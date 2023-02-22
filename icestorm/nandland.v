
`default_nettype none

`include "femtorv32_quark.v"
`include "uart.v"
`include "ringoscillator.v"
`include "simple_480p.v"

module top(input oscillator,
           output TXD,
           input  RXD,

           inout PORTA0,
           inout PORTA1,
           inout PORTA2,
           inout PORTA3,
           inout PORTA4,
           inout PORTA5,
           inout PORTA6,
           inout PORTA7,

           input S1,
           input S2,
           input S3,
           input S4,

           output reg D1,
           output reg D2,
           output reg D3,
           output reg D4,

           output reg Segment1A,
           output reg Segment1B,
           output reg Segment1C,
           output reg Segment1D,
           output reg Segment1E,
           output reg Segment1F,
           output reg Segment1G,
           output reg Segment2A,
           output reg Segment2B,
           output reg Segment2C,
           output reg Segment2D,
           output reg Segment2E,
           output reg Segment2F,
           output reg Segment2G,

           output reg VGA_HSync,
           output reg VGA_VSync,

           output reg VGA_Red_0,
           output reg VGA_Red_1,
           output reg VGA_Red_2,
           output reg VGA_Grn_0,
           output reg VGA_Grn_1,
           output reg VGA_Grn_2,
           output reg VGA_Blu_0,
           output reg VGA_Blu_1,
           output reg VGA_Blu_2
);

   /***************************************************************************/
   // Clock.
   /***************************************************************************/

   wire clk = oscillator; // Directly use 25 MHz

   /***************************************************************************/
   // Reset logic.
   /***************************************************************************/

   wire reset_button = ~(S2&S4);

   reg [7:0] reset_cnt = 0;
   wire resetq = &reset_cnt;

   always @(posedge clk, negedge reset_button) begin
     if (!reset_button) reset_cnt <= 0;
     else               reset_cnt <= reset_cnt + !resetq;
   end

   /***************************************************************************/
   // PMOD.
   /***************************************************************************/

   wire [7+4:0] port_in;
   reg  [7:0] port_out;
   reg  [7:0] port_dir;   // 1:output, 0:input

   SB_IO #(.PIN_TYPE(6'b1010_01)) io0 (.PACKAGE_PIN(PORTA0), .D_OUT_0(port_out[0]), .D_IN_0(port_in[0]), .OUTPUT_ENABLE(port_dir[0]));
   SB_IO #(.PIN_TYPE(6'b1010_01)) io1 (.PACKAGE_PIN(PORTA1), .D_OUT_0(port_out[1]), .D_IN_0(port_in[1]), .OUTPUT_ENABLE(port_dir[1]));
   SB_IO #(.PIN_TYPE(6'b1010_01)) io2 (.PACKAGE_PIN(PORTA2), .D_OUT_0(port_out[2]), .D_IN_0(port_in[2]), .OUTPUT_ENABLE(port_dir[2]));
   SB_IO #(.PIN_TYPE(6'b1010_01)) io3 (.PACKAGE_PIN(PORTA3), .D_OUT_0(port_out[3]), .D_IN_0(port_in[3]), .OUTPUT_ENABLE(port_dir[3]));
   SB_IO #(.PIN_TYPE(6'b1010_01)) io4 (.PACKAGE_PIN(PORTA4), .D_OUT_0(port_out[4]), .D_IN_0(port_in[4]), .OUTPUT_ENABLE(port_dir[4]));
   SB_IO #(.PIN_TYPE(6'b1010_01)) io5 (.PACKAGE_PIN(PORTA5), .D_OUT_0(port_out[5]), .D_IN_0(port_in[5]), .OUTPUT_ENABLE(port_dir[5]));
   SB_IO #(.PIN_TYPE(6'b1010_01)) io6 (.PACKAGE_PIN(PORTA6), .D_OUT_0(port_out[6]), .D_IN_0(port_in[6]), .OUTPUT_ENABLE(port_dir[6]));
   SB_IO #(.PIN_TYPE(6'b1010_01)) io7 (.PACKAGE_PIN(PORTA7), .D_OUT_0(port_out[7]), .D_IN_0(port_in[7]), .OUTPUT_ENABLE(port_dir[7]));

   assign port_in[ 8] = S1;
   assign port_in[ 9] = S2;
   assign port_in[10] = S3;
   assign port_in[11] = S4;

   /***************************************************************************/
   // Ring oscillator for random numbers.
   /***************************************************************************/

   wire random;
   ring_osc #( .NUM_LUTS(1) ) chaos ( .osc_out(random), .resetq(resetq) );

   /***************************************************************************/
   // VGA.
   /***************************************************************************/

   wire [9:0] xpos;
   wire [9:0] ypos;
   wire vga_blank, xblank, yblank, vga_enable, hsync, vsync;

   simple_480p syncgenerator (clk, ~resetq, xpos, ypos, hsync, vsync, vga_enable);

   reg  hsync_d1,  hsync_d2,  hsync_d3;
   reg  vsync_d1,  vsync_d2,  vsync_d3;
   reg enable_d1, enable_d2, enable_d3;

   always @(posedge clk)
   begin
     // The pixel pipeline needs three clock cycles to provide bitmap data after
     // the coordinates are valid. Delay the other VGA signals for three cycles to get in sync.

     hsync_d1 <= hsync;
     hsync_d2 <= hsync_d1;
     hsync_d3 <= hsync_d2;

     vsync_d1 <= vsync;
     vsync_d2 <= vsync_d1;
     vsync_d3 <= vsync_d2;

     enable_d1 <= vga_enable;
     enable_d2 <= enable_d1;
     enable_d3 <= enable_d2;

     VGA_HSync <= hsync_d3;
     VGA_VSync <= vsync_d3;

     {VGA_Red_2, VGA_Red_1, VGA_Red_0,
      VGA_Grn_2, VGA_Grn_1, VGA_Grn_0,              // Black (required by VGA during blanking)
      VGA_Blu_2, VGA_Blu_1, VGA_Blu_0} <= ~enable_d3 ? 9'b000_000_000 :
                                                    // Cyan (highlight)  Orange (normal)  Navy background
                       bitmap_shift[7] ? colorswitch ? 9'b000_111_111 :  9'b111_101_000 : 9'b000_000_011;
   end

   reg [7:0] characters [2559:0]; // [2399:0] is sufficient for 80x30, but RAM blocks come in 512 bytes...
   reg [7:0]       font [2047:0]; initial $readmemh("font-vga.hex", font);

   reg [7:0] char, bitmap, bitmap_shift;
   reg [3:0] fontrow, fontrow_delay;
   reg colorswitch, colorswitch_delay;

   wire [11:0] characterindex = xpos[2:0] == 3'b000 ? xpos[9:3] + 80 * ypos[9:4] : mem_address[11:0];
   wire [10:0]      fontindex = xpos[2:0] == 3'b001 ? {char[6:0], fontrow}       : mem_address[10:0];

   always @(posedge clk) // Pixel pipeline.
   begin
      // First cycle:
      char    <= characters[ characterindex ]; // 7-Bit ASCII. Using char[7] for highlight color.
      fontrow <= ypos[3:0];

      // Second cycle:
      bitmap            <= font[ fontindex ]; // 8x16 pixel font bitmap data.
      colorswitch_delay <= char[7];

      // Third cycle:
      if (xpos[2:0] == 3'b010) begin bitmap_shift <= bitmap; colorswitch <= colorswitch_delay; end
      else                     begin bitmap_shift <= {bitmap_shift[6:0], 1'b0}; end
   end

   // This is a little trick to coax a word-addressed CPU into byte aligned reads and writes:

   wire [31:0] char_rdata = {  char,   char,   char,   char};
   wire [31:0] font_rdata = {bitmap, bitmap, bitmap, bitmap};

   always @(posedge clk) begin

      if(mem_wmask[0] & mem_address_is_char) characters[mem_address[11:0]] <= mem_wdata[ 7:0 ];
      if(mem_wmask[1] & mem_address_is_char) characters[mem_address[11:0]] <= mem_wdata[15:8 ];
      if(mem_wmask[2] & mem_address_is_char) characters[mem_address[11:0]] <= mem_wdata[23:16];
      if(mem_wmask[3] & mem_address_is_char) characters[mem_address[11:0]] <= mem_wdata[31:24];

      if(mem_wmask[0] & mem_address_is_font)       font[mem_address[10:0]] <= mem_wdata[ 7:0 ];
      if(mem_wmask[1] & mem_address_is_font)       font[mem_address[10:0]] <= mem_wdata[15:8 ];
      if(mem_wmask[2] & mem_address_is_font)       font[mem_address[10:0]] <= mem_wdata[23:16];
      if(mem_wmask[3] & mem_address_is_font)       font[mem_address[10:0]] <= mem_wdata[31:24];

   end

   /***************************************************************************/
   // UART.
   /***************************************************************************/

   wire serial_valid, serial_busy;
   wire [7:0] serial_data;
   wire serial_wr = io_wstrb & mem_address[IO_UART_DAT_bit];
   wire serial_rd = io_rstrb & mem_address[IO_UART_DAT_bit];

   buart #(
     .FREQ_MHZ(25),
     .BAUDS(115200)
   ) buart (
      .clk(clk),
      .resetq(resetq),
      .rx(RXD),
      .tx(TXD),
      .rd(serial_rd),
      .wr(serial_wr),
      .valid(serial_valid),
      .busy(serial_busy),
      .tx_data(mem_wdata[7:0]),
      .rx_data(serial_data)
   );

   /***************************************************************************/
   // IO Ports.
   /***************************************************************************/

   // We get a total of 14 bits for 1-hot addressing of IO registers.
   // The two LSBs are for selecting bytes only, we can use bits 2 to 13.

   localparam IO_LEDS_bit      = 2; // RW LEDs and segments
   localparam IO_UART_DAT_bit  = 3; // RW write: data to send (8 bits) read: received data (8 bits)
   localparam IO_UART_CNTL_bit = 4; // R  status. bit 8: valid read data. bit 9: busy sending. bit 10: random.
   localparam IO_PORT_IN_bit   = 5; // R:  GPIO port in
   localparam IO_PORT_OUT_bit  = 6; // RW: GPIO port out
   localparam IO_PORT_DIR_bit  = 7; // RW: GPIO port dir

   wire [31:0] io_rdata =

      (mem_address[IO_UART_DAT_bit   ] |
       mem_address[IO_UART_CNTL_bit  ] ? {random, serial_busy, serial_valid, serial_data}  : 32'd0) |
      (mem_address[IO_PORT_IN_bit    ] ?  port_in                                          : 32'd0) |
      (mem_address[IO_PORT_OUT_bit   ] ?  port_out                                         : 32'd0) |
      (mem_address[IO_PORT_DIR_bit   ] ?  port_dir                                         : 32'd0) |
      (mem_address[IO_LEDS_bit       ] ? {D4, D3, D2, D1,

     ~Segment1G, ~Segment1F, ~Segment1E, ~Segment1D, ~Segment1C, ~Segment1B, ~Segment1A,
     ~Segment2G, ~Segment2F, ~Segment2E, ~Segment2D, ~Segment2C, ~Segment2B, ~Segment2A }  : 32'd0) ;


   always @(posedge clk)
   begin
     if (io_wstrb & mem_address[IO_LEDS_bit    ])
       {
         D4, D3, D2, D1,
         Segment1G, Segment1F, Segment1E, Segment1D, Segment1C, Segment1B, Segment1A,
         Segment2G, Segment2F, Segment2E, Segment2D, Segment2C, Segment2B, Segment2A
       } <= mem_wdata ^ 18'b0000_1111111_1111111; // Segments are active low

     if (io_wstrb & mem_address[IO_PORT_OUT_bit]) port_out <= mem_wdata;
     if (io_wstrb & mem_address[IO_PORT_DIR_bit]) port_dir <= mem_wdata;
   end

   // The processor reads the contents one clock cycle after the read strobe has been active.
   // Buffering it for getting IO register contents of the read strobe cycle.

   reg  [31:0] io_rdata_buffered;

   always @(posedge clk)
      if (mem_address_is_io & io_rstrb) io_rdata_buffered <= io_rdata;

   /***************************************************************************/
   // The memory bus.
   /***************************************************************************/

   // Memory map:
   //   mem_address[15:14] 00: RAM              (starts at 0x0000)
   //                      01: IO page (1-hot)  (starts at 0x4000)
   //                      10: Characters       (starts at 0x8000)
   //                      11: Font             (starts at 0xC000)

   wire [31:0] mem_address; // 16 bits are used internally. The two LSBs are usually ignored for word addresses
   wire  [3:0] mem_wmask;   // mem write mask and strobe /write Legal values are 000,0001,0010,0100,1000,0011,1100,1111
   wire [31:0] mem_rdata;   // processor <- (mem and peripherals)
   wire [31:0] mem_wdata;   // processor -> (mem and peripherals)
   wire        mem_rstrb;   // mem read strobe. Goes high to initiate memory read.
   wire        mem_rbusy;   // processor <- (mem and peripherals). Stays high until a read transfer is finished.
   wire        mem_wbusy;   // processor <- (mem and peripherals). Stays high until a write transfer is finished.

   /***************************************************************************/
   // The processor.
   /***************************************************************************/

   FemtoRV32 #(
     .RESET_ADDR(16'h0000),
     .ADDR_WIDTH(16)
   ) processor (
     .clk(clk),
     .mem_addr(mem_address),
     .mem_wdata(mem_wdata),
     .mem_wmask(mem_wmask),
     .mem_rdata(mem_rdata),
     .mem_rstrb(mem_rstrb),
     .mem_rbusy(mem_rbusy),
     .mem_wbusy(mem_wbusy),
     .reset(resetq)
   );

   // Wait for character or font data read being possible.
   // This is just the smallest possible logic that works, not the fastest.

   assign mem_rbusy = mem_address[15] & (xpos[2:0] != 3'b011);
   assign mem_wbusy = 0;

   /***************************************************************************/
   // Memory and register access control wires.
   /***************************************************************************/

   wire mem_wstrb = |mem_wmask; // mem write strobe, goes high to initiate memory write (deduced from wmask)

   // RAM, IO, characters or font?

   wire mem_address_is_ram       = (mem_address[15:14] == 2'b00);
   wire mem_address_is_io        = (mem_address[15:14] == 2'b01);
   wire mem_address_is_char      = (mem_address[15:14] == 2'b10);
   wire mem_address_is_font      = (mem_address[15:14] == 2'b11);

   wire io_rstrb = mem_rstrb & mem_address_is_io;
   wire io_wstrb = mem_wstrb & mem_address_is_io;

   /***************************************************************************/
   // RAM.
   /***************************************************************************/

   reg  [31:0] RAM[(1*1024/4)-1:0]; // Choose your firmware here:
   // initial $readmemh("../tinyblinky/tinyblinky.hex", RAM);
      initial $readmemh("../hello_gcc/hello_gcc.hex",   RAM);
   reg  [31:0] ram_rdata;

   always @(posedge clk) begin

     if(mem_wmask[0] & mem_address_is_ram) RAM[mem_address[9:2]][ 7:0 ] <= mem_wdata[ 7:0 ];
     if(mem_wmask[1] & mem_address_is_ram) RAM[mem_address[9:2]][15:8 ] <= mem_wdata[15:8 ];
     if(mem_wmask[2] & mem_address_is_ram) RAM[mem_address[9:2]][23:16] <= mem_wdata[23:16];
     if(mem_wmask[3] & mem_address_is_ram) RAM[mem_address[9:2]][31:24] <= mem_wdata[31:24];

     ram_rdata <= RAM[mem_address[9:2]];
   end

   /***************************************************************************/
   // Connect the read wires of memories and IO registers to the memory bus.
   /***************************************************************************/

   assign mem_rdata =

      (mem_address_is_ram       ? ram_rdata              : 32'd0) |
      (mem_address_is_io        ? io_rdata_buffered      : 32'd0) |
      (mem_address_is_char      ? char_rdata             : 32'd0) |
      (mem_address_is_font      ? font_rdata             : 32'd0) ;

endmodule // top
