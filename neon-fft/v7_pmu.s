;;---------------------------------------------------------------
;; Performance Monitoring Unit (PMU) Example Code for Cortex-A/R
;;
;; Copyright (C) ARM Limited, 2010-2012. All rights reserved.
;;---------------------------------------------------------------


  PRESERVE8

  AREA  PMU,CODE,READONLY

  ARM

; ------------------------------------------------------------
; Performance Monitor Block
; ------------------------------------------------------------

  EXPORT getPMN
  ; Returns the number of progammable counters
  ; uint32_t getPMN(void)
getPMN PROC
  MRC     p15, 0, r0, c9, c12, 0 ; Read PMCR Register
  MOV     r0, r0, LSR #11        ; Shift N field down to bit 0
  AND     r0, r0, #0x1F          ; Mask to leave just the 5 N bits
  BX      lr
  ENDP


  EXPORT  pmn_config
  ; Sets the event for a programmable counter to record
  ; void pmn_config(unsigned counter, uint32_t event)
  ; counter (in r0) = Which counter to program (e.g. 0 for PMN0, 1 for PMN1)
  ; event   (in r1) = The event code (from appropriate TRM or ARM Architecture Reference Manual)
pmn_config PROC
  AND     r0, r0, #0x1F          ; Mask to leave only bits 4:0
  MCR     p15, 0, r0, c9, c12, 5 ; Write PMSELR Register
  ISB                            ; Synchronize context
  MCR     p15, 0, r1, c9, c13, 1 ; Write PMXEVTYPER Register
  BX      lr
  ENDP


  EXPORT ccnt_divider
  ; Enables/disables the divider (1/64) on CCNT
  ; void ccnt_divider(int divider)
  ; divider (in r0) = If 0 disable divider, else enable divider
ccnt_divider PROC
  MRC     p15, 0, r1, c9, c12, 0  ; Read PMCR

  CMP     r0, #0x0                ; IF (r0 == 0)
  BICEQ   r1, r1, #0x08           ; THEN: Clear the D bit (disables the divisor)
  ORRNE   r1, r1, #0x08           ; ELSE: Set the D bit (enables the divisor)

  MCR     p15, 0, r1, c9, c12, 0  ; Write PMCR
  BX      lr
  ENDP

  ; ---------------------------------------------------------------
  ; Enable/Disable
  ; ---------------------------------------------------------------

  EXPORT enable_pmu
  ; Global PMU enable
  ; void enable_pmu(void)
enable_pmu  PROC
  MRC     p15, 0, r0, c9, c12, 0  ; Read PMCR
  ORR     r0, r0, #0x01           ; Set E bit
  MCR     p15, 0, r0, c9, c12, 0  ; Write PMCR
  BX      lr
  ENDP


  EXPORT disable_pmu
  ; Global PMU disable
  ; void disable_pmu(void)
disable_pmu  PROC
  MRC     p15, 0, r0, c9, c12, 0  ; Read PMCR
  BIC     r0, r0, #0x01           ; Clear E bit
  MCR     p15, 0, r0, c9, c12, 0  ; Write PMCR
  BX      lr
  ENDP


  EXPORT enable_ccnt
  ; Enable the CCNT
  ; void enable_ccnt(void)
enable_ccnt PROC
  MOV     r0, #0x80000000         ; Set C bit
  MCR     p15, 0, r0, c9, c12, 1  ; Write PMCNTENSET Register
  BX      lr
  ENDP


  EXPORT disable_ccnt
  ; Disable the CCNT
  ; void disable_ccnt(void)
disable_ccnt PROC
  MOV     r0, #0x80000000         ; Set C bit
  MCR     p15, 0, r0, c9, c12, 2  ; Write PMCNTENCLR Register
  BX      lr
  ENDP


  EXPORT enable_pmn
  ; Enable PMN{n}
  ; void enable_pmn(uint32_t counter)
  ; counter (in r0) = The counter to enable (e.g. 0 for PMN0, 1 for PMN1)
enable_pmn PROC
  MOV     r1, #0x1
  MOV     r1, r1, LSL r0
  MCR     p15, 0, r1, c9, c12, 1  ; Write PMCNTENSET Register
  BX      lr
  ENDP


  EXPORT disable_pmn
  ; Disable PMN{n}
  ; void disable_pmn(uint32_t counter)
  ; counter (in r0) = The counter to disable (e.g. 0 for PMN0, 1 for PMN1)
disable_pmn PROC
  MOV     r1, #0x1
  MOV     r1, r1, LSL r0
  MCR     p15, 0, r1, c9, c12, 2  ; Write PMCNTENCLR Register
  BX      lr
  ENDP


  EXPORT  enable_pmu_user_access
  ; Enables User mode access to the PMU (must be called in a privileged mode)
  ; void enable_pmu_user_access(void)
enable_pmu_user_access PROC
  MRC     p15, 0, r0, c9, c14, 0  ; Read PMUSERENR Register
  ORR     r0, r0, #0x01           ; Set EN bit (bit 0)
  MCR     p15, 0, r0, c9, c14, 0  ; Write PMUSERENR Register
  ISB                             ; Synchronize context
  BX      lr
  ENDP


  EXPORT  disable_pmu_user_access
  ; Disables User mode access to the PMU (must be called in a privileged mode)
  ; void disable_pmu_user_access(void)
