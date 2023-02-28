// Project F: FPGA Graphics - Simple 640x480p60 Display
// (C)2022 Will Green, open source hardware released under the MIT License
// Learn more at https://projectf.io/posts/fpga-graphics/

// Matthias Koch, 2023: Changed to registered output of hsync, vsync and de, 1 clock cycle later.

`default_nettype none
`timescale 1ns / 1ps

module simple_600p_regs (
   input  wire clk_pix,   // pixel clock
   input  wire rst_pix,   // reset in pixel clock domain
   output reg  [10:0] sx, // horizontal screen position
   output reg  [ 9:0] sy, // vertical screen position
   output reg  hsync,     // horizontal sync
   output reg  vsync,     // vertical sync
   output reg  de         // data enable (low in blanking interval)
);

   // Horizontal timings
   parameter HA_END = 799;           // end of active pixels
   parameter HS_STA = HA_END + 56;   // sync starts after front porch
   parameter HS_END = HS_STA + 120;  // sync ends
   parameter LINE   = 1039;          // last pixel on line (after back porch)

   // Hertical timings
   parameter VA_END = 599;           // end of active pixels
   parameter VS_STA = VA_END + 37;   // sync starts after front porch
   parameter VS_END = VS_STA + 6;    // sync ends
   parameter SCREEN = 665;           // last line on screen (after back porch)

   reg blanky;

   always @(posedge clk_pix)
   begin
      if (rst_pix) begin
         sx <= 0;
         sy <= 0;
         hsync  <= 0;
         vsync  <= 0;
         de     <= 0;
         blanky <= 0;
      end
      else begin

         hsync <= (sx == HS_STA) | (hsync & ~(sx == HS_END)); // positive polarity
         vsync <= (sy == VS_STA) | (vsync & ~(sy == VS_END)); // positive polarity

         de <= ((sx == 0) | (de & ~(sx == HA_END+1))) & ~blanky;

         if (sx == LINE) begin  // last pixel on line?
             sx <= 0;

             if (sy == SCREEN) begin sy <= 0;      blanky <= 0;                       end
             else              begin sy <= sy + 1; blanky <= blanky | (sy == VA_END); end

         end else begin
            sx <= sx + 1;
         end

      end
   end
endmodule
