.section .text
.align 2
.globl _start
# --------------------------------------------------------------------------------------------------------------
# Constants and Register Definitions
# --------------------------------------------------------------------------------------------------------------
# GPIO base and offsets (from Lab 3 template)
.equ GPIO_BASE_CTRL_ADDR,      0x10012000
.equ GPIO_INPUT_VAL,           0x00
.equ GPIO_INPUT_EN,            0x04
.equ GPIO_OUTPUT_EN,           0x08
.equ GPIO_OUTPUT_VAL,          0x0C
.equ GPIO_FALL_IE,             0x20
.equ GPIO_FALL_IP,             0x24
# LED bar and pushbutton mappings (from Lab 3 template)
.equ GPIO_LEDBAR_PINS,         0x00FC0C00
.equ GPIO_BUTTON_S1,           0x00001000
# FE310 PLIC addresses and S1 interrupt source
.equ PLIC_BASE_ADDR,           0x0C000000
.equ PLIC_ENABLE_BASE,         0x00002000
.equ PLIC_THRESHOLD_BASE,      0x00200000
.equ PLIC_CLAIM_BASE,          0x00200004
.equ S1_PLIC_ID,               20
.equ S1_PLIC_ENABLE_MASK,      0x00100000
.equ PLIC_S1_PRIORITY_OFFSET,  0x50


_start:
# Set up mtvec with the address of the interrupt vector (S1_interrupt)
    la t0, S1_interrupt            # Load the address of the interrupt handler 'S1_interrupt' into t0
                                    # S1_interrupt represents the Interrupt Service Routine (ISR) found at the bottom of the code
    csrw mtvec, t0                 # csrw: CSR write, writes the value in register t0 (which is the
                                    # address of the interrupt handler) to the mtvec register.
                                    # Set the mtvec register to the address in t0 (S1_interrupt)
# Enable "External" machine interrupts in the mie register
    li t0, (1 << 11)                # Set bit 11 to "1" and write it to t0
                                     # This bit (bit 11) corresponds to the external interrupt enable
    csrs mie, t0                    # csrs: CSR Set, it performs a bitwise OR between the current
                                     # value of mie and the value in t0
                                     # Set bit 11 in the mie register (enable external interrupts)
# mtvec: Machine Trap Vector register, it stores the address of the interrupt handler
# directing the processor to jump to this address, S1_interrupt, when an interrupt occurs.
# Enable global machine interrupts (MIE, bit 3 of mstatus)
    csrr t0, mstatus                # read the value of the mstatus into t0
    li t1, (1 << 3)                 # Set MIE (Machine Interrupt Enable)
                                     # (1<<3): this instruction puts "1" at the 3rd bit
    or t0, t0, t1                   # add t0 "mstatus" to t1, where we actually are setting bit 3 to "1"
                                     # This sets the 3rd bit (MIE) in t0 without modifying other bits
    csrw mstatus, t0                # Write the modified value in t0 back to the mstatus register


    li s1, GPIO_BASE_CTRL_ADDR      # GPIO base address
    li s2, GPIO_LEDBAR_PINS         # LED bar mask
    li s5, GPIO_BUTTON_S1           # S1 button mask
    li s6, PLIC_BASE_ADDR           # PLIC base address
# ------------------------------ Configure SW1 as an input ------------------------------
    sw s5, GPIO_INPUT_EN(s1)
# ----------------------- Configure GPIO LEDs pins as an output -------------------------
    sw s2, GPIO_OUTPUT_EN(s1)
# ---------------------------- Turn Off all LEDs in LED Bar -----------------------------
    jal AllLedsOff
# ------------ Enable Falling edge for S1: Remember S1 is a GPIO and not PLIC -----------
    sw s5, GPIO_FALL_IE(s1)
    sw s5, GPIO_FALL_IP(s1)          # Clear stale pending flag before enabling PLIC


# ---------------------------- Enable PLIC for S1 interrupt -----------------------------
    li t0, PLIC_ENABLE_BASE
    add t0, s6, t0
    lw t1, 0(t0)
    li t2, S1_PLIC_ENABLE_MASK       # Source ID 20 => bit 20
    or t1, t1, t2
    sw t1, 0(t0)
