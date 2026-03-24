// top_oled_black.v — full init + all-black pixel output, inline (no ssd1306_fb submodule)
// Matches ssd1306_oled.v FSM exactly. If display goes black, ssd1306_fb.v has a bug.
module top_oled_black (
    input  wire clk,
    output wire oled_scl,
    output wire oled_sda,
    output wire led
);
    assign led = 1'b0;  // solid on = this bitstream

    localparam I2C_ADDR    = 8'h78;
    localparam CMD_PREFIX  = 8'h00;
    localparam DATA_PREFIX = 8'h40;

    reg  [7:0] i2c_data;
    reg        i2c_start;
    reg        i2c_send_stop;
    wire       i2c_busy;

    ssd1306_i2c i2c (
        .clk(clk), .rst(1'b0),
        .data(i2c_data),
        .start(i2c_start),
        .send_start(1'b0),
        .send_stop(i2c_send_stop),
        .busy(i2c_busy),
        .scl(oled_scl), .sda(oled_sda)
    );

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
        init_cmds[12] = 8'hA1;
        init_cmds[13] = 8'hC8;
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

    localparam [2:0]
        ST_RESET   = 3'd0,
        ST_SEND    = 3'd1,
        ST_WAIT    = 3'd2,
        ST_NEXT    = 3'd3,
        ST_BUSFREE = 3'd4;

    localparam [1:0]
        PH_INIT      = 2'd0,
        PH_PAGE_CMD  = 2'd1,
        PH_PAGE_DATA = 2'd2;

    reg [2:0]  state      = ST_RESET;
    reg [1:0]  phase      = PH_INIT;
    reg [19:0] reset_cnt  = 0;
    reg [9:0]  busfree_cnt = 0;
    reg [4:0]  cmd_idx    = 0;
    reg [2:0]  page       = 0;
    reg [6:0]  col        = 0;

    // All-black pixel output
    wire [7:0] px_byte = 8'h00;

    always @(posedge clk) begin
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
                                state   <= ST_SEND;
                            end else if (col == 7'd127) begin
                                phase   <= PH_PAGE_CMD;
                                cmd_idx <= 0;
                                page    <= (page == 3'd7) ? 3'd0 : page + 1;
                                state   <= ST_BUSFREE;
                            end else begin
                                col     <= col + 1;
                                state   <= ST_SEND;
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
        endcase
    end
endmodule
