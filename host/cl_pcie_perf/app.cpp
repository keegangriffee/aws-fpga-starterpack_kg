/**
 *	Host application for cl_pcie_perf	
 *
 *	@author Tommy Jung
 *	with modifications for PCIE testing by Keegan Griffee
 */

#include <iostream>
#include <cstdlib>
#include <chrono>
#include <thread>
#include <stdexcept>
#include "fabricmanager.h"
#include "pcihandler.h"
#include "dmacontroller.h"
#include "fpga_mgmt.h"
#include "stopwatch.h"
#include "math_helper.hpp"
#include <stdio.h>
#include <string.h>
using namespace std;
using namespace std::this_thread;
using namespace std::chrono;

#define START_ADDR_REG_ADDR 0x500
#define BURST_LEN_REG_ADDR 0x504
#define WRITE_VAL_REG_ADDR 0x508
#define RHASH_REG_ADDR 0x50c
#define RW_EN_REG_ADDR 0x510
#define RW_DONE_REG_ADDR 0x514
#define RD_CLK_COUNT_REG_ADDR 0x518
#define WR_CLK_COUNT_REG_ADDR 0x51c
#define BUF_SIZE (1ULL << 34)

const int SLOT_ID = 0;
const int NUM_EARLY_TRIAL = 50000;
const int NUM_TRIAL = 10;
const int BYTE_PER_BURST = 64;
const int CLK_FREQ = 250000000;

int main(int argc, char ** argv)
{		
	auto fabricManager = new FabricManager();
	//auto pciHandler = new PCIHandler();
	auto dmaController = new DMAController();
	auto stopwatch = new Stopwatch();
	fpga_mgmt_image_info_t* info = 0;
	
	char * buf1 = (char *) malloc(sizeof(char) * BUF_SIZE);
	char * buf2 = (char *) malloc(sizeof(char) * BUF_SIZE);

	try
	{
		// get fpga image info.
		info = fabricManager->getImageInfo(SLOT_ID);
		cout << "FPGA Image Info:" << endl;
		printf("Vendor ID: 0x%x\r\n", info->spec.map[FPGA_APP_PF].vendor_id);
		printf("Device ID: 0x%x\r\n", info->spec.map[FPGA_APP_PF].device_id);

		// init dmaController.
		dmaController->init(SLOT_ID);

		// Do increasingly larger transfer sizes (bytes per burst) and measure
		// the performance
		uint32_t ocl_read = 0;	
		size_t burst_len = 1;
		for (int i = 0; i < 29; i++)
		{
			int num_trial = (i < 12) ? NUM_TRIAL * NUM_EARLY_TRIAL : NUM_TRIAL;	

			double dma_read_latency[NUM_TRIAL*NUM_EARLY_TRIAL] = {0};
			double dma_write_latency[NUM_TRIAL*NUM_EARLY_TRIAL] = {0};

			for (int j = 0; j < num_trial; j++)
			{
				// init random char buffer
				for (size_t k = 0; k < burst_len*BYTE_PER_BURST; k++)
				{
					buf1[k] = (char) (97 + (rand() % 26));
				}

				// DMA write
				int addr = 0;
				// Uncomment if testing random scattered addressing
				//int addr = rand();
				stopwatch->start();
				dmaController->write(buf1, burst_len*BYTE_PER_BURST, 0, addr);
				dma_write_latency[j] = stopwatch->stop();
		

				// DMA read
				stopwatch->start();
				dmaController->read(buf2, burst_len*BYTE_PER_BURST, 0, addr);	
				dma_read_latency[j] = stopwatch->stop();

			}

			double dma_read_avg = MathHelper::average(dma_read_latency, num_trial);
			double dma_read_stdev = MathHelper::stdev(dma_read_latency, num_trial);
			double dma_write_avg = MathHelper::average(dma_write_latency, num_trial);
			double dma_write_stdev = MathHelper::stdev(dma_write_latency, num_trial);
				
			printf("dma,read,%lu,%f,%f\r\n", burst_len, dma_read_avg*1000, dma_read_stdev*1000);
			printf("dma,write,%lu,%f,%f\r\n", burst_len, dma_write_avg*1000, dma_write_stdev*1000);

			burst_len *= 2;
		}

	}
	catch(exception& e)
	{
		cout << e.what() << endl;			
	}

	// make sure to free dynamically allocated memory.
	free(info);
	free(buf1);
	free(buf2);
	delete fabricManager;
	delete dmaController;
	delete stopwatch;

	return 0;
}
