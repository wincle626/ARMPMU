;; Bare-metal startup code for Cortex-A8 on Beagle Board
;;
;; Vector table, reset handler, stacks, interrupt handler, cache & MMU config, NEON enable.
;;
;; Copyright ARM Ltd 2002-2012. All rights reserved.


; Standard definitions of mode bits and interrupt (I & F) flags in PSRs

Mode_USR        EQU     0x10
Mode_FIQ        EQU     0x11
Mode_IRQ        EQU     0x12
Mode_SVC        EQU     0x13
Mode_ABT        EQU     0x17
Mode_UND        EQU     0x1B
Mode_SYS        EQU     0x1F

I_Bit           EQU     0x80 ; when I bit is set, IRQ is disabled
F_Bit           EQU     0x40 ; when F bit is set, FIQ is disabled


    PRESERVE8

    AREA   VECTORS, CODE, READONLY   ; name this block of code

    ENTRY


; StartHere is the Entry point for the Reset handler

    EXPORT StartHere

StartHere

;***********************
; Exception Vector Table
;***********************

; Note: LDR PC instructions are used here, though branch (B) instructions
; could also be used, unless the exception handlers are >32MB away.

Vectors
    LDR PC, Reset_Addr
    LDR PC, Undefined_Addr
    LDR PC, SVC_Addr
    LDR PC, Prefetch_Addr
    LDR PC, Abort_Addr
    B .                             ; Reserved vector
    LDR PC, IRQ_Addr
    LDR PC, FIQ_Addr


Reset_Addr      DCD     Reset_Handler
Undefined_Addr  DCD     Undefined_Handler
SVC_Addr        DCD     SVC_Handler
Prefetch_Addr   DCD     Prefetch_Handler
Abort_Addr      DCD     Abort_Handler
IRQ_Addr        DCD     IRQ_Handler
FIQ_Addr        DCD     FIQ_Handler


;***********************
; Exception Handlers
;***********************

; The following dummy handlers do not do anything useful in this example.
; They are set up here for completeness.

Undefined_Handler
    B   Undefined_Handler
SVC_Handler
    B   SVC_Handler
Prefetch_Handler
    B   Prefetch_Handler
Abort_Handler
    B   Abort_Handler
;;IRQ_Handler
;;    implemented below
FIQ_Handler
    B   FIQ_Handler
IRQ_Handler
 B   IRQ_Handler


;***********************
; Interrupt Handler
;***********************

; This simple example is only able to handle interrupts one after another.
; For a more complex nested (re-entrant) interrupt handler example, refer to the documentation

   ; IMPORT C_interrupt_handler

;IRQ_Handler FUNCTION {r0-r12}
 ;   PUSH {r0-r3, r12, lr}

  ;  BL C_interrupt_handler

   ; POP {r0-r3, r12, lr}
    ;SUBS pc, lr, #4

    ;ENDFUNC


;***********************
; Stack definitions
;***********************

; Import stack base linker symbols for app and irq from scatter file.  Stacks must be 8 byte aligned.

                IMPORT  ||Image$$ARM_LIB_STACK$$ZI$$Limit||
app_stack_base  DCD     ||Image$$ARM_LIB_STACK$$ZI$$Limit||
                IMPORT  ||Image$$IRQ_STACK$$ZI$$Limit||
irq_stack_base  DCD     ||Image$$IRQ_STACK$$ZI$$Limit||


;***********************
; Reset Handler
;***********************

; Disable cache and MMU, invalidate TLBs, fix vector table, setup stack pointers, setup & enable MMU, enable NEON, enter C library via __main(), then enable cache.

Reset_Handler   FUNCTION {}

    ; Disable caches, MMU and branch prediction in case they were left enabled from an earlier run
    ; This does not need to be done from a cold reset
    MRC     p15, 0, r0, c1, c0, 0       ; Read CP15 System Control register
    BIC     r0, r0, #(0x1 << 12)        ; Clear I bit 12 to disable I Cache
    BIC     r0, r0, #(0x1 <<  2)        ; Clear C bit  2 to disable D Cache
    BIC     r0, r0, #0x1                ; Clear M bit  0 to disable MMU
    BIC     r0, r0, #(0x1 << 11)        ; Clear Z bit 11 to disable branch prediction
    MCR     p15, 0, r0, c1, c0, 0       ; Write value back to CP15 System Control register

; The MMU is enabled later, before calling main().  Caches and branch prediction are enabled inside main(),
; after the MMU has been enabled and scatterloading has been performed.

    ; Invalidate Data and Instruction TLBs and branch predictor
    MOV     r0,#0
    MCR     p15, 0, r0, c8, c7, 0      ; I-TLB and D-TLB invalidation
    MCR     p15, 0, r0, c7, c5, 6      ; BPIALL - Invalidate entire branch predictor array


    ; Set Vector Base Address Register (VBAR) to point to this application's vector table
    LDR r0, =Vectors
    MCR p15, 0, r0, c12, c0, 0


    ; Enter each mode used in turn to disable interrupts and set up the stack pointer
    ; In this simple example, only SVC and IRQ modes are used
    ; Stack pointers must be 8 byte aligned
    MSR     CPSR_c, #Mode_IRQ :OR: I_Bit :OR: F_Bit
    LDR     r0, irq_stack_base
    MOV     sp, r0

    MSR     CPSR_c, #Mode_SVC :OR: I_Bit :OR: F_Bit
    LDR     r0, app_stack_base
    MOV     sp, r0

    ; Continue in SVC mode


