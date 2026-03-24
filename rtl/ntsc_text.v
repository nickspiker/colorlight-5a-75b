// NTSC B&W composite text display — scalable character grid
// Pixel clock: 25 MHz (board oscillator, no PLL needed)
// Output: 2-pin DAC (sync + video) through resistor network
//
// NTSC non-interlaced timing at 25 MHz:
//   H total:  1589 clocks (63.56 µs)
//   H sync:    118 clocks ( 4.72 µs)
//   H back:    142 clocks ( 5.68 µs)
//   H active: 1280 clocks (51.20 µs)
//   H front:    49 clocks ( 1.96 µs)
//   V total:   262 lines
//   V sync:      3 lines
//   V top:      19 lines
//   V active:  200 lines
//   V bottom:   40 lines

module ntsc_text #(
    parameter COLS    = 4,
    parameter ROWS    = 1,
    parameter CHAR_W  = 8,
    parameter CHAR_H  = 8,
    parameter H_SCALE = 40,   // clocks per font pixel (horizontal)
    parameter V_SCALE = 25    // lines per font pixel (vertical)
)(
    input  wire clk,          // 25 MHz

    // character buffer write port
    input  wire        char_we,
    input  wire [9:0]  char_addr,  // 0..COLS*ROWS-1
    input  wire [6:0]  char_data,  // ASCII 0..127

    // composite output pins
    output reg  sync_pin,
    output reg  video_pin
);

    // =========================================================================
    // NTSC timing constants (25 MHz pixel clock)
    // =========================================================================
    localparam H_TOTAL   = 1589;
    localparam H_SYNC    = 118;
    localparam H_BACK    = 142;
    localparam H_MAX_ACT = 1280;
    localparam H_FRONT   = H_TOTAL - H_SYNC - H_BACK - H_MAX_ACT;  // 49

    localparam V_TOTAL   = 262;
    localparam V_SYNC    = 3;
    localparam V_TOP     = 19;
    localparam V_MAX_ACT = 200;
    localparam V_BOTTOM  = V_TOTAL - V_SYNC - V_TOP - V_MAX_ACT;  // 40

    // Content size and centering
    localparam H_CONTENT = COLS * CHAR_W * H_SCALE;
    localparam V_CONTENT = ROWS * CHAR_H * V_SCALE;
    localparam H_BORDER  = (H_MAX_ACT - H_CONTENT) / 2;
    localparam V_BORDER  = (V_MAX_ACT - V_CONTENT) / 2;

    // =========================================================================
    // Counters
    // =========================================================================
    reg [10:0] h_cnt = 0;  // 0..1588
    reg [8:0]  v_cnt = 0;  // 0..261

    wire h_end = (h_cnt == H_TOTAL - 1);

    always @(posedge clk) begin
        if (h_end) begin
            h_cnt <= 0;
            if (v_cnt == V_TOTAL - 1)
                v_cnt <= 0;
            else
                v_cnt <= v_cnt + 1;
        end else begin
            h_cnt <= h_cnt + 1;
        end
    end

    // =========================================================================
    // Region flags
    // =========================================================================
    wire h_sync_region = (h_cnt < H_SYNC);
    wire v_sync_region = (v_cnt < V_SYNC);

    // Content region (where characters are drawn)
    localparam H_CONTENT_START = H_SYNC + H_BACK + H_BORDER;
    localparam H_CONTENT_END   = H_CONTENT_START + H_CONTENT;
    localparam V_CONTENT_START = V_SYNC + V_TOP + V_BORDER;
    localparam V_CONTENT_END   = V_CONTENT_START + V_CONTENT;

    wire h_in_content = (h_cnt >= H_CONTENT_START) && (h_cnt < H_CONTENT_END);
    wire v_in_content = (v_cnt >= V_CONTENT_START) && (v_cnt < V_CONTENT_END);

    // =========================================================================
    // Counter-based pixel indexing (supports non-power-of-2 scales)
    // =========================================================================

    // --- Horizontal: resets at start of each line ---
    reg [5:0] h_scale_cnt = 0;   // 0..H_SCALE-1
    reg [2:0] cell_x = 0;        // 0..CHAR_W-1
    reg [5:0] char_col = 0;      // 0..COLS-1

    always @(posedge clk) begin
        if (h_cnt == H_CONTENT_START - 1) begin
            // Prime counters 1 clock before content starts
            h_scale_cnt <= 0;
            cell_x      <= 0;
            char_col    <= 0;
        end else if (h_in_content) begin
            if (h_scale_cnt == H_SCALE - 1) begin
                h_scale_cnt <= 0;
                if (cell_x == CHAR_W - 1) begin
                    cell_x   <= 0;
                    char_col <= char_col + 1;
                end else begin
                    cell_x <= cell_x + 1;
                end
            end else begin
                h_scale_cnt <= h_scale_cnt + 1;
            end
        end
    end

    // --- Vertical: resets at start of frame, advances at end of each line ---
    reg [4:0] v_scale_cnt = 0;   // 0..V_SCALE-1
    reg [2:0] cell_y = 0;        // 0..CHAR_H-1
    reg [4:0] char_row = 0;      // 0..ROWS-1

    always @(posedge clk) begin
        if (v_cnt == V_CONTENT_START - 1 && h_end) begin
            v_scale_cnt <= 0;
            cell_y      <= 0;
            char_row    <= 0;
        end else if (v_in_content && h_end) begin
            if (v_scale_cnt == V_SCALE - 1) begin
                v_scale_cnt <= 0;
                if (cell_y == CHAR_H - 1) begin
                    cell_y   <= 0;
                    char_row <= char_row + 1;
                end else begin
                    cell_y <= cell_y + 1;
                end
            end else begin
                v_scale_cnt <= v_scale_cnt + 1;
            end
        end
    end

    // =========================================================================
    // Character buffer — dual-port RAM
    // =========================================================================
    reg [6:0] char_buf [0:1023];
    integer i;
    initial for (i = 0; i < 1024; i = i + 1) char_buf[i] = 7'h20; // spaces

    // Write port
    always @(posedge clk) begin
        if (char_we)
            char_buf[char_addr] <= char_data;
    end

    // Read port — address from scan position
    wire [9:0] scan_addr = char_row * COLS + char_col;
    reg [6:0] char_code;
    always @(posedge clk) char_code <= char_buf[scan_addr];

    // =========================================================================
    // Font ROM — 128 chars × 8 rows = 1024 bytes
    // =========================================================================
    reg [7:0] font_rom [0:1023];
    initial $readmemh("build/font_8x8.mem", font_rom);

    wire [9:0] font_addr = {char_code, cell_y};
    reg [7:0] font_row;
    always @(posedge clk) font_row <= font_rom[font_addr];

    // =========================================================================
    // Pixel output — 2-cycle pipeline delay for BRAM reads
    // =========================================================================
    reg [2:0] cell_x_d1, cell_x_d2;
    reg       content_d1, content_d2;

    always @(posedge clk) begin
        cell_x_d1  <= cell_x;
        cell_x_d2  <= cell_x_d1;
        content_d1 <= h_in_content & v_in_content;
        content_d2 <= content_d1;
    end

    wire pixel  = font_row[7 - cell_x_d2];  // MSB = leftmost
    wire active = content_d2;

    // =========================================================================
    // Composite output
    // =========================================================================
    wire in_sync = h_sync_region | v_sync_region;

    always @(posedge clk) begin
        sync_pin  <= ~in_sync;           // low during sync
        video_pin <= active & pixel;     // high for white pixels only
    end

endmodule
