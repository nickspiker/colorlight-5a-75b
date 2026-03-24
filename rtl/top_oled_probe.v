// Minimal probe: old I2C driver, just sends 0xA5 (entire display ON)
// If display lights up, old driver works and the issue was in our ce-based driver.
// Sequence: START + 0x78 (addr) + 0x00 (cmd prefix) + 0xAF (on) + STOP
//           then START + 0x78 + 0x00 + 0xA5 (all pixels on) + STOP
module top_oled_probe (
    input  wire clk,
    output wire oled_scl,
    output wire oled_sda,
    output wire led
);
    assign led = 1'b1;  // LED on = this bitstream running

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

    // Simple sequencer: wait for !busy, fire bytes one by one
    // Bytes: 0x78, 0x00, 0xAE, 0x8D, 0x14, 0xAF, 0xA5 (+ stop on last)
    localparam N = 8;
    reg [7:0] seq [0:N-1];
    initial begin
        seq[0] = 8'h78;  // I2C addr (write)
        seq[1] = 8'h00;  // command prefix
        seq[2] = 8'hAE;  // display off
        seq[3] = 8'h8D;  // charge pump
        seq[4] = 8'h14;
        seq[5] = 8'hAF;  // display on
        seq[6] = 8'hA5;  // entire display ON (all pixels white)
        seq[7] = 8'hA5;  // repeat to make sure
    end

    reg [3:0] idx      = 0;
    reg       started  = 0;
    reg       done     = 0;

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