;==================================================================
; Cache Invalidation code for Cortex-A8
;==================================================================

        ; Invalidate L1 Instruction Cache

        MRC p15, 1, r0, c0, c0, 1   ; Read Cache Level ID Register (CLIDR)
        TST r0, #0x3                ; Harvard Cache?
        MOV r0, #0                  ; SBZ
        MCRNE p15, 0, r0, c7, c5, 0 ; ICIALLU - Invalidate instruction cache and flush branch target cache

        ; Invalidate Data/Unified Caches

        MRC p15, 1, r0, c0, c0, 1   ; Read CLIDR
        ANDS r3, r0, #0x07000000    ; Extract coherency level
        MOV r3, r3, LSR #23         ; Total cache levels << 1
        BEQ Finished                ; If 0, no need to clean

        MOV r10, #0                 ; R10 holds current cache level << 1
Loop1   ADD r2, r10, r10, LSR #1    ; R2 holds cache "Set" position
        MOV r1, r0, LSR r2          ; Bottom 3 bits are the Cache-type for this level
        AND r1, r1, #7              ; Isolate those lower 3 bits
        CMP r1, #2
        BLT Skip                    ; No cache or only instruction cache at this level

        MCR p15, 2, r10, c0, c0, 0  ; Write the Cache Size selection register
        ISB                         ; ISB to sync the change to the CacheSizeID reg
        MRC p15, 1, r1, c0, c0, 0   ; Reads current Cache Size ID register
        AND r2, r1, #7              ; Extract the line length field
        ADD r2, r2, #4              ; Add 4 for the line length offset (log2 16 bytes)
        LDR r4, =0x3FF
        ANDS r4, r4, r1, LSR #3     ; R4 is the max number on the way size (right aligned)
        CLZ r5, r4                  ; R5 is the bit position of the way size increment
        LDR r7, =0x7FFF
        ANDS r7, r7, r1, LSR #13    ; R7 is the max number of the index size (right aligned)

Loop2   MOV r9, r4                  ; R9 working copy of the max way size (right aligned)

Loop3   ORR r11, r10, r9, LSL r5    ; Factor in the Way number and cache number into R11
        ORR r11, r11, r7, LSL r2    ; Factor in the Set number
        MCR p15, 0, r11, c7, c6, 2  ; Invalidate by Set/Way
        SUBS r9, r9, #1             ; Decrement the Way number
        BGE Loop3
        SUBS r7, r7, #1             ; Decrement the Set number
        BGE Loop2
Skip    ADD r10, r10, #2            ; Increment the cache number
        CMP r3, r10
        BGT Loop1

Finished


;===================================================================
; Cortex-A8 MMU Configuration
; Set translation table base
;===================================================================

        IMPORT ||Image$$APP_CODE$$Base||    ; From scatter file
        IMPORT ||Image$$TTB$$ZI$$Base||  ; from scatter file

        ; Cortex-A8 supports two translation tables
        ; Configure translation table base (TTB) control register cp15,c2
        ; to a value of all zeros, indicates we are using TTB register 0.

        MOV     r0,#0x0
        MCR     p15, 0, r0, c2, c0, 2


        ; write the address of our page table base to TTB register 0

        LDR     r0,=||Image$$TTB$$ZI$$Base||
        MCR     p15, 0, r0, c2, c0, 0


;===================================================================
; Cortex-A8 PAGE TABLE generation, using standard Arch v6 tables
;
; AP[11:10]   - Access Permissions = b11, Read/Write Access
; Domain[8:5] - Domain = b1111, Domain 15
; Type[1:0]   - Descriptor Type = b10, 1MB descriptors
;
; TEX  C  B
; 000  0  0  Strongly Ordered
; 000  1  1  Outer and Inner write back, no Write-allocate.
;===================================================================

        LDR     r1,=0xfff                   ; loop counter
        LDR     r2,=2_00000000000000000000110111100010

        ; r0 contains the address of the translation table base
        ; r1 is loop counter
        ; r2 is level1 descriptor (bits 19:0)

        ; use loop counter to create 4096 individual table entries.
        ; this writes from address 'Image$$TTB$$ZI$$Base' +
        ; offset 0x3FFC down to offset 0x0 in word steps (4 bytes)

