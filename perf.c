/*---------------------------------------------------------------------*/
/* Performance Monitoring Unit (PMU) Example Code for Cortex-A* family */
/*                                                                     */
/* Copyright (C) ARM Limited, 2011. All rights reserved.               */
/*---------------------------------------------------------------------*/

#include <stdio.h>
#include "v7_pmu.h"

static int k=0;
void start_perfmon(void)
{
    enable_pmu_user_access();  // Allow access to PMU from User Mode
    enable_pmu();              // Enable the PMU
   /* pmn_config(0, 0x01);       // Configure counter 0 to count I-Cache Misses
    pmn_config(1, 0x03);       // Configure counter 1 to count D-Cache Misses
// Alternatively...
//    pmn_config(0, 0x06);       // Configure counter 0 to count Data Reads
//    pmn_config(1, 0x07);       // Configure counter 1 to count Data Writes
    pmn_config(2, 0x08);       // Configure counter 2 to count Instructions Executed
    pmn_config(3, 0x0C);       // Configure counter 3 to count PC Changes

    enable_pmn(0);             // Enable counter 0
    enable_pmn(1);             // Enable counter 1
    enable_pmn(2);             // Enable counter 2
    enable_pmn(3);             // Enable counter 3*/

    enable_ccnt();             // Enable CCNT
    reset_pmn();               // Reset the configurable counters
    reset_ccnt();              // Reset the CCNT (cycle counter)

}

long int stop_perfmon(void)
{

  /*  disable_ccnt();            // Stop CCNT
    disable_pmn(0);            // Stop counter 0
    disable_pmn(1);            // Stop counter 1
    disable_pmn(2);            // Stop counter 2
    disable_pmn(3);            // Stop counter 3

    printf("\nPerformance monitor results");
    printf("\n---------------------------\n");
    printf("I-Cache Misses = %u\n",        read_pmn(0) );
    printf("D-Cache Misses = %u\n",        read_pmn(1) );
    printf("Instructions Executed = %u\n", read_pmn(2) );
    printf("PC Changes = %u\n",            read_pmn(3) );*/
    long count=read_ccnt();
    //printf("\nCycle Count (CCNT) = %d\n,  %d   \n",  count,read_flags() );
   // printf("Overflow  = %d\n",    read_flags() );
    k=read_flags();
    return count;
}

