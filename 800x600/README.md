
RISC-V Playground for Nandland Go, 800x600 version
---------------------

Changes relative to the vanilla 640x480 version:

  - Clock doubler to 50 MHz
  - VGA 800x600 textmode with 7-Bit ASCII 8x16 font
  - 1 kb initialised RAM

Memory map and IO
---------------------

Memory areas are selected using bits [15:14].

* 0x0000 - 0x03FF: 1 kb initialised RAM for firmware
* 0x4000 - 0x7FFF: Peripheral IO registers
* 0x8000 - 0x8E0F: 3600 bytes character buffer, 100x36=3600 chars visible, byte access only
* 0x8E10 - 0x93FF: 1520 bytes font data, 95 characters, 16 bytes per character, byte access only

For using the display, all you have is to write characters into the 3600 bytes starting
at 0x8000. The font (starting at 0x8E10) contains 95 glyphs (32 to 126), taken from FreeBSD "iso-8x16"
bitmap font. The DEL glyph 127 is missing.

The MSB (0x80) selects a "highlight" color.
