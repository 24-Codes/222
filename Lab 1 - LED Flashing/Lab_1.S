.section .text          # Begin code (text) section — stores executable instructions
.globl  _start          # Make the '_start' label globally visible to the linker as entry point
.align  2               # Align the next instruction to a 4-byte boundary (2^2 = 4) for efficiency

_start:

# Define base address and offsets for GPIO control registers (memory-mapped I/O)
# Refer to the lab manual or SiFive FE310-G002 Manual v1p5 on Learn for more info about the addresses
.equ GPIO_BASE_CTRL_ADDR,  0x10012000    # Base address for the GPIO control registers
.equ GPIO_OUTPUT_EN,       0x08          # Address offset for enabling GPIO outputs
.equ GPIO_OUTPUT_VAL,      0x0C          # Address offset for writing to GPIO outputs

# Determine the correct bitmask values (in hex) for: LED Bar Pins, Seven Segment LED Display Pins
# All LED Pins, and LEDBAR LED1. Example is given here for GPIO_7SEGLED_PINS
.equ GPIO_7SEGLED_PINS,    0x0000023F    # Seven Segment LED Display Pins (7)
.equ GPIO_LEDBAR_PINS,     0x00FC0C00    # LED Bar Pins (8)
.equ GPIO_ALL_LED_PINS,    0x00FC0E3F    # All LED Pins (15)
.equ GPIO_LEDBAR_LED_1,    0x800         # LEDBAR LED1 (Bit 11)

# Initialize the GPIO control registers (configure all LEDs as output)
    li  t0, GPIO_BASE_CTRL_ADDR
    li  t1, GPIO_ALL_LED_PINS

    sw  t1, GPIO_OUTPUT_EN(t0)      # Store all LEDs to address for output enabling

# Turn Off all LEDs
    li  t1, 0x0                     # Make all LEDs 0
    sw  t1, GPIO_OUTPUT_VAL(t0)     # Store new LED state to output

# Turn On (toggle) LED1
    li  t1, GPIO_LEDBAR_LED_1
    sw  t1, GPIO_OUTPUT_VAL(t0)     # Store new LED 11 on state into output address

# Store addresses into registers for loop operations
    li  t3, GPIO_LEDBAR_LED_1
    lw  t2, GPIO_OUTPUT_VAL(t0)

loop:
    li  t4, 0x3D0900                # 4,000,000 iterations

loop1:
    addi t4, t4, -1                 # Decrement counter by 1
    bnez t4, loop1                  # Return to top of loop1 if counter not completed

    xor t2, t2, t3                  # Use xor to get address for LED states from on -> off, vice versa
    sw  t2, GPIO_OUTPUT_VAL(t0)     # Store LED state into output

    beqz t4, loop                   # Unconditional since counter will always be 0 here, return to top of loop


# ------------------------------------------------------------------

# addi t4, t3, 0x100

# imm[11:0]: 000100000000
# rs1: 11100
# funct3: 000
# rd: 11101
# opcode: 0010011

# Machine code (binary): 000100000000_11100_000_11101_0010011 or 0001_0000_0000_1110_0000_1110_1001_0011
