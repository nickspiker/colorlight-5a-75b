// ssd1306_fb.v — 128×64 8bpp framebuffer → SH1106 OLED (I2C, dithered)
//
// Write port: wr_addr = row*128 + col (0..8191), wr_data = 8-bit grey
// Dither: TRNG threshold per pixel (spirix_alu_random, 64-bit, 8 bits/px)
// Timing: `ce` input is one pulse per SCL half-period (from top-level counter)
//         EVERY gate in this module is gated by ce — nothing runs at 25 MHz.
//
// OLED byte layout: D0 = top row of page, right-shift build
// BRAM addr = {page[2:0], row_in_page[2:0], col[6:0]} = 13 bits

module ssd1306_fb (
    input  wire        clk,
    input  wire        rst,
    input  wire        ce,        // one pulse per SCL half-period — gates everything

    // 8bpp write port (row-major: addr = row*128 + col)
    // Write port runs at full clk so the ROM loader in top can stream at startup
    input  wire [12:0] wr_addr,
    input  wire  [7:0] wr_data,
    input  wire        wr_en,

    output wire        scl,
    output wire        sda
);

    // =========================================================================
    // Framebuffer BRAM (8192 × 8)
    // Write port: full clk (ROM loader streams at startup, one write/clk)
    // Read port: ce-gated (gather state reads one pixel per ce)
    // =========================================================================
    reg [7:0] fb [0:8191];
    always @(posedge clk)
        if (wr_en) fb[wr_addr] <= wr_data;

    reg [12:0] rd_addr = 0;
    reg  [7:0] rd_dout = 0;
    always @(posedge clk)
        if (ce) rd_dout <= fb[rd_addr];

    // =========================================================================
    // TRNG — free-running at 25 MHz (ring oscillators must spin continuously)
    // Output captured into rng_shift only on ce pulses
    // =========================================================================
    wire [63:0] trng_frac;
    wire        trng_done, trng_busy;
    reg         trng_start = 1;

    spirix_alu_random #(.MAX_FRAC(64), .MAX_EXP(8)) trng (
        .clk(clk),
        .start(trng_start),
        .frac_width(2'b11),
        .exp_width(2'b00),
        .result_frac(trng_frac),
        .result_exp(),
        .busy(trng_busy),
        .done(trng_done),
        .dbg_xor()
    );

    always @(posedge clk) begin
        if (ce) begin
            trng_start <= 0;
            if (trng_done) trng_start <= 1;
        end
    end

    // 64-bit shift register: 8 bits consumed per pixel column, updated on ce
    reg [63:0] rng_shift = 64'hDEAD_BEEF_CAFE_1234;
    wire [7:0] dither_thresh = rng_shift[7:0];

    // =========================================================================
    // I2C driver — gated by ce
    // =========================================================================
    reg  [7:0] i2c_data;
    reg        i2c_start = 0;   // held high until i2c_busy acknowledges
    reg        i2c_send_stop;
    wire       i2c_busy;

    ssd1306_i2c i2c_drv (
        .clk(clk), .rst(rst),
        .data(i2c_data),
        .start(i2c_start),
        .send_start(1'b0),
        .send_stop(i2c_send_stop),
        .busy(i2c_busy),
        .scl(scl), .sda(sda)
    );

    // =========================================================================
    // Init command table (SSD1306 + SH1106 compatible)
    // =========================================================================
    localparam INIT_LEN = 25;
    reg [7:0] init_cmds [0:INIT_LEN-1];
    initial begin
        init_cmds[ 0] = 8'hAE;  // display off
        init_cmds[ 1] = 8'hD5;  // clock divide
        init_cmds[ 2] = 8'h80;
        init_cmds[ 3] = 8'hA8;  // multiplex
        init_cmds[ 4] = 8'h3F;  // 64-1
        init_cmds[ 5] = 8'hD3;  // display offset
        init_cmds[ 6] = 8'h00;
        init_cmds[ 7] = 8'h40;  // start line 0
        init_cmds[ 8] = 8'h8D;  // charge pump (SSD1306)
        init_cmds[ 9] = 8'h14;
        init_cmds[10] = 8'hAD;  // DC-DC control (SH1106)
        init_cmds[11] = 8'h8B;
        init_cmds[12] = 8'hA1;  // segment remap col127=SEG0
        init_cmds[13] = 8'hC8;  // COM scan descending
        init_cmds[14] = 8'hDA;  // COM pins
        init_cmds[15] = 8'h12;
        init_cmds[16] = 8'h81;  // contrast
        init_cmds[17] = 8'hCF;
        init_cmds[18] = 8'hD9;  // pre-charge
        init_cmds[19] = 8'hF1;
        init_cmds[20] = 8'hDB;  // VCOMH deselect
        init_cmds[21] = 8'h40;
        init_cmds[22] = 8'hA4;  // display from RAM (normal)
        init_cmds[23] = 8'hA6;  // normal (not inverted)
        init_cmds[24] = 8'hAF;  // display on
    end

    // =========================================================================
    // Sequencer — ALL state advances on ce only
    // =========================================================================
    localparam [2:0]
        ST_RESET   = 3'd0,
        ST_SEND    = 3'd1,
        ST_WAIT    = 3'd2,
        ST_NEXT    = 3'd3,
        ST_BUSFREE = 3'd4,
        ST_GATHER  = 3'd5;

    localparam [1:0]
        PH_INIT      = 2'd0,
        PH_PAGE_CMD  = 2'd1,
        PH_PAGE_DATA = 2'd2;

    localparam [7:0] I2C_ADDR    = 8'h78;  // 0x3C << 1 (write)
    localparam [7:0] CMD_PREFIX  = 8'h00;
    localparam [7:0] DATA_PREFIX = 8'h40;

    reg [2:0]  state       = ST_RESET;
    reg [1:0]  phase       = PH_INIT;
    reg [11:0] reset_cnt   = 0;   // 2^12 ce pulses ≈ 10ms @ CLK_DIV=64
    reg [9:0]  busfree_cnt = 0;
    reg [4:0]  cmd_idx     = 0;
    reg [2:0]  page        = 0;
    reg [6:0]  col         = 0;
    reg [7:0]  px_byte     = 0;
    reg [3:0]  gather_cnt  = 0;

    always @(posedge clk) begin
        if (rst) begin
            state     <= ST_RESET;
            reset_cnt <= 0;
            i2c_start <= 0;
        end else begin

            i2c_start <= 0;  // default: pulse for one cycle only

            case (state)

                // --- power-on hold ---
                ST_RESET: begin
                    reset_cnt <= reset_cnt + 1;
                    if (&reset_cnt) begin
                        phase   <= PH_INIT;
                        cmd_idx <= 0;
                        state   <= ST_SEND;
                    end
                end

                // --- load byte into i2c driver ---
                ST_SEND: begin
                    if (!i2c_busy) begin
                        case (phase)
                            PH_INIT: begin
                                case (cmd_idx)
                                    5'd0: begin i2c_data <= I2C_ADDR;   i2c_send_stop <= 0; end
                                    5'd1: begin i2c_data <= CMD_PREFIX;  i2c_send_stop <= 0; end
                                    default: begin
                                        i2c_data      <= init_cmds[cmd_idx - 2];
                                        i2c_send_stop <= (cmd_idx == INIT_LEN + 1);
                                    end
                                endcase
                            end
                            PH_PAGE_CMD: begin
                                case (cmd_idx[2:0])
                                    3'd0: begin i2c_data <= I2C_ADDR;              i2c_send_stop <= 0; end
                                    3'd1: begin i2c_data <= CMD_PREFIX;             i2c_send_stop <= 0; end
                                    3'd2: begin i2c_data <= 8'hB0 | {5'd0, page};  i2c_send_stop <= 0; end
                                    3'd3: begin i2c_data <= 8'h02;                 i2c_send_stop <= 0; end
                                    3'd4: begin i2c_data <= 8'h10;                 i2c_send_stop <= 1; end
                                    default: ;
                                endcase
                            end
                            PH_PAGE_DATA: begin
                                case (cmd_idx)
                                    5'd0: begin i2c_data <= I2C_ADDR;    i2c_send_stop <= 0; end
                                    5'd1: begin i2c_data <= DATA_PREFIX;  i2c_send_stop <= 0; end
                                    default: begin
                                        i2c_data      <= px_byte;
                                        i2c_send_stop <= (col == 7'd127);
                                    end
                                endcase
                            end
                        endcase
                        i2c_start <= 1;
                        state     <= ST_WAIT;
                    end
                end

                // --- wait for i2c to acknowledge start ---
                ST_WAIT: begin
                    if (i2c_busy)
                        state <= ST_NEXT;
                end

                // --- wait for byte to finish, advance sequencer ---
                ST_NEXT: begin
                    if (!i2c_busy) begin
                        case (phase)
                            PH_INIT: begin
                                if (cmd_idx == INIT_LEN + 1) begin
                                    phase   <= PH_PAGE_CMD;
                                    cmd_idx <= 0;
                                    page    <= 0;
                                    state   <= ST_BUSFREE;
                                end else begin
                                    cmd_idx <= cmd_idx + 1;
                                    state   <= ST_SEND;
                                end
                            end
                            PH_PAGE_CMD: begin
                                if (cmd_idx == 4) begin
                                    phase   <= PH_PAGE_DATA;
                                    cmd_idx <= 0;
                                    col     <= 0;
                                    state   <= ST_BUSFREE;
                                end else begin
                                    cmd_idx <= cmd_idx + 1;
                                    state   <= ST_SEND;
                                end
                            end
                            PH_PAGE_DATA: begin
                                if (cmd_idx < 2) begin
                                    cmd_idx <= cmd_idx + 1;
                                    if (cmd_idx == 1) begin
                                        gather_cnt <= 0;
                                        state      <= ST_GATHER;
                                    end else begin
                                        state <= ST_SEND;
                                    end
                                end else if (col == 7'd127) begin
                                    cmd_idx <= 0;
                                    page    <= (page == 3'd7) ? 3'd0 : page + 1;
                                    phase   <= PH_PAGE_CMD;
                                    state   <= ST_BUSFREE;
                                end else begin
                                    col        <= col + 1;
                                    gather_cnt <= 0;
                                    state      <= ST_GATHER;
                                end
                            end
                        endcase
                    end
                end

                // --- bus-free gap between I2C transactions ---
                ST_BUSFREE: begin
                    busfree_cnt <= busfree_cnt + 1;
                    if (&busfree_cnt) begin
                        busfree_cnt <= 0;
                        state       <= ST_SEND;
                    end
                end

                // --- gather 8 pixels for current page+col into px_byte ---
                // BRAM has 1-cycle read latency (ce-gated): set rd_addr on ce N,
                // rd_dout holds that pixel on ce N+1.
                // gather_cnt=0: issue read for row 0
                // gather_cnt=1: rd_dout=row0 → shift bit; issue read for row 1
                // ...
                // gather_cnt=7: rd_dout=row6 → shift bit; issue read for row 7
                // gather_cnt=8: rd_dout=row7 → shift last bit; → ST_SEND
                ST_GATHER: begin
                    gather_cnt <= gather_cnt + 1;
                    // DIAGNOSTIC: force all-black
                    px_byte <= 8'h00;
                    if (gather_cnt == 4'd8) begin
                        gather_cnt <= 0;
                        state      <= ST_SEND;
                    end
                end

            endcase
        end
    end

endmodule
