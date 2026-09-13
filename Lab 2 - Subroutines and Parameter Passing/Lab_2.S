# ---------------------------- DATA SECTION -------------------------
.section .rodata          # Read-only data section for constants / lookup tables
.align 2                  # Align to 4-byte boundary (2^2 = 4)

# Input string (Message) to be sent / converted to Morse code
InputLUT:
    .asciz "AZDKS"

# Morse Code Look-Up Table
.align 2
MorseLUT:
    .half 0x17, 0x1D5, 0x75D, 0x75       # A, B, C, D
    .half 0x1, 0x15D, 0x1DD, 0x55        # E, F, G, H
    .half 0x5, 0x1777, 0x1D7, 0x175      # I, J, K, L
    .half 0x77, 0x1D, 0x777, 0x5DD       # M, N, O, P
    .half 0x1DD7, 0x5D, 0x15, 0x7        # Q, R, S, T
    .half 0x57, 0x157, 0x177, 0x757      # U, V, W, X
    .half 0x1D77, 0x775                  # Y, Z


# ---------------------------- CODE SECTION -------------------------
.section .text                          # Begin code section
.globl _start                           # Entry point
.align  2                               # Align to 4-byte boundary

_start:
    # GPIO Control Registers Memory Mapping
    # Refer to lab manual or SiFive FE310-G002 Manual v1p5
    .equ GPIO_BASE_CTRL_ADDR, 0x10012000    # Base address for GPIO control registers
    .equ GPIO_OUTPUT_EN,      0x08          # Offset to enable GPIO outputs
    .equ GPIO_OUTPUT_VAL,     0x0C          # Offset to write GPIO outputs

    # LED Pin Masks
    .equ GPIO_7SEGLED_PINS, 0x0000023F      # Seven Segment LED Display Pins (7)
    .equ GPIO_LEDBAR_PINS,  0x00FC0C00      # LED Bar Pins (8)
    .equ GPIO_ALL_LED_PINS, 0x00FC0E3F      # All LED Pins (15)
    .equ GPIO_LEDBAR_LED_7, 0x800000        # LEDBAR LED7 (Bit ??)

    # Initialize GPIO outputs
    li t0, GPIO_BASE_CTRL_ADDR
    li t1, GPIO_ALL_LED_PINS

    sw t1, GPIO_OUTPUT_EN(t0)

    # Turn off all LEDs
    li t1, 0x0
    sw t1, GPIO_OUTPUT_VAL(t0)


# ---------------------------- MAIN LOOP -----------------------------
# Initialize pointer and start processing each character of the input string
InputPointer:
    la s1, InputLUT                     # Load address of input string into s1

# Process each character in the input string
NextChar:
    lbu a0, 0(s1)                       # Load next character into a0 (unsigned)
    addi s1, s1, 1                      # Increment pointer to next character
    snez a1, a0                         # Set a1 = 1 if a0 != 0 (not null)
    beqz a1, EndOfString                # If reached end of word
    jal ra, CHAR2MORSE
    j NextChar                          # Restart with next character
EndOfString:
    # 2s Delay (added onto 1.5s delay inside CHAR2MORSE)
    jal ra, Delay
    j InputPointer                      # Restart from first letter of the word


# ---------------------------- SUBROUTINES ---------------------------
# Converts an ASCII uppercase letter (A-Z) into its Morse pattern and Flash the LED according to the pattern
CHAR2MORSE:
    # Allocate stack space for s1 and ra
    addi sp, sp, -8
    sw s1, 0(sp)
    sw ra, 4(sp)

    li t3, 0x41                # Load ASCII value of 'A'
    sub t2, a0, t3              # Convert ASCII character to 0-based index (A=0, B=1, ...)
    li t3, 2                    # Each Morse LUT entry is 2 bytes (halfword)
    mul t2, t2, t3              # Get byte offset into MorseLUT (index * 2)

    la t3, MorseLUT
    add t2, t2, t3              # Get offset address for letter from MorseLUT
    lh t3, 0(t2)                # Load into t3

    li t5, 16                   # Initialize 16-bit counter

    loop:
        slli t3, t3, 1          # Shift left to skip leading zeros
        addi t5, t5, -1         # Decrement bit count
        li s1, 0x8000           # Mask for most significant bit
        and t2, t3, s1          # Check if MSB is 1
        beqz t2, loop           # If MSB is 0, continue skipping bits

    loop2:
        and t2, t3, s1          # Get MSB of pattern
        beqz t2, turn_off       # Turn LED off if = 0

        turn_on:
            jal ra, LED_ON
            jal ra, Delay        # 0.5s delay
            j continue           # Skip turn_off path

        turn_off:
            jal ra, LED_OFF
            jal ra, Delay
            j continue

        continue:
            slli t3, t3, 1      # Shift next bit
            addi t5, t5, -1     # Decrement bit counter
            bnez t5, loop2      # Continue until all bits are processed (counter = 0)

    jal ra, LED_OFF              # LED is off after character finishes
    jal ra, Delay                # 1.5s delay
    jal ra, Delay
    jal ra, Delay

    # Restore stack
    lw s1, 0(sp)
    lw ra, 4(sp)
    addi sp, sp, 8

    ret


# ---------------------------- LED CONTROL ---------------------------
# Turn On LED7
LED_ON:
    li t1, GPIO_LEDBAR_LED_7
    sw t1, GPIO_OUTPUT_VAL(t0)
    ret

# Turn LED7 off
LED_OFF:
    li t1, 0x0
    sw t1, GPIO_OUTPUT_VAL(t0)
    ret

# ---------------------------- DELAY ROUTINES -----------------------
Delay: # 0.5s delay
    li t4, 0x3D0900              # # of cycles

    loop1:
        addi t4, t4, -1
        bnez t4, loop1

    ret

End:
    .end


# --------------------------------------------------------------------

# Character input string: "AZDKS"

# A: 1 0111
# 1.5 sec: 000
# Z: 111 0111 0101
# 1.5 sec: 000
# D: 111 0101
# 1.5 sec: 000
# K: 1 1101 0111
# 1.5 sec: 000
# S: 1 0101
# 1.5 sec: 000
# 2.0 sec: 0000

# Final Morse Pattern: 10111000111011101010001110101000111010111000101010000000
