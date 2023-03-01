
RISC-V Playground for Nandland Go
---------------------

This projects contains an example for a simple RISC-V RV32I microcontroller
based on the FemtoRV32-Quark written by Bruno Levy and Matthias Koch:

[https://github.com/BrunoLevy/learn-fpga/](https://github.com/BrunoLevy/learn-fpga/)

[https://github.com/BrunoLevy/learn-fpga/blob/master/FemtoRV/RTL/PROCESSOR/femtorv32_quark.v](https://github.com/BrunoLevy/learn-fpga/blob/master/FemtoRV/RTL/PROCESSOR/femtorv32_quark.v)

Peripherals included for default:

  - VGA 640x480 textmode with 7-Bit ASCII 8x16 font
  - Random number generator
  - GPIO registers for PMOD pin access
  - Buttons, LEDs and two digit seven segment display
  - UART terminal, 115200 Baud 8N1
  - 2 kb initialised RAM

Memory map and IO
---------------------

Memory areas are selected using bits [15:14].

* 0x0000 - 0x07FF: 2 kb initialised RAM for firmware
* 0x4000 - 0x7FFF: Peripheral IO registers
* 0x8000 - 0x89FF: 2560 bytes character buffer, 80x30=2400 chars visible, byte access only
* 0x8A00 - 0x8FFF: 1536 bytes font data, 96 characters, 16 bytes per character, byte access only

For using the display, all you have is to write characters into the 2400 bytes starting
at 0x8000. The font (starting at 0x8A00) contains 96 glyphs (32 to 127), taken from FreeBSD "iso-8x16"
bitmap font. The MSB (0x80) selects a "highlight" color.

The ten glyphs for ASCII 22 to 31 are in the invisible part of the character memory area
from 0x8960 (=80*30+0x8000) to 0x89FF and can be freely used for custom characters.

Both character and font data areas can be read and written using byte access only.

The IO registers with base 0x4000 are word addressable.

* 0x4004: RW  [17:14] Four LEDs [13:7] Left segment digit [6:0] Right segment digit

* 0x4008: RW  Serial terminal. Write: Send character [7:0]. Read: Received character [7:0] and flags.
* 0x4010: RO  For reading flags [10] Random [9] Busy [8] Valid without removing character [7:0] from receive FIFO.

* 0x4020: RO  [7:0] PMOD IN   [11:8] Buttons
* 0x4040: RW  [7:0] PMOD OUT
* 0x4080: RW  [7:0] PMOD DIR

Bits [13:2] are one-hot decoded. Every register has its own bit, which simplifies
the decoding logic, and also allows to set multiple registers at once.

The serial terminal flags contain a ring oscillator used for random numbers,
but wait (a few) 100 clock cycles before capturing the next random bit because
one gets correlations between the bits when reading too fast.
Just give the ring oscillator a little bit of time to drift away.

Reset the CPU by pressing S2 & S4 at once. This does not, however, reload the bitstream with the memory initialisation. It just re-starts with the memory as left before.

Example firmware
---------------------

Tinyblinky:

  A little blinky in RISC-V assembler. A nice "hello world" project.

Mandelbrot:

  Explore the Mandelbrot and Tricorn fractals in ASCII art.

Hello GCC:

  A small project in C featuring serial terminal, buttons, LEDs and VGA.

How to build and use
---------------------

Run the "compile" script.

For flashing the bitstream, use:

  iceprog nandland.bin

Open terminal with 115200 baud 8N1 on the second interface offered by the Nandland Go, for example /dev/ttyUSB1

Docs on RISC-V itself
---------------------

Instruction set quick reference, recommended:

  [http://www.riscvbook.com/greencard-20181213.pdf](http://www.riscvbook.com/greencard-20181213.pdf)

Complete specifications:

  [https://riscv.org/technical/specifications/](https://riscv.org/technical/specifications/)

See `Volume 1, Unprivileged Spec` for instruction set,
and `Volume 2, Privileged Spec` for interrupt infrastructure.

Toolchain "installation" for FPGA
---------------------

Get the latest package for your computers architecture: [https://github.com/YosysHQ/oss-cad-suite-build/releases](https://github.com/YosysHQ/oss-cad-suite-build/releases)

Unpack the toolchain to a suitable place, and - assuming you use Linux - include the toolchain temporarily to your path with the command `source ~/path/to/oss-cad-suite/environment`. This allows to have multiple versions installed on your computer, but just go for the lastest. One note: Do not try to install packaged Yosys/NextPNR/Icestorm tools that might come with your distro -- the toolchain is advancing very, very quick, and if your distro packaged it three months ago, it is already heavily outdated. The ones in Debian Stable -- Ouch!

Get RISC-V assembler
---------------------

The GNU binutils for RISC-V include the assembler.

Unlike as for the FPGA tools that change rapidly,
you can just have a look for binary packages in your distribution.

For Debian 11 Stable "Bullseye", one gets using

  apt-cache search binutils | grep riscv

binutils-riscv64-linux-gnu - GNU binary utilities, for riscv64-linux-gnu target
binutils-riscv64-linux-gnu-dbg - GNU binary utilities, for riscv64-linux-gnu target (debug symbols)
binutils-riscv64-unknown-elf - GNU assembler, linker and binary utilities for RISC-V processors

Both binutils-riscv64-linux-gnu and binutils-riscv64-unknown-elf are fine,
but you might have to adjust the actual invocations to the tools depending
on which package(s) you actually installed.

Despite the names, these also support 32 bit RISC-V targets.

Guide for complete newbies to FPGAs
---------------------

Let's try for short:

For a bunch of TTL logic chip to do something useful, you need to wire them up - and the way you wire these determines the function of the completed circuit.

A "Field Programmambe Gate Array" contains a grid of "universal gates" called lookup-tables with -in our case- 4 binary inputs and 1 output, and every of these is accompanied by 1 flipflop bit. Nothing special so far. The special sauce of an FPGA is their connection - that there is a dense mesh of wires in different lengths that crisscross the entire chip, with switchbox points that allow to choose how to connect the individual logic elements to the mesh of wires. By selecting which switchboxes to activate, one builds an actual digital circuit on the FPGA.

For your curiosity, here is a DIY FPGA: [http://blog.notdot.net/2012/10/Build-your-own-FPGA](http://blog.notdot.net/2012/10/Build-your-own-FPGA)

You should have an idea by now! You are going to build logic circuits. And you'll probably fall into a rabbit hole :-)

I would love to give you a complete intro, but for time-is-not-infinite reasons, recommend you intros from others instead.

For the ones that prefer reading and want to know everything to design their own RISC-V CPU at the end of the course:

[https://github.com/BrunoLevy/learn-fpga/tree/master/FemtoRV/TUTORIALS/FROM_BLINKER_TO_RISCV](https://github.com/BrunoLevy/learn-fpga/tree/master/FemtoRV/TUTORIALS/FROM_BLINKER_TO_RISCV)

For the ones that prefer videos and a calm pace, Shawn Hymel has done a series in 12 parts that really starts at the beginning and explains the scenery you encounter:

[https://github.com/ShawnHymel/introduction-to-fpga](https://github.com/ShawnHymel/introduction-to-fpga)


[https://www.digikey.de/en/maker/projects/introduction-to-fpga-part-1-what-is-an-fpga/3ee5f6c8fa594161a655a9f960060893](https://www.digikey.de/en/maker/projects/introduction-to-fpga-part-1-what-is-an-fpga/3ee5f6c8fa594161a655a9f960060893)