init_ttb_1

        ORR     r3, r2, r1, LSL#20          ; r3 now contains full level1 descriptor to write
        STR     r3, [r0, r1, LSL#2]         ; str table entry at TTB base + loopcount*4
        SUBS    r1, r1, #1                  ; decrement loop counter
        BPL     init_ttb_1

        ; In this example, the 1MB section based at '||Image$$APP_CODE$$Base||' is setup specially as cacheable (write back mode).
        ; TEX[14:12]=000 and CB[3:2]= 11, Outer and inner write back, no Write-allocate normal memory.

        LDR     r1,=||Image$$APP_CODE$$Base|| ; Base physical address of code segment
        LSR     r1,#20                     ; Shift right to align to 1MB boundaries
        ORR     r3, r2, r1, LSL#20         ; Setup the initial level1 descriptor again
        ORR     r3,r3,#2_0000000001100     ; Set CB bits
        STR     r3, [r0, r1, LSL#2]        ; str table entry

;===================================================================
; Setup domain control register - Enable all domains to client mode
;===================================================================

        MRC     p15, 0, r0, c3, c0, 0     ; Read Domain Access Control Register
        LDR     r0, =0x55555555           ; Initialize every domain entry to b01 (client)
        MCR     p15, 0, r0, c3, c0, 0     ; Write Domain Access Control Register

;===================================================================
; Setup L2 Cache - L2 Cache Auxiliary Control
;===================================================================

;; Seems to undef on Beagle ?
;;        MOV     r0, #0
;;        MCR     p15, 1, r0, c9, c0, 2      ; Write L2 Auxilary Control Register


    IF {TARGET_FEATURE_NEON} || {TARGET_FPU_VFP}
;==================================================================
; Enable access to NEON/VFP by enabling access to Coprocessors 10 and 11.
; Enables Full Access i.e. in both privileged and non privileged modes
;==================================================================

        MRC     p15, 0, r0, c1, c0, 2      ; Read Coprocessor Access Control Register (CPACR)
        ORR     r0, r0, #(0xF << 20)       ; Enable access to CP 10 & 11
        MCR     p15, 0, r0, c1, c0, 2      ; Write Coprocessor Access Control Register (CPACR)
        ISB

;==================================================================
; Switch on the VFP and NEON hardware
;=================================================================

        MOV     r0, #0x40000000
        VMSR    FPEXC, r0                   ; Write FPEXC register, EN bit set
    ENDIF


;===================================================================
; Enable MMU and Branch to __main
; Leaving the caches disabled until after scatter loading.
;===================================================================

        IMPORT  __main                      ; Before MMU enabled import label to __main
        LDR     r12,=__main                 ; save this in register for possible long jump


        MRC     p15, 0, r0, c1, c0, 0       ; Read CP15 System Control register
        BIC     r0, r0, #(0x1 << 12)        ; Clear I bit 12 to disable I Cache
        BIC     r0, r0, #(0x1 <<  2)        ; Clear C bit  2 to disable D Cache
        BIC     r0, r0, #0x2                ; Clear A bit  1 to disable strict alignment fault checking
        ORR     r0, r0, #0x1                ; Set M bit 0 to enable MMU before scatter loading
        MCR     p15, 0, r0, c1, c0, 0       ; Write CP15 System Control register


; Now the MMU is enabled, virtual to physical address translations will occur.
; This will affect the next instruction fetches.
;
; The two instructions currently in the ARM pipeline will have been fetched before the MMU was enabled.
; The branch to __main is safe because the Virtual Address (VA) is the same as the Physical Address (PA)
; (flat mapping) of this code that enables the MMU and performs the branch

        BX      r12                         ; Branch to __main() C library entry point

    ENDFUNC



;==================================================================
; Enable caches and branch prediction
; This code must be run from a privileged mode
;==================================================================

        AREA   ENABLECACHES, CODE, READONLY

        EXPORT enable_caches

enable_caches  FUNCTION

;==================================================================
; Enable caches and branch prediction
;==================================================================

        MRC     p15, 0, r0, c1, c0, 0      ; Read System Control Register
        ORR     r0, r0, #(0x1 << 12)       ; Set I bit 12 to enable I Cache
        ORR     r0, r0, #(0x1 << 2)        ; Set C bit  2 to enable D Cache
        ORR     r0, r0, #(0x1 << 11)       ; Set Z bit 11 to enable branch prediction
        MCR     p15, 0, r0, c1, c0, 0      ; Write System Control Register


;==================================================================
; Enable Cortex-A8 Level2 Unified Cache
;==================================================================

        MRC     p15, 0, r0, c1, c0, 1      ; Read Auxiliary Control Register
        ORR     r0, #2                     ; L2EN bit, enable L2 cache
        MCR     p15, 0, r0, c1, c0, 1      ; Write Auxiliary Control Register

        BX      lr

        ENDFUNC


    EXPORT disable_caches

disable_caches FUNCTION

        MRC     p15, 0, r0, c1, c0, 0       ; Read CP15 System Control register
        BIC     r0, r0, #(0x1 << 12)        ; Clear I bit 12 to disable I Cache
        BIC     r0, r0, #(0x1 <<  2)        ; Clear C bit  2 to disable D Cache
        MCR     p15, 0, r0, c1, c0, 0       ; Write CP15 System Control register

        BX    lr

        ENDFUNC


        END