disable_pmu_user_access PROC
  MRC     p15, 0, r0, c9, c14, 0  ; Read PMUSERENR Register
  BIC     r0, r0, #0x01           ; Clear EN bit (bit 0)
  MCR     p15, 0, r0, c9, c14, 0  ; Write PMUSERENR Register
  ISB                             ; Synchronize context
  BX      lr
  ENDP


  ; ---------------------------------------------------------------
  ; Counter read registers
  ; ---------------------------------------------------------------

  EXPORT read_ccnt
  ; Returns the value of CCNT
  ; uint32_t read_ccnt(void)
read_ccnt   PROC
  MRC     p15, 0, r0, c9, c13, 0 ; Read CCNT Register
  BX      lr
  ENDP


  EXPORT  read_pmn
  ; Returns the value of PMN{n}
  ; uint32_t read_pmn(uint32_t counter)
  ; counter (in r0) = The counter to read (e.g. 0 for PMN0, 1 for PMN1)
read_pmn PROC
  AND     r0, r0, #0x1F          ; Mask to leave only bits 4:0
  MCR     p15, 0, r0, c9, c12, 5 ; Write PMSELR Register
  ISB                            ; Synchronize context
  MRC     p15, 0, r0, c9, c13, 2 ; Read current PMNx Register
  BX      lr
  ENDP


  ; ---------------------------------------------------------------
  ; Software Increment
  ; ---------------------------------------------------------------

  EXPORT pmu_software_increment
  ; Writes to software increment register
  ; void pmu_software_increment(uint32_t counter)
  ; counter (in r0) = The counter to increment (e.g. 0 for PMN0, 1 for PMN1)
pmu_software_increment PROC
  MOV     r1, #0x01
  MOV     r1, r1, LSL r0
  MCR     p15, 0, r1, c9, c12, 4 ; Write PMSWINCR Register
  BX      lr
  ENDP


  ; ---------------------------------------------------------------
  ; Overflow & Interrupt Generation
  ; ---------------------------------------------------------------

  EXPORT read_flags
  ; Returns the value of the overflow flags
  ; uint32_t read_flags(void)
read_flags PROC
  MRC     p15, 0, r0, c9, c12, 3 ; Read PMOVSR Register
  BX      lr
  ENDP


  EXPORT  write_flags
  ; Writes the overflow flags
  ; void write_flags(uint32_t flags)
write_flags PROC
  MCR     p15, 0, r0, c9, c12, 3 ; Write PMOVSR Register
  ISB                            ; Synchronize context
  BX      lr
  ENDP


  EXPORT  enable_ccnt_irq
  ; Enables interrupt generation on overflow of the CCNT
  ; void enable_ccnt_irq(void)
enable_ccnt_irq PROC
  MOV     r0, #0x80000000
  MCR     p15, 0, r0, c9, c14, 1  ; Write PMINTENSET Register
  BX      lr
  ENDP


  EXPORT  disable_ccnt_irq
  ; Disables interrupt generation on overflow of the CCNT
  ; void disable_ccnt_irq(void)
disable_ccnt_irq PROC
  MOV     r0, #0x80000000
  MCR     p15, 0, r0, c9, c14, 2   ; Write PMINTENCLR Register
  BX      lr
  ENDP


  EXPORT enable_pmn_irq
  ; Enables interrupt generation on overflow of PMN{x}
  ; void enable_pmn_irq(uint32_t counter)
  ; counter (in r0) = The counter to enable the interrupt for (e.g. 0 for PMN0, 1 for PMN1)
enable_pmn_irq PROC
  MOV     r1, #0x1
  MOV     r0, r1, LSL r0
  MCR     p15, 0, r0, c9, c14, 1   ; Write PMINTENSET Register
  BX      lr
  ENDP


  EXPORT disable_pmn_irq
  ; Disables interrupt generation on overflow of PMN{x}
  ; void disable_pmn_irq(uint32_t counter)
  ; counter (in r0) = The counter to disable the interrupt for (e.g. 0 for PMN0, 1 for PMN1)
disable_pmn_irq PROC
  MOV     r1, #0x1
  MOV     r0, r1, LSL r0
  MCR     p15, 0, r0, c9, c14, 2  ; Write PMINTENCLR Register
  BX      lr
  ENDP


  ; ---------------------------------------------------------------
  ; Reset Functions
  ; ---------------------------------------------------------------

  EXPORT reset_pmn
  ; Resets all programmable counters to zero
  ; void reset_pmn(void)
reset_pmn PROC
  MRC     p15, 0, r0, c9, c12, 0  ; Read PMCR
  ORR     r0, r0, #0x2            ; Set P bit (Event counter reset)
  MCR     p15, 0, r0, c9, c12, 0  ; Write PMCR
  BX      lr
  ENDP


  EXPORT  reset_ccnt
  ; Resets the CCNT
  ; void reset_ccnt(void)
reset_ccnt PROC
  MRC     p15, 0, r0, c9, c12, 0  ; Read PMCR
  ORR     r0, r0, #0x4            ; Set C bit (Clock counter reset)
  MCR     p15, 0, r0, c9, c12, 0  ; Write PMCR
  BX      lr
  ENDP


  END
