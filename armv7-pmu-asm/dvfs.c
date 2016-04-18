// dvfs.c - Enable and read from the ARM PMU

#include <linux/module.h>	
#include <linux/kernel.h>
#include <linux/cpufreq.h>
#include "dvfs.h"

MODULE_LICENSE("GPL");
MODULE_DESCRIPTION("Module to perform DVFS");
MODULE_AUTHOR("Nima Nikzad");

#define CPU_NUM			0
#define ONDEMAND_GOV		0
#define USERSPACE_GOV		1

//Note: this NUMTICKS value can be changed by you so that your governor can make decision at different intervals
#define NUMTICKS		100
#define TICKS_PER_SEC		100

#define MIN_FREQ_INDEX		0
#define MAX_FREQ_INDEX		15

// TODO: This needs to be updated
//unsigned int freqs[] = {245760, 400000, 480000, 600000}; this is for HTC Aria
//unsigned int freqs[]={192000, 384000, 432000, 486000, 450000, 648000, 702000, 756000, 810000, 864000, 918000, 972000, 1026000, 1080000, 1134000, 1188000};
static unsigned int freqs[]={384000, 432000, 486000, 540000, 594000, 648000, 702000, 756000, 810000, 864000, 918000, 972000, 1026000, 1080000, 1134000, 1188000};
static unsigned int actPower[]={212, 230, 248, 265, 284, 307, 331, 359, 386, 415, 447, 481, 516, 554, 590, 625};
static unsigned int idlePower[]={82, 85, 88, 91, 94, 99, 104, 112, 119, 127, 135, 143, 152, 161, 170, 179};
static unsigned int last_freq;
static unsigned long cycle_count, counter0, counter1, counter2, counter3, tick_count;

// Set the frequency to freq
// DO NOT MODIFY
int setFreq(int cpu, unsigned int freq)
{
	struct cpufreq_policy plcy;
	int ret;

	cpufreq_get_policy(&plcy, CPU_NUM);

	if(!plcy.governor->store_setspeed)
	{
		printk(KERN_INFO "MUST SET POLICY TO USERSPACE FIRST!\n");
		return -1;
	}

	ret = acpuclk_set_rate(cpu, freq , SETRATE_CPUFREQ);

	printk(KERN_INFO "CPU FREQ CHANGED TO %u, with ret: %d\n", freq,ret);
	return ret;
}

// Set frequency to the 'index' step
// DO NOT MODIFY
void setFreqIndex(int cpu, unsigned int index)
{
	// Check bounds
	if(index < MIN_FREQ_INDEX || index > MAX_FREQ_INDEX)
		return;
	if(setFreq(cpu, freqs[index])==0)
          last_freq=index;
}

// Calculate CPU utilization, note that this function must be invoked prior to setFreqIndex function because of last_freq
// also note that the first time you call this function after insmod, it will possibly yield a util larger than 100%, this is because variable last_freq  has not been set up properly. So when this happens, just ignore the first cpu utilization value.
// DO NOT MODIFY
unsigned int getCpuUtil(void)
{
	unsigned int curFreq, cycles, maxCycles, util;
	curFreq = freqs[last_freq]; // freq in khz
	// kHz utilized
	cycles = cycle_count / 1000;
	// Maximum possible cycles
	maxCycles = curFreq * tick_count / TICKS_PER_SEC;
	// Multiplied by 100 to get in percent
	util = 100 * cycles / maxCycles;

	return util;
}

// For debugging
// Print the current policy info
// DO NOT MODIFY
void printPolicyInfo(void)
{
	struct cpufreq_policy plcy;
	cpufreq_get_policy(&plcy, CPU_NUM);
	printk(KERN_INFO "CPU: %u, GOVERNOR: %s, MIN: %u, MAX: %u, CUR: %u\n", plcy.cpu, plcy.governor->name, plcy.min, plcy.max, plcy.cur);
}

// For debugging
// Print counter info, note that this function must be invoked prior to setFreqIndex function because of getCpuUtil
// DO NOT MODIFY
void printCounterInfo(void)
{
	unsigned int util;
	util = getCpuUtil();
	printk(KERN_INFO "Counter 0 = %lu, Counter 1 = %lu, Counter 2 = %lu, Counter 3 = %lu, CCNT = %lu, CPUtil: %u, Energy: %u\n", counter0, counter1, counter2, counter3, cycle_count, util, (actPower[last_freq] * util + idlePower[last_freq] * (100 - util ))*(unsigned int) tick_count / TICKS_PER_SEC/100);
}


