// top_oled_image.v — display static image on SH1106 128×64 OLED (I2C)
//
// Image stored as 8bpp grayscale ROM (row-major, 8192 bytes).
// Per-pixel dithering with TRNG threshold (synthesised separately as black-box).
// ROM addr = {page[2:0], row_in_page[2:0], col[6:0]} = 13 bits
//
// Clock architecture:
//   ce fires every CLK_DIV clocks — FSM and ROM reads tick at I2C speed.
//   TRNG runs at full 25 MHz; dither_thresh is sampled by the ce-gated FSM.
//   ssd1306_i2c has its own internal CLK_DIV counter — ce and I2C are in step.

module top_oled_image #(
    parameter integer CLK_DIV = 7   // I2C bit-clock divider: SCL = 25MHz / CLK_DIV
)(
    input  wire clk,        // 25 MHz
    output wire oled_scl,
    output wire oled_sda,
    output wire led
);
    assign led = 1'b0;  // solid on (active-low) = bitstream running

    // =========================================================================
    // CE — ticks FSM and ROM at I2C speed (CLK_DIV = one I2C bit period)
    // =========================================================================
    reg [$clog2(CLK_DIV)-1:0] cnt = 0;
    wire at_top = (cnt == CLK_DIV - 1);
    always @(posedge clk) cnt <= at_top ? 0 : cnt + 1;
    reg ce = 0;
    always @(posedge clk) ce <= at_top;

    // =========================================================================
    // Image ROM
    // =========================================================================
    reg [7:0] rom [0:8191];
    initial $readmemh("build/fb_image.mem", rom);

    // =========================================================================
    // I2C driver
    // =========================================================================
    localparam I2C_ADDR    = 8'h78;
    localparam CMD_PREFIX  = 8'h00;
    localparam DATA_PREFIX = 8'h40;

    reg  [7:0] i2c_data;
    reg        i2c_start;
    reg        i2c_send_stop;
    wire       i2c_busy;

    ssd1306_i2c #(.CLK_DIV(CLK_DIV)) i2c (
        .clk(clk), .rst(1'b0),
        .data(i2c_data),
        .start(i2c_start),
        .send_start(1'b0),
        .send_stop(i2c_send_stop),
        .busy(i2c_busy),
        .scl(oled_scl), .sda(oled_sda)
    );

    // =========================================================================
    // Init command table
    // =========================================================================
    localparam INIT_LEN = 25;
    reg [7:0] init_cmds [0:INIT_LEN-1];
    initial begin
        init_cmds[ 0] = 8'hAE;
        init_cmds[ 1] = 8'hD5;
        init_cmds[ 2] = 8'h80;
        init_cmds[ 3] = 8'hA8;
        init_cmds[ 4] = 8'h3F;
        init_cmds[ 5] = 8'hD3;
        init_cmds[ 6] = 8'h00;
        init_cmds[ 7] = 8'h40;
        init_cmds[ 8] = 8'h8D;
        init_cmds[ 9] = 8'h14;
        init_cmds[10] = 8'hAD;
        init_cmds[11] = 8'h8B;
        init_cmds[12] = 8'hA1;  // reverse segment direction (flip horizontal)
        init_cmds[13] = 8'hC8;  // reverse COM scan (flip vertical)
        init_cmds[14] = 8'hDA;
        init_cmds[15] = 8'h12;
        init_cmds[16] = 8'h81;
        init_cmds[17] = 8'hCF;
        init_cmds[18] = 8'hD9;
        init_cmds[19] = 8'hF1;
        init_cmds[20] = 8'hDB;
        init_cmds[21] = 8'h40;
        init_cmds[22] = 8'hA4;  // display from RAM
        init_cmds[23] = 8'hA6;
        init_cmds[24] = 8'hAF;  // display on
    end

    // =========================================================================
    // Dither threshold — 32-bit maximal LFSR, 8-bit threshold
    //
    // Runs at full 25 MHz (not CE-gated). Each CE tick (32 clocks) the LFSR
    // has advanced 32 steps, giving an effectively independent sample.
    // No spatial component — pure temporal dither avoids page-aligned artifacts.
    // =========================================================================
    reg [31:0] lfsr_f = 32'hACE1F0B3;
    wire lfsr_f_fb = lfsr_f[31] ^ lfsr_f[21] ^ lfsr_f[1] ^ lfsr_f[0];
    always @(posedge clk) lfsr_f <= {lfsr_f[30:0], lfsr_f_fb};

    wire [7:0] dither_thresh = lfsr_f[7:0];

    // =========================================================================
    // FSM
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

    reg [2:0]  state       = ST_RESET;
    reg [1:0]  phase       = PH_INIT;
    reg [19:0] reset_cnt   = 0;
    reg [9:0]  busfree_cnt = 0;
    reg [4:0]  cmd_idx     = 0;
    reg [2:0]  page        = 0;
    reg [6:0]  col         = 0;
    reg [7:0]  px_byte     = 0;
    reg [3:0]  gather_cnt  = 0;

    // ROM read: address computed combinationally, 1-cycle registered output.
    // gather_cnt[2:0] at gc=0 → reads row 0; rom_dout available at gc=1 (captured as D0).
    // No prefetch needed. No rom_addr register needed.
    reg  [7:0] rom_dout = 0;

    always @(posedge clk) if (ce) begin
        rom_dout <= rom[{page, gather_cnt[2:0], col}];
        i2c_start <= 0;

        case (state)

            ST_RESET: begin
                reset_cnt <= reset_cnt + 1;
                if (&reset_cnt) begin
                    phase   <= PH_INIT;
                    cmd_idx <= 0;
                    page    <= 0;
                    col     <= 0;
                    state   <= ST_SEND;
                end
            end

            ST_SEND: begin
                if (!i2c_busy) begin
                    case (phase)
                        PH_INIT: begin
                            if (cmd_idx == 0) begin
                                i2c_data      <= I2C_ADDR;
                                i2c_send_stop <= 0;
                            end else if (cmd_idx == 1) begin
                                i2c_data      <= CMD_PREFIX;
                                i2c_send_stop <= 0;
                            end else begin
                                i2c_data      <= init_cmds[cmd_idx - 2];
                                i2c_send_stop <= (cmd_idx == INIT_LEN + 1);
                            end
                        end
                        PH_PAGE_CMD: begin
                            case (cmd_idx[2:0])
                                3'd0: begin i2c_data <= I2C_ADDR;             i2c_send_stop <= 0; end
                                3'd1: begin i2c_data <= CMD_PREFIX;            i2c_send_stop <= 0; end
                                3'd2: begin i2c_data <= 8'hB0 | {5'd0, page}; i2c_send_stop <= 0; end
                                3'd3: begin i2c_data <= 8'h02;                i2c_send_stop <= 0; end
                                3'd4: begin i2c_data <= 8'h10;                i2c_send_stop <= 1; end
                                default: ;
                            endcase
                        end
                        PH_PAGE_DATA: begin
                            if (cmd_idx == 0) begin
                                i2c_data      <= I2C_ADDR;
                                i2c_send_stop <= 0;
                            end else if (cmd_idx == 1) begin
                                i2c_data      <= DATA_PREFIX;
                                i2c_send_stop <= 0;
                            end else begin
                                i2c_data      <= px_byte;
                                i2c_send_stop <= (col == 7'd127);
                            end
                        end
                    endcase
                    i2c_start <= 1;
                    state     <= ST_WAIT;
                end
            end

            ST_WAIT: begin
                if (i2c_busy)
                    state <= ST_NEXT;
            end

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
                                phase      <= PH_PAGE_DATA;
                                cmd_idx    <= 0;
                                col        <= 0;
                                gather_cnt <= 0;
                                state      <= ST_BUSFREE;
                            end else begin
                                cmd_idx <= cmd_idx + 1;
                                state   <= ST_SEND;
                            end
                        end
                        PH_PAGE_DATA: begin
                            if (cmd_idx < 2) begin
                                cmd_idx <= cmd_idx + 1;
                                if (cmd_idx == 1) begin
                                    // sent DATA_PREFIX — start gathering col 0
                                    gather_cnt <= 0;
                                    state      <= ST_GATHER;
                                end else begin
                                    state <= ST_SEND;
                                end
                            end else if (col == 7'd127) begin
                                phase   <= PH_PAGE_CMD;
                                cmd_idx <= 0;
                                page    <= (page == 3'd7) ? 3'd0 : page + 1;
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

            ST_BUSFREE: begin
                busfree_cnt <= busfree_cnt + 1;
                if (&busfree_cnt) begin
                    busfree_cnt <= 0;
                    state       <= ST_SEND;
                end
            end

            // Gather 8 rows into px_byte:
            // ROM address = {page, gather_cnt[2:0], col} computed combinationally.
            // gc=0: ROM reads row 0 → rom_dout = row 0 at gc=1.
            // gc=1..8: capture rom_dout (row 0..7) into px_byte via right-shift.
            ST_GATHER: begin
                gather_cnt <= gather_cnt + 1;
                if (gather_cnt >= 4'd1) begin
                    px_byte <= {(rom_dout >= dither_thresh), px_byte[7:1]};
                end
                if (gather_cnt == 4'd8) begin
                    gather_cnt <= 0;
                    state      <= ST_SEND;
                end
            end

        endcase
    end

endmodule
