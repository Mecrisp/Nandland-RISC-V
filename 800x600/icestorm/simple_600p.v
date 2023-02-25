// Project F: FPGA Graphics - Simple 640x480p60 Display
// (C)2022 Will Green, open source hardware released under the MIT License
// Learn more at https://projectf.io/posts/fpga-graphics/

`default_nettype none
`timescale 1ns / 1ps

module simple_600p (
    input  wire clk_pix,   // pixel clock
    input  wire rst_pix,   // reset in pixel clock domain
    output reg  [10:0] sx,  // horizontal screen position
    output reg  [ 9:0] sy,  // vertical screen position
    output      hsync,     // horizontal sync
    output      vsync,     // vertical sync
    output      de         // data enable (low in blanking interval)
    );

    // horizontal timings
    parameter HA_END = 799;           // end of active pixels
    parameter HS_STA = HA_END + 56;   // sync starts after front porch
    parameter HS_END = HS_STA + 120;  // sync ends
    parameter LINE   = 1039;           // last pixel on line (after back porch)

    // vertical timings
    parameter VA_END = 599;           // end of active pixels
    parameter VS_STA = VA_END + 37;   // sync starts after front porch
    parameter VS_END = VS_STA + 6;    // sync ends
    parameter SCREEN = 665;           // last line on screen (after back porch)

    assign hsync = (sx >= HS_STA && sx < HS_END);  // positive polarity
    assign vsync = (sy >= VS_STA && sy < VS_END);  // positive polarity
    assign de = (sx <= HA_END && sy <= VA_END);

    // calculate horizontal and vertical screen position
    always @(posedge clk_pix)
    begin
        if (sx == LINE) begin  // last pixel on line?
            sx <= 0;
            sy <= (sy == SCREEN) ? 0 : sy + 1;  // last line on screen?
        end else begin
            sx <= sx + 1;
        end
        if (rst_pix) begin
            sx <= 0;
            sy <= 0;
        end
    end
endmodule