// Configure the PMU to track cntr0, cntr1, cntr2, and cntr3
// DO NOT MODIFY
void configPMU(unsigned cntr0, unsigned cntr1, unsigned cntr2, unsigned cntr3)
{
	disable_pmu();			// must first disable the pmu
	disable_ccnt();
	disable_pmn(0);
	disable_pmn(1);
	disable_pmn(2);
	disable_pmn(3);
	reset_ccnt();			// reset cycle counter
	reset_pmn();			// reset configurable counters
	pmn_config(0,cntr0);	// configure counter 0
	pmn_config(1,cntr1);	// configure counter 1
	pmn_config(2,cntr2);	// configure counter 1
	pmn_config(3,cntr3);	// configure counter 1
	ccnt_divider(0);		// 1 divices ccnt by 64
	enable_pmu();
	enable_ccnt();
	enable_pmn(0);
	enable_pmn(1);
	enable_pmn(2);
	enable_pmn(3);
}

////////////////////////
// MODIFY THIS FUNCTION!
// Called on tick of scheduler
// This function is called by the kernel every 10ms
////////////////////////
void dvfs_tick(void)
{
	disable_pmu();			// Disable the PMU before accessing it
	tick_count++;			// Track the number of ticks
	counter0 += read_pmn(0);	// Update counter0 count
	counter1 += read_pmn(1);	// Update counter1 count
	counter2 += read_pmn(2);	// Update counter2 count
	counter3 += read_pmn(3);	// Update counter3 count
	cycle_count += read_ccnt();	// Update executed cycles count
	reset_ccnt();			// Reset executed cycles count
	reset_pmn();			// Reset performance counters

	if(tick_count == NUMTICKS)
	{
		/////////////////////////
		// IMPLEMENT POLICY HERE!
		/////////////////////////
		printCounterInfo();
		// Example:
                // note that getCpuUtil and printCounterInfo are called before setFreqIndex because setFreqIndex will modify global variable last_freq
		if (getCpuUtil() >= 90)
			setFreqIndex(0, last_freq + 1);
		else if (getCpuUtil() <= 80)
			setFreqIndex(0, last_freq - 1);
		//////////////
		// END POLICY
		//////////////

		// After your policy has made a decision, reset variables!
		tick_count = 0;
		counter0 = 0;
		counter1 = 0;
		counter2 = 0;
		counter3 = 0;
		cycle_count = 0;
	}
	// Re-enable PMU after done accessing it
	enable_pmu();
}


// Run when module is first inserted
int init_module(void)
{
	int i;
	struct cpufreq_policy plcy;
	cpufreq_get_policy(&plcy, CPU_NUM);
	last_freq = MAX_FREQ_INDEX + 1;
	// Find the current speed's index
	for(i = 0; i <= MAX_FREQ_INDEX; i++)
		if(plcy.cur == freqs[i])
			last_freq = i;

	printk(KERN_INFO "**************\n");
	if(last_freq > MAX_FREQ_INDEX)
	{
		printk(KERN_INFO "Didnt find current frequency(%u) in table!\n", plcy.cur);
		last_freq = MAX_FREQ_INDEX;
	}

        counter0 = 0;
	counter1 = 0;
        counter2 = 0;
        counter3 = 0;
	cycle_count = 0;
	tick_count = 0;

	dvfs_tick_fp = dvfs_tick;
	// DO NOT MODIFY ABOVE THIS!

	// You may modify the next two commands to define what frequency to start running at as well as what you want your performance counters to track first
	// Initial set of CPU to max
	setFreqIndex(0, last_freq);
	// Initial setup of PMU settings
	// 0x11--cycle cnt, 0x44--any cachable miss in L2, 
	// 0x43--L2 accesses, 0x10--branch misprediction
	configPMU(0x03, 0x08, 0x43, 0x10);

	return 0;
}

// Run when module is removed.
// DO NOT MODIFY
void cleanup_module(void)
{
	//setFreq(245760);
	//printPolicyInfo();
	disable_pmu();
	dvfs_tick_fp = NULL;
	printk(KERN_INFO "**************\n");
}
