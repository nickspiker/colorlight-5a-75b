// spirix_keypad.v — Async matrix keypad scanner (4 col × 5 row, no clock)
//
// Key press latches column, flips IO direction, reads row.
// Key release clears latch. Fully combinational — no clock, no debounce.
// Desolder 74HC245T on both connectors (U2 for J2, U3 for J3).
// All pins need PULLMODE=UP in constraints.

module spirix_keypad (
    inout  wire [3:0] col,       // J2: 4 column pins
    inout  wire [4:0] row,       // J3: 5 row pins
    output wire [4:0] o_key,     // decoded key 0-19 (row*4 + col)
    output wire       o_valid    // key pressed and decoded
);

    // Read physical pins
    wire [3:0] col_rd = col;
    wire [4:0] row_rd = row;

    // Column capture latch (active-high: 1 = this column was pressed)
    // GSR inits to 0000 = idle (phase 0). No clock needed.
    (* keep *) reg [3:0] col_lat;

    wire phase       = |col_lat;     // any bit set = row-scan phase
    wire any_col_low = ~(&col_rd);   // column contact detected
    wire key_release = &row_rd;      // all rows high = switch open

    always @* begin
        if (!phase && any_col_low)
            col_lat = ~col_rd;       // capture (invert active-low pins)
        else if (phase && key_release)
            col_lat = 4'b0000;       // clear
    end

    // --- Tristate control ---
    // Phase 0: rows drive LOW,           cols input (pull-up)
    // Phase 1: captured col drives LOW,  rows input (pull-up)

    assign row[0] = phase ? 1'bz : 1'b0;
    assign row[1] = phase ? 1'bz : 1'b0;
    assign row[2] = phase ? 1'bz : 1'b0;
    assign row[3] = phase ? 1'bz : 1'b0;
    assign row[4] = phase ? 1'bz : 1'b0;

    assign col[0] = (phase && col_lat[0]) ? 1'b0 : 1'bz;
    assign col[1] = (phase && col_lat[1]) ? 1'b0 : 1'bz;
    assign col[2] = (phase && col_lat[2]) ? 1'b0 : 1'bz;
    assign col[3] = (phase && col_lat[3]) ? 1'b0 : 1'bz;

    // --- Decode: one-hot → index ---
    wire [1:0] col_idx = col_lat[0] ? 2'd0 :
                         col_lat[1] ? 2'd1 :
                         col_lat[2] ? 2'd2 : 2'd3;

    wire [2:0] row_idx = !row_rd[0] ? 3'd0 :
                         !row_rd[1] ? 3'd1 :
                         !row_rd[2] ? 3'd2 :
                         !row_rd[3] ? 3'd3 : 3'd4;

    assign o_key   = {row_idx, col_idx};    // row*4 + col
    assign o_valid = phase && !key_release;

endmodule
