// top_oled_a4_test.v — send 0xA4 (display from RAM) to confirm it works.
// If display goes black: 0xA4 reaches SH1106 correctly.
// Uses same proven simple sequencer as top_oled_probe.
module top_oled_a4_test (
    input  wire clk,
    output wire oled_scl,
    output wire oled_sda,
    output wire led
);
    assign led = 1'b1;  // solid on = this bitstream

    reg [7:0] i2c_data      = 0;
    reg       i2c_start     = 0;
    reg       i2c_send_stop = 0;
    wire      i2c_busy;

    ssd1306_i2c i2c (
        .clk       (clk),
        .rst       (1'b0),
        .data      (i2c_data),
        .start     (i2c_start),
        .send_start(1'b0),
        .send_stop (i2c_send_stop),
        .busy      (i2c_busy),
        .scl       (oled_scl),
        .sda       (oled_sda)
    );

    localparam N = 7;
    reg [7:0] seq [0:N-1];
    initial begin
        seq[0] = 8'h78;  // I2C addr (write)
        seq[1] = 8'h00;  // command prefix
        seq[2] = 8'hAE;  // display off
        seq[3] = 8'h8D;  // charge pump
        seq[4] = 8'h14;
        seq[5] = 8'hAF;  // display on
        seq[6] = 8'hA4;  // display from RAM (should go dark/show zeroes)
    end

    reg [3:0] idx     = 0;
    reg       started = 0;
    reg       done    = 0;

    always @(posedge clk) begin
        i2c_start <= 0;
        if (!done && !i2c_busy && !i2c_start) begin
            if (!started || idx > 0) begin
                i2c_data      <= seq[idx];
                i2c_send_stop <= (idx == N-1);
                i2c_start     <= 1;
                started       <= 1;
                if (idx == N-1)
                    done <= 1;
                else
                    idx <= idx + 1;
            end
        end
    end
endmodule
