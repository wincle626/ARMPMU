;
;  Copyright 2012 ARM Limited
;  All rights reserved.
;
;  Redistribution and use in source and binary forms, with or without
;  modification, are permitted provided that the following conditions are met
;    * Redistributions of source code must retain the above copyright
;      notice, this list of conditions and the following disclaimer.
;    * Redistributions in binary form must reproduce the above copyright
;      notice, this list of conditions and the following disclaimer in the
;      documentation and/or other materials provided with the distribution.
;    * Neither the name of ARM Limited nor the
;      names of its contributors may be used to endorse or promote products
;      derived from this software without specific prior written permission.
;
;  THIS SOFTWARE IS PROVIDED BY ARM LIMITED AND CONTRIBUTORS "AS IS" AND
;  ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
;  WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
;  DISCLAIMED. IN NO EVENT SHALL ARM LIMITED BE LIABLE FOR ANY
;  DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
;  (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
;  LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
;  ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
;  (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
;  SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
;

;/*
; * NE10 Library  dsp/NE10_cfft.neon.s
; */

;/*
; * Note
; * 1. Currently, this is for soft VFP EABI, not for hard vfpv3 ABI yet
; * 2. In the assembly code, we use D0-D31 registers. So VFPv3-D32 is used. In VFPv3-D16, there will be failure
; */


        ;/*
        ; * ;brief  Core radix-4 FFT of floating-point data.  Do not call this function directly.
        ; * ;param[out]  *pDst            points to the output buffer
        ; * ;param[in]  *pSrc             points to the input buffer
        ; * ;param[in]  N                 length of FFT
        ; * ;param[in]  *pCoef            points to the twiddle factors
        ; * ;retureq none.
        ; * The function implements a Radix-4 Complex FFT
        ; */


  PRESERVE8

  AREA  NE10,CODE,READONLY

  ARM

     EXPORT ne10_radix4_butterfly_float_neon

ne10_radix4_butterfly_float_neon FUNCTION



        PUSH    {r4-r12,lr}    ;push r12 to keep stack 8 bytes aligned
        VPUSH   {d8-d15}

;        Q0.F32   .qn Q0.F32
;        Q1.F32   .qn Q1.F32
;        Q2.F32   .qn Q2.F32
;        Q3.F32   .qn Q3.F32
;        Q4.F32   .qn Q4.F32
;        Q5.F32   .qn Q5.F32
;        Q6.F32   .qn Q6.F32
;        Q7.F32   .qn Q7.F32
;
;        Q8.F32 .qn Q8.F32
;        Q9.F32 .qn Q9.F32
;        Q10.F32 .qn Q10.F32
;        Q11.F32 .qn Q11.F32
;        Q12.F32 .qn Q12.F32
;        Q13.F32 .qn Q13.F32
;
;       Q14.F32 .qn Q14.F32
;       Q15.F32 .qn Q15.F32
;
;       Q2.F32 .qn Q2.F32
;       Q3.F32 .qn Q3.F32
;
;       Q4.F32 .qn Q4.F32
;       Q5.F32 .qn Q5.F32
;
;        Q8.F32     .qn Q8.F32
;        Q9.F32     .qn Q9.F32
;        Q10.F32     .qn Q10.F32
;        Q11.F32     .qn Q11.F32
;        Q12.F32     .qn Q12.F32
;        Q13.F32     .qn Q13.F32
;        Q14.F32     .qn Q14.F32
;        Q15.F32     .qn Q15.F32

pDst        RN  R0
pSrc        RN  R1
fftSize     RN  R2
pCoef       RN  R3


SubFFTSize  RN  R4
SubFFTNum   RN  R5
grpCount    RN  R6
twidStep    RN  R8
setCount    RN  R9
grpStep     RN  R10

pT1         RN  R7
pOut1       RN  R11
pTw2        RN  R12
TwdStep     RN  R14
pTmp        RN  R7

        LSR     SubFFTNum,fftSize,#2
        MOV     SubFFTSize,#4
        MOV     pT1,pSrc
        LSR     grpCount,SubFFTNum,#2
        MOV     pOut1,pDst
        LSL     fftSize,#1

fftGrpLoop
        VLD2        {Q0.F32,Q1.F32},[pT1],fftSize  ;/*Load Input Values*/
        VLD2        {Q2.F32,Q3.F32},[pT1],fftSize
        VLD2        {Q4.F32,Q5.F32},[pT1],fftSize


        ;/*pSrc[0] + pSrc[2]*/
        VADD    Q8.F32,Q0.F32,Q4.F32
        VADD    Q9.F32,Q1.F32,Q5.F32
        ;/*pSrc[0] - pSrc[2]*/
        VSUB    Q10.F32,Q0.F32,Q4.F32
        VSUB    Q11.F32,Q1.F32,Q5.F32
        ;/*pSrc[1] + pSrc[3]*/
        VLD2        {Q6.F32,Q7.F32},[pT1],fftSize
        VADD    Q12.F32,Q2.F32,Q6.F32
        VADD    Q13.F32,Q3.F32,Q7.F32
        ;/*pSrc[1] - pSrc[3]*/
        VSUB    Q14.F32,Q2.F32,Q6.F32
        VSUB    Q15.F32,Q3.F32,Q7.F32

        ;/*Radix-4 Butterfly calculation*/
        ;/*Third Result*/
        VSUB    Q4.F32,Q8.F32,Q12.F32
        VSUB    Q5.F32,Q9.F32,Q13.F32
        ;/*First Result*/
        VADD    Q0.F32,Q8.F32,Q12.F32
        VZIP    Q0.F32,Q4.F32
        VADD    Q1.F32,Q9.F32,Q13.F32
        VZIP    Q1.F32,Q5.F32
        ;/*Second result*/
        VADD    Q2.F32,Q10.F32,Q15.F32
        VSUB    Q3.F32,Q11.F32,Q14.F32
        ;/*Fourth Result*/
        VSUB    Q6.F32,Q10.F32,Q15.F32
        VZIP    Q2.F32,Q6.F32
        VADD    Q7.F32,Q11.F32,Q14.F32


        VZIP    Q3.F32,Q7.F32


        SUB     pT1,pT1,fftSize, LSL #2

        VST4.F32    {d0,d2,d4,d6},[pOut1]!
        VST4.F32    {d1,d3,d5,d7},[pOut1]!
        SUBS        grpCount,#1
        ADD         pT1,pT1,#32
        VST4.F32    {d8,d10,d12,d14},[pOut1]!
        VST4.F32    {d9,d11,d13,d15},[pOut1]!

        BGT     fftGrpLoop

        ;/* Swap Input and Output*/
        MOV     pTmp,pDst
        MOV     pDst,pSrc
        MOV     pSrc,pTmp

        ;/*Remaining FFT Stages Second Stage to Last Stage*/
        ;/* Update the Grp count and size for the next stage */
        LSR     SubFFTNum,#2
        LSL     SubFFTSize,#2

fftStageLoop
        MOV     grpCount,SubFFTNum
        MOV     grpStep,#0
        ADD     pT1,pSrc,fftSize
        LSL     TwdStep,SubFFTSize,#1

fftGrpLoop1
        LSR     setCount,SubFFTSize,#2
        ADD     pOut1,pDst,grpStep,LSL #3
        MOV     pTw2,pCoef

        LSL     SubFFTSize,#1

fftSetLoop
        VLD2    {Q8.F32,Q9.F32},[pTw2],TwdStep
        VLD2    {Q2.F32,Q3.F32},[pT1],fftSize
        ;/*CPLX_MUL (pTmpT2, pTw2, pT2);*/
        VMUL   Q14.F32,Q8.F32,Q2.F32
        VMUL   Q15.F32,Q8.F32,Q3.F32
        VLD2    {Q10.F32,Q11.F32},[pTw2],TwdStep
        VLD2    {Q4.F32,Q5.F32},[pT1],fftSize
        VMLA   Q14.F32,Q9.F32,Q3.F32
        VMLS   Q15.F32,Q9.F32,Q2.F32


        ;/*CPLX_MUL (pTmpT3, pTw3, pT3);*/
        VMUL   Q2.F32,Q10.F32,Q4.F32
        VMUL   Q3.F32,Q10.F32,Q5.F32
        VLD2    {Q12.F32,Q13.F32},[pTw2]
        VLD2    {Q6.F32,Q7.F32},[pT1],fftSize
        VMLA   Q2.F32,Q11.F32,Q5.F32
        VMLS   Q3.F32,Q11.F32,Q4.F32

        SUB     pT1,pT1,fftSize, LSL #2


        ;/*CPLX_MUL (pTmpT4, pTw4, pT4);*/
        VMUL   Q4.F32,Q12.F32,Q6.F32
        VMUL   Q5.F32,Q12.F32,Q7.F32
        VLD2    {Q0.F32,Q1.F32},[pT1],fftSize
        VMLA   Q4.F32,Q13.F32,Q7.F32
        VMLS   Q5.F32,Q13.F32,Q6.F32


        ;/*CPLX_ADD (pTmp1, pT1, pTmpT3);*/
        VADD    Q8.F32,Q0.F32,Q2.F32
        VADD    Q9.F32,Q1.F32,Q3.F32
        ;/*CPLX_SUB (pTmp2, pT1, pTmpT3);*/
        VSUB    Q10.F32,Q0.F32,Q2.F32
        VSUB    Q11.F32,Q1.F32,Q3.F32
        ;/*CPLX_ADD (pTmp3, pTmpT2, pTmpT4);*/
        VADD    Q12.F32,Q14.F32,Q4.F32
        VADD    Q13.F32,Q15.F32,Q5.F32
        ;/*CPLX_SUB (pTmp4, pTmpT2, pTmpT4);*/
        VSUB    Q14.F32,Q14.F32,Q4.F32
        VSUB    Q15.F32,Q15.F32,Q5.F32

        ;/*CPLX_ADD (pT1, pTmp1, pTmp3);*/
        VADD    Q0.F32,Q8.F32,Q12.F32
        VADD    Q1.F32,Q9.F32,Q13.F32
        VST2    {Q0.F32,Q1.F32},[pOut1],SubFFTSize
        ;/*CPLX_ADD_SUB_X (pT2, pTmp2, pTmp4);*/
        VADD    Q2.F32,Q10.F32,Q15.F32
        VSUB    Q3.F32,Q11.F32,Q14.F32
        VST2    {Q2.F32,Q3.F32},[pOut1],SubFFTSize
        ;/*CPLX_SUB (pT3, pTmp1, pTmp3);*/
        VSUB    Q4.F32,Q8.F32,Q12.F32
        VSUB    Q5.F32,Q9.F32,Q13.F32
        VST2    {Q4.F32,Q5.F32},[pOut1],SubFFTSize
        ;/*CPLX_SUB_ADD_X (pT4, pTmp2, pTmp4);*/
        VSUB    Q6.F32,Q10.F32,Q15.F32
        VADD    Q7.F32,Q11.F32,Q14.F32
        VST2    {Q6.F32,Q7.F32},[pOut1],SubFFTSize
        SUBS    setCount,#4
        ;/* Store the Result*/







        SUB     pTw2,pTw2,TwdStep, LSL #1
        SUB     pOut1,pOut1,SubFFTSize, LSL #2

        ADD     pT1,pT1,#32
        ADD     pTw2,pTw2,#32
        ADD     pOut1,pOut1,#32

        BGT     fftSetLoop
        LSR     SubFFTSize,#1
        SUBS    grpCount,grpCount,#1
        ADD     grpStep,grpStep,SubFFTSize

        BGT     fftGrpLoop1
        ;/* Update the Grp count and size for the next stage */
        ADD     twidStep,SubFFTSize,SubFFTSize, LSL #1
        LSRS    SubFFTNum,SubFFTNum,#2

        ;/* Swap Input and Output*/
        MOV     pTmp,pDst
        MOV     pDst,pSrc
        MOV     pSrc,pTmp

        ADD     pCoef,pCoef,twidStep,LSL #1

        LSL     SubFFTSize,SubFFTSize,#2

        BGT     fftStageLoop

        ;/* if the N is even power of 4, copy the output to dst buffer */
        ASR     fftSize,fftSize,#1
        CLZ     SubFFTNum,fftSize
        MOV     setCount, #32
        SUB     SubFFTNum, setCount, SubFFTNum
        ASR     SubFFTNum,SubFFTNum,#1
        ANDS    SubFFTNum, SubFFTNum, #1

        BNE     fftEnd

        ASR     grpCount, fftSize, #4
;fftCopyLoop
;        VLD1.F32    {d0,d1,d2,d3},[pSrc]!
;        VLD1.F32    {d4,d5,d6,d7},[pSrc]!
;        VLD1.F32    {d8,d9,d10,d11},[pSrc]!
;        VLD1.F32    {d12,d13,d14,d15},[pSrc]!
;
;        SUBS        grpCount,#1
;        VST1.F32    {d0,d1,d2,d3},[pDst]!
;        VST1.F32    {d4,d5,d6,d7},[pDst]!
;        VST1.F32    {d8,d9,d10,d11},[pDst]!
;        VST1.F32    {d12,d13,d14,d15},[pDst]!
;
;        BGT         fftCopyLoop
;
fftEnd
        ;/* Retureq From Function*/
        VPOP    {d8-d15}
        POP     {r4-r12,pc}
        ENDP