# ---------------- Set PLIC priority for S1 interrupt to 7 "Highest Priority" -----------
# ----------- The address is calculated according to: PLIC_BASE + 4 x S1_PLIC_ID --------
# ----------------------------- write the instructions here -----------------------------
    li t0, PLIC_S1_PRIORITY_OFFSET   # 4 * S1_PLIC_ID = 0x50
    add t0, s6, t0
    li t1, 7
    sw t1, 0(t0)


# ------------------------------- Set PLIC threshold to 6 -------------------------------
# ----------------------------- write the instructions here -----------------------------
    li t0, PLIC_THRESHOLD_BASE
    add t0, s6, t0
    li t1, 6
    sw t1, 0(t0)


# Initialize pseudo-random generator and countdown timer
    li a7, 0xABCD                    # Non-zero PRNG seed
    li a4, 0                         # Countdown register


main_program:
# ------------------- Flashing the LEDS at a rate of 10 Hz (0.1 seconds) ----------------
# ----------------------------- write the instructions here -----------------------------
    li a4, 0xFF
    jal WriteLedBar
    jal Delay0p1Second
    jal AllLedsOff
    jal Delay0p1Second
    jal RandomNum
    j main_program


# Interrupt Service Routine (ISR) for S1 interrupt
.align 2
S1_interrupt:
# ----------------------------- Save Registers to Stack -----------------------------
    addi sp, sp, -24
    sw ra, 20(sp)
    sw t0, 16(sp)
    sw t1, 12(sp)
    sw t2, 8(sp)
    sw t3, 4(sp)
    sw t4, 0(sp)
# -------------------------- Acknowledge Interrupt in PLIC --------------------------
    li t0, PLIC_CLAIM_BASE
    add t0, s6, t0
    lw t2, 0(t0)                     # Claim interrupt source ID
    li t3, S1_PLIC_ID
    bne t2, t3, ISR_complete_only    # Service only S1/GPIO12 here


# ----------------------------- Delay-only ISR body ---------------------------
    jal ra, AllLedsOff
    jal ra, Scale


    WaitScaledDelayLoop:    # Wait in 1 second intervals
        jal WriteLedBar
        jal Delay1Second
        addi a4, a4, -10
        blt zero, a4, WaitScaledDelayLoop
    jal AllLedsOff
# -------------------------- Complete the Interrupt in the PLIC --------------------------
# ------------------------ Clear the falling interrupt pending in the GPIO ---------------
ISR_complete_only:
    sw s5, GPIO_FALL_IP(s1)          # Clear GPIO falling-edge pending bit
    li t0, PLIC_CLAIM_BASE
    add t0, s6, t0
    sw t2, 0(t0)                     # Write claim ID back to complete


# ----------------------------- Restore Registers & Return --------------------------
    lw t4, 0(sp)
    lw t3, 4(sp)
    lw t2, 8(sp)
    lw t1, 12(sp)
    lw t0, 16(sp)
    lw ra, 20(sp)
    addi sp, sp, 24
    mret                              # Return from interrupt


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
    sw zero, GPIO_OUTPUT_VAL(s1)
    ret


WriteLedBar:
    andi t1, a4, 0x03               # lower 2 bits -> GPIO[11:10]
    slli t1, t1, 10
    andi t3, a4, 0xFC               # upper 6 bits -> GPIO[23:18]
    slli t3, t3, 16
    or t1, t1, t3
    sw t1, GPIO_OUTPUT_VAL(s1)
    ret


Delay0p1Second:
    li t4, 0xC3500    # 800,000

    Delay_loop:
        addi t4, t4, -1
        bnez t4, Delay_loop
        ret

Delay1Second:
    li t4, 0x7A1200                  # 8,000,000 ~1 second


Delay1SecondLoop:
    addi t4, t4, -1
    bnez t4, Delay1SecondLoop
    ret


# Scaling the random number generated (a7) between 5.0 and 25.0 sec
Scale:
    andi a4, a7, 0xFF
    li t1, 201

    ScaleReduce:
        bltu a4, t1, ScaleDone
        addi a4, a4, -201

    ScaleDone:
        addi a4, a4, 50
        ret

End:
    .end
