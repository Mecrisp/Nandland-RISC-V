/*
 *  PicoSoC - A simple example SoC using PicoRV32
 *
 *  Copyright (C) 2017  Clifford Wolf <clifford@clifford.at>
 *
 *  Permission to use, copy, modify, and/or distribute this software for any
 *  purpose with or without fee is hereby granted, provided that the above
 *  copyright notice and this permission notice appear in all copies.
 *
 *  THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 *  WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 *  MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 *  ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 *  WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 *  ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 *  OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 *
 */

 // October 2019, Matthias Koch: Renamed wires

module buart (
   input clk,
   input resetq,

   output tx,
   input  rx,

   input  wr,
   input  rd,
   input  [7:0] tx_data,
   output [7:0] rx_data,

   output busy,
   output valid
);

   /************** Baud frequency constants ******************/

   parameter  FREQ_MHZ = 12;
   parameter  BAUDS    = 115200;

   localparam divider  = FREQ_MHZ * 1000000 / BAUDS;
   localparam divwidth = $clog2(divider);

   localparam baud_init = divider;
   localparam half_baud_init = divider/2+1;

   /************* Receiver ***********************************/

   reg [3:0] recv_state;
   reg [divwidth-1:0] recv_divcnt;   // Counts to divider. Reserve enough bits !
   reg [7:0] recv_pattern;

   reg [7:0] recv_buf_data;
   reg recv_buf_valid;

   assign rx_data = recv_buf_data;
   assign valid = recv_buf_valid;

   always @(posedge clk) begin
       if (!resetq) begin

           recv_state <= 0;
           recv_divcnt <= 0;
           recv_pattern <= 0;
           recv_buf_data <= 0;
           recv_buf_valid <= 0;

       end else begin
           recv_divcnt <= recv_divcnt + 1;

           if (rd) recv_buf_valid <= 0;

           case (recv_state)
               0: begin
                   if (!rx)
                       recv_state <= 1;
                   recv_divcnt <= 0;
               end
               1: begin
                   if (2*recv_divcnt == divider+1) begin
                       recv_state <= 2;
                       recv_divcnt <= 0;
                   end
               end
               10: begin
                   if (recv_divcnt == divider+1) begin
                       recv_buf_data <= recv_pattern;
                       recv_buf_valid <= 1;
                       recv_state <= 0;
                   end
               end
               default: begin
                   if (recv_divcnt == divider+1) begin
                       recv_pattern <= {rx, recv_pattern[7:1]};
                       recv_state <= recv_state + 1;
                       recv_divcnt <= 0;
                   end
               end
           endcase
       end
   end

   /************* Transmitter ******************************/

   reg [9:0] send_pattern;
   reg [3:0] send_bitcnt;
   reg [divwidth-1:0] send_divcnt;
   reg send_dummy;

   assign busy = (send_bitcnt || send_dummy);
   assign tx = send_pattern[0];

   always @(posedge clk) begin
       send_divcnt <= send_divcnt + 1;
       if (!resetq) begin
           send_pattern <= ~0;
           send_bitcnt <= 0;
           send_divcnt <= 0;
           send_dummy <= 1;
       end else begin
           if (send_dummy && !send_bitcnt) begin
               send_pattern <= ~0;
               send_bitcnt <= 15;
               send_divcnt <= 0;
               send_dummy <= 0;
           end else
           if (wr && !send_bitcnt) begin
               send_pattern <= {1'b1, tx_data[7:0], 1'b0};
               send_bitcnt <= 10;
               send_divcnt <= 0;
           end else
           if (send_divcnt == divider+1 && send_bitcnt) begin
               send_pattern <= {1'b1, send_pattern[9:1]};
               send_bitcnt <= send_bitcnt - 1;
               send_divcnt <= 0;
           end
       end
   end

endmodule
