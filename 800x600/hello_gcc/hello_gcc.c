
// -----------------------------------------------------------------------------
//   Now go on with C
// -----------------------------------------------------------------------------

#include <stdint.h>

// -----------------------------------------------------------------------------
//   Timing
// -----------------------------------------------------------------------------

#define CYCLES_US    25
#define CYCLES_MS 25000

uint32_t cycles(void)
{
  uint32_t ticks;
  asm volatile ("rdcycle %0" : "=r"(ticks));
  return ticks;
}

void delay_cycles(uint32_t time)
{
  uint32_t now = cycles();
  while ( (cycles() - now) < time ) {};
}

void us(uint32_t time)
{
  delay_cycles(time * CYCLES_US);
}

void ms(uint32_t time)
{
  delay_cycles(time * CYCLES_MS);
}

// -----------------------------------------------------------------------------
//   Terminal IO
// -----------------------------------------------------------------------------

#define UART_DATA  *(volatile uint8_t  *) 0x4008
#define UART_FLAGS *(volatile uint32_t *) 0x4010

uint32_t keypressed(void)
{
  return 0x100 & UART_FLAGS ? -1 : 0;
}

uint8_t getchar(void)
{
  while ( 0x100 & ~UART_FLAGS) {};
  return UART_DATA;
}

void serial_putchar(uint8_t character)
{
  while ( 0x200 & UART_FLAGS) {};
  UART_DATA = character;
}

// -----------------------------------------------------------------------------
//   Random numbers
// -----------------------------------------------------------------------------

uint32_t randombit(void)
{
  delay_cycles(100);
  return 0x400 & UART_FLAGS ? 1 : 0;
}

uint32_t random(void)
{
  uint32_t randombits = 0;
  for (uint32_t i = 0; i < 32; i++)
  {
    randombits = randombits << 1 | randombit();
  }
  return randombits;
}

// -----------------------------------------------------------------------------
//   LEDs & IO
// -----------------------------------------------------------------------------

#define LEDS      *(volatile uint32_t  *) 0x4004

#define PORT_IN   *(volatile uint32_t  *) 0x4020
#define PORT_OUT  *(volatile uint32_t  *) 0x4040
#define PORT_DIR  *(volatile uint32_t  *) 0x4080

// -----------------------------------------------------------------------------
//   Textmode handling
// -----------------------------------------------------------------------------

#define XRES 100
#define YRES  36

// Arrays for font data and characters

volatile uint8_t *characters = (volatile uint8_t*) 0x8000;
volatile uint8_t *font       = (volatile uint8_t*) 0x8A00;

static uint32_t xpos = 0;
static uint32_t ypos = 0;
static uint32_t textmarker = 0;

void normal(void) // Default color
{
  textmarker = 0;
}

void highlight(void) // Highlight color
{
  textmarker = 0x80;
}

void clear(void) // Fills the complete screen buffer with spaces
{
  for (uint32_t pos = 0; pos < YRES*XRES; pos++) characters[pos] = 32;
  xpos = 0;
  ypos = 0;
  normal();
}

void addline(void)
{
  if (ypos < YRES-1)
  {
    ypos++;
  }
  else
  {
    uint32_t pos;
    for (pos=XRES;          pos < YRES*XRES; pos++) characters[pos-XRES] = characters[pos];
    for (pos=(YRES-1)*XRES; pos < YRES*XRES; pos++) characters[pos] = 32;
  }

  xpos = 0;
}

void addchar(uint8_t character)
{
  if (xpos > XRES-1) { addline(); xpos = 0; }
  characters[xpos + ypos*XRES] = character | textmarker;
  xpos++;
}

void stepback(void)
{
  if (xpos) { xpos--; }
  else
  {
    if (ypos)
    {
      ypos--;
      xpos = XRES-1;
    }
  }
  characters[xpos + ypos*XRES] = 32;
}

#define MIN(X, Y) (((X) < (Y)) ? (X) : (Y))
#define MAX(X, Y) (((X) > (Y)) ? (X) : (Y))

void vga_putchar(uint8_t character)
{
  switch (character)
  {
    case 10: addline();  break;
    case  8: stepback(); serial_putchar(32); serial_putchar(8); break;
    default: if ((character & 0xC0) != 0x80) addchar(MIN(character, 127));
  }
}

// -----------------------------------------------------------------------------
//   Output characters both to screen and serial terminal
// -----------------------------------------------------------------------------

void putchar(uint8_t character)
{
  serial_putchar(character);
  vga_putchar(character);
}

// -----------------------------------------------------------------------------
//   Pretty printing
// -----------------------------------------------------------------------------

void print_string(const char* s)
{
  for(const char* p = s; *p; ++p) putchar(*p);
}

void print_hex_digit(uint32_t digit)
{
  digit = digit & 15;
  putchar(digit < 10 ? digit + 48 : digit + 55);
}

void print_hex_byte(uint32_t hex)
{
  print_hex_digit(hex >> 4);
  print_hex_digit(hex);
}

void print_hex_word(uint32_t hex)
{
  print_hex_byte(hex >> 24);
  print_hex_byte(hex >> 16);
  print_hex_byte(hex >>  8);
  print_hex_byte(hex);
}

uint8_t segmentfont[16] = {
  0b0111111, // 0
  0b0000110, // 1
  0b1011011, // 2
  0b1001111, // 3
  0b1100110, // 4
  0b1101101, // 5
  0b1111101, // 6
  0b0000111, // 7
  0b1111111, // 8
  0b1101111, // 9
  0b1110111, // A
  0b1111100, // B
  0b0111001, // C
  0b1011110, // D
  0b1111001, // E
  0b1110001  // F
};

// -----------------------------------------------------------------------------
//   Main
// -----------------------------------------------------------------------------

void main(void)
{
  clear();

  putchar(10);
  highlight();

  print_string("RISC-V Playground on Nandland Go\n");

  normal();
  putchar(10);

  // A little bit of artwork, does not fit in memory together with the terminal...

  // while (1)
  // {
  //   characters[((random() & 15) + 7) * XRES + (random() & 63) + 8] = (random() & 0x80) | (random() & 1 ? 0x2F : 0x5C);
  //   ms(10);
  // }

  // Serial terminal on VGA

  uint32_t character = 0;

  while (1)
  {
    if (keypressed())
    {
      character = getchar();
      putchar(character);
    }
    uint32_t buttons = PORT_IN >> 8;
    LEDS = (segmentfont[(character>>4)&15] << 7) | segmentfont[character&15] | buttons << 14;
  }
}
