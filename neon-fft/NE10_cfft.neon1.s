

  PRESERVE8

  AREA  NE10,CODE,READONLY,ALIGN=3

  ARM

     EXPORT ne10_radix4_butterfly_float_neon

ne10_radix4_butterfly_float_neon FUNCTION



        PUSH    {r4-r12,lr}    ;push r12 to keep stack 8 bytes aligned
        VPUSH   {d8-d15}

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
pTmp        RN  R12

        LSR     SubFFTNum,fftSize,#2
        MOV     SubFFTSize,#4
        MOV     pT1,pSrc
        LSR     grpCount,SubFFTNum,#2
        MOV     pOut1,pDst
        LSL     fftSize,#1

fftGrpLoop
        VLD2        {Q0.F32,Q1.F32},[pT1@256],fftSize  ;/*Load Input Values*/
        VLD2        {Q2.F32,Q3.F32},[pT1@256],fftSize
        VLD2        {Q4.F32,Q5.F32},[pT1@256],fftSize
   ;

        ;/*pSrc[0] + pSrc[2]*/
        VADD    Q8.F32,Q0.F32,Q4.F32
        VADD    Q9.F32,Q1.F32,Q5.F32
        ;/*pSrc[0] - pSrc[2]*/
        VSUB    Q10.F32,Q0.F32,Q4.F32
        VSUB    Q11.F32,Q1.F32,Q5.F32
        ;/*pSrc[1] + pSrc[3]*/
        VLD2        {Q6.F32,Q7.F32},[pT1@256],fftSize

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
        VADD    Q1.F32,Q9.F32,Q13.F32
        ;/*Second result*/
        VADD    Q2.F32,Q10.F32,Q15.F32
        VSUB    Q3.F32,Q11.F32,Q14.F32
        ;/*Fourth Result*/
        VSUB    Q6.F32,Q10.F32,Q15.F32
        VADD    Q7.F32,Q11.F32,Q14.F32

        ;/*Get Result in correct order for storing*/
        ;/*4Re2,4Re0,3Re2,3Re0 2Re2,2Re0,1Re2,1Re0*/
        VZIP    Q0.F32,Q4.F32
        ;/*4Re3,4Re1,3Re3,3Re1 2Re3,2Re1,1Re3,1Re1*/
        VZIP    Q2.F32,Q6.F32

        ;/*4Im2,4Im0,3Im2,3Im0 2Im2,2Im0,1Im2,1Im0*/
        VZIP    Q1.F32,Q5.F32
        ;/*4Im3,4Im1,3Im2,3Im1 2Im3,2Im1,1Im3,1Im1*/
        VZIP    Q3.F32,Q7.F32

        SUB     pT1,pT1,fftSize, LSL #2

        MOV         pTmp,#32
        VST4.F32    {d0,d2,d4,d6},[pOut1@256],pTmp
        VST4.F32    {d1,d3,d5,d7},[pOut1@256],pTmp
        SUBS        grpCount,#1
        ADD         pT1,pT1,#32
        VST4.F32    {d8,d10,d12,d14},[pOut1@256],pTmp
        VST4.F32    {d9,d11,d13,d15},[pOut1@256],pTmp

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
        VLD2    {Q8.F32,Q9.F32},[pTw2@256],TwdStep
        VLD2    {Q2.F32,Q3.F32},[pT1@256],fftSize
        ;/*CPLX_MUL (pTmpT2, pTw2, pT2);*/
        VMUL   Q14.F32,Q8.F32,Q2.F32
        VMUL   Q15.F32,Q8.F32,Q3.F32
        VLD2    {Q10.F32,Q11.F32},[pTw2@256],TwdStep
        VLD2    {Q4.F32,Q5.F32},[pT1@256],fftSize
        VMLA   Q14.F32,Q9.F32,Q3.F32
        VMLS   Q15.F32,Q9.F32,Q2.F32


        ;/*CPLX_MUL (pTmpT3, pTw3, pT3);*/
        VMUL   Q2.F32,Q10.F32,Q4.F32
        VMUL   Q3.F32,Q10.F32,Q5.F32
        VLD2    {Q12.F32,Q13.F32},[pTw2@256]
        VLD2    {Q6.F32,Q7.F32},[pT1@256],fftSize
        VMLA   Q2.F32,Q11.F32,Q5.F32
        VMLS   Q3.F32,Q11.F32,Q4.F32

        SUB     pT1,pT1,fftSize, LSL #2


        ;/*CPLX_MUL (pTmpT4, pTw4, pT4);*/
        VMUL   Q4.F32,Q12.F32,Q6.F32
        VMUL   Q5.F32,Q12.F32,Q7.F32
        VLD2    {Q0.F32,Q1.F32},[pT1@256],fftSize
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

        ;/*CPLX_ADD_SUB_X (pT2, pTmp2, pTmp4);*/
        VADD    Q2.F32,Q10.F32,Q15.F32
        VSUB    Q3.F32,Q11.F32,Q14.F32

        ;/*CPLX_SUB (pT3, pTmp1, pTmp3);*/
        VSUB    Q4.F32,Q8.F32,Q12.F32
        VSUB    Q5.F32,Q9.F32,Q13.F32
        ;/*CPLX_SUB_ADD_X (pT4, pTmp2, pTmp4);*/
        VSUB    Q6.F32,Q10.F32,Q15.F32
        VADD    Q7.F32,Q11.F32,Q14.F32

        SUBS    setCount,#4
        ;/* Store the Result*/

        VST2    {Q0.F32,Q1.F32},[pOut1@256],SubFFTSize
        VST2    {Q2.F32,Q3.F32},[pOut1@256],SubFFTSize

        VST2    {Q4.F32,Q5.F32},[pOut1@256],SubFFTSize
        VST2    {Q6.F32,Q7.F32},[pOut1@256],SubFFTSize

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

fftEnd
        ;/* Retureq From Function*/
        VPOP    {d8-d15}
        POP     {r4-r12,pc}
        ENDP



