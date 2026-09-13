.section .text
.align 2
.globl _start

_start:
    # Define the GPIO control register base address and offsets
    .equ GPIO_BASE_CTRL_ADDR,  0x10012000    # Base address for GPIO control registers
    .equ GPIO_INPUT_VAL,       0x00
    .equ GPIO_INPUT_EN,        0x04
    .equ GPIO_OUTPUT_EN,       0x08
    .equ GPIO_OUTPUT_VAL,      0x0C

    # Define GPIO Pin Mapping for LEDs (8 LEDs in LED bar, LED6)
    .equ GPIO_LEDBAR_PINS,     0x00FC0C00    # LED Bar Pins (8)
    .equ GPIO_LEDBAR_LED_6,    0x00400000    # LED_6
    .equ GPIO_BUTTON_S1,       0x00001000    # S1 pushbutton on GPIO 12

    li s1, GPIO_BASE_CTRL_ADDR    # GPIO base address

    # Define GPIO Pin Mapping for LEDs (8 LEDs in LED bar, LED6)
    li s2, GPIO_LEDBAR_PINS       # LED bar GPIO bits: 23:18 and 11:10
    li s3, GPIO_LED6_PIN          # LED_6 on GPIO 22

    # Configure the GPIO Outputs for all LEDs
    sw s2, GPIO_OUTPUT_EN(s1)

    # Define GPIO Pin Mapping for Pushbuttons (S1)
    li s5, GPIO_BUTTON_S1         # S1 pushbutton

    # Configure the GPIO Inputs for the pushbuttons used (S1)
    sw s5, GPIO_INPUT_EN(s1)

    # Turn off all LEDs
    li t1, 0x0
    sw t1, GPIO_OUTPUT_VAL(s1)

# ---------------------- Initialize the pseudo-random number generator -----------------------
InitRandomNum:
    # Sets a7 to a 16-bit non-zero value; only the PRNG subroutine should modify a7
    li a7, 0xABCD


# Task_1:
    # jal ra, AllLedsOff
    # li a0, 0

# loop:
    # jal ra, WriteLedBar
    # jal ra, Delay

    # li t0, 0xFF
    # beq a0, t0, Task_1
    # addi a0, a0, 1
    # j loop


# ---------------------------------- Task 2: Reflex Meter -----------------------------------
Task_2:
    jal ra, AllLedsOff
    jal ra, RandomNum
    jal ra, Scale
    jal ra, WaitScaledDelay
    jal ra, TurnOnLed6

    li s9, 0    # Initialize counter

    Task_2_TimerLoop:
        jal ra, Delay_0p1ms         # Delay 0.1ms
        addi s9, s9, 1              # counter++
        lw t1, GPIO_INPUT_VAL(s1)   # Get state of S1 button
        and t1, t1, s5              # Keep only S1 bit
        bnez t1, Task_2_TimerLoop   # Poll until button pressed

    jal ra, AllLedsOff

    # Lowest 8 bits
    andi a0, s9, 0xFF     # Store as argument
    jal ra, WriteLedBar   # Turn on LEDs based on current 8 bits
    jal ra, Delay2Seconds

    # Next 8 bits
    srli t0, s9, 8      # Using shift to avoid upper immediate loading when masking
    andi a0, t0, 0xFF   # Masking lower 8 bits
    jal ra, WriteLedBar
    jal ra, Delay2Seconds

    # Next 8 bits
    srli t0, s9, 16
    andi a0, t0, 0xFF
    jal ra, WriteLedBar
    jal ra, Delay2Seconds

    # Last 8 bits
    srli t0, s9, 24
    andi a0, t0, 0xFF
    jal ra, WriteLedBar
    jal ra, Delay2Seconds

    jal ra, AllLedsOff
    jal ra, Delay5Seconds
    j Task_2


# ---------------------------------------- Scaling -------------------------------------------
# Scaling the random number generated (a7) between 2 and 10 sec
Scale:
    mv t0, a7   # Prevent changing a7
    li t1, 9    # Compare using 9 because of range

    ScaleReduce:              # Reduce by range until within range
        bltu t0, t1, ScaleDone    # t0 < 9
        addi t0, t0, -9
        j ScaleReduce

    ScaleDone:
        addi a0, t0, 2    # Add 2 to final result to scale from 2-10 instead of 0-8
        ret


# ------------------------- Pseudo-Random Number Generator ------------------------------
# Register a7 will hold the generated random number
# You may read this register anywhere in your program.
# Important: Only this subroutine should write to a7.
RandomNum:
    addi sp, sp, -16
    sw ra, 12(sp)                  # Save return address

    li s4, 0x8000                  # Select bit 15 of a7
    and t1, a7, s4                 # Extract bit 15

    li s4, 0x2000                  # Select bit 13 of a7
    and t3, a7, s4                 # Extract bit 13

    slli t3, t3, 2                 # Shift extracted bit 13 left by 2
    xor t3, t1, t3                 # Combine with extracted bit 15

    li s4, 0x1000                  # Select bit 12 of a7
    and t1, a7, s4                 # Extract bit 12

    slli t1, t1, 3                 # Shift extracted bit 12 left by 3
    xor t3, t3, t1                 # Combine with previous result

    andi t1, a7, 0x0400            # Select bit 10 of a7
    slli t1, t1, 5                 # Shift bit 10 left by 5
    xor t3, t3, t1                 # Combine with previous result

    srli t3, t3, 15                # Shift result right by 15
    slli a7, a7, 1                 # Shift a7 left by 1
    or a7, a7, t3                  # Update a7 with new pseudo-random value

    lw ra, 12(sp)                  # Restore return address
    addi sp, sp, 16                # Restore stack pointer
    ret                             # Return from subroutine


AllLedsOff:
    li t1, 0x0
    sw t1, GPIO_OUTPUT_VAL(s1)
    ret


WriteLedBar:
    andi t1, a0, 0x03   # 2 LSB of a0
    slli t1, t1, 10     # GPIO corresponding to these 2 bits

    andi t2, a0, 0xFC   # Upper 6 bits
    slli t2, t2, 16     # GPIO for these 6 bits

    or t1, t1, t2       # Combine the 2 into final GPIO output
    sw t1, GPIO_OUTPUT_VAL(s1)
    ret


TurnOnLed6:
    li t1, GPIO_LEDBAR_LED_6
    sw t1, GPIO_OUTPUT_VAL(s1)
    ret


# ---------------------------- DELAY ROUTINES -----------------------
WaitScaledDelay:    # Wait for random delay
    addi sp, sp, -16    # Stack for return addr
    sw ra, 12(sp)
    li t0, a0

    WaitScaledDelayLoop:    # Wait in 1 second intervals
        jal ra, Delay1Second
        addi t0, t0, -1
        bnez t0, WaitScaledDelayLoop

    lw ra, 12(sp)
    addi sp, sp, 16
    ret

Delay2Seconds:
    li t4, 0xF42400   # 16,000,000

    Delay2SecondsLoop:
        addi t4, t4, -1
        bnez t4, Delay2SecondsLoop
        ret


Delay5Seconds:
    li t4, 0x2625A00   # 40,000,000

    Delay5SecondsLoop:
        addi t4, t4, -1
        bnez t4, Delay5SecondsLoop
        ret


Delay_01ms:
    li t4, 0x320   # 800

    01ms_loop:
        addi t4, t4, -1
        bnez t4, 01ms_loop
        ret


Delay1Second:
    li t4, 0x2625A0   # 2,500,000

    Delay1SecondLoop:
        addi t4, t4, -1
        bnez t4, Delay1SecondLoop
        ret


End:
    .end
