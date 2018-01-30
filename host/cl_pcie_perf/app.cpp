/**
 *	Host application for cl_dram_perf	
 *
 *	@author Tommy Jung
 *			Keegan Griffee
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

		/*
		// attach pciHandler.
		pciHandler->attach(SLOT_ID, FPGA_APP_PF, APP_PF_BAR0);
		*/

		// init dmaController.
		dmaController->init(SLOT_ID);

		/*
		// set start_addr
		pciHandler->poke(START_ADDR_REG_ADDR, 0);
		uint32_t start_addr_read = pciHandler->peek(START_ADDR_REG_ADDR);
		if (start_addr_read != 0)
		{
			throw runtime_error("failed to write start_addr\r\n");
		}
		*/

		// real test
		uint32_t ocl_read = 0;	
		size_t burst_len = 1;
		for (int i = 0; i < 29; i++)
		{
			int num_trial = (i < 12) ? NUM_TRIAL * 100 : NUM_TRIAL;	

			double dma_read_latency[NUM_TRIAL*100] = {0};
			double dma_write_latency[NUM_TRIAL*100] = {0};

			for (int j = 0; j < num_trial; j++)
			{
				// init random char buffer
				for (size_t k = 0; k < burst_len*BYTE_PER_BURST; k++)
				{
					buf1[k] = (char) (97 + (rand() % 26));
				}
				
				// DMA write
				stopwatch->start();
				dmaController->write(buf1, burst_len*BYTE_PER_BURST, 0, 0);
				dma_write_latency[j] = stopwatch->stop();
		

				// DMA read
				stopwatch->start();
				dmaController->read(buf2, burst_len*BYTE_PER_BURST, 0, 0);	
				dma_read_latency[j] = stopwatch->stop();
				
			}

			double dma_read_avg = MathHelper::average(dma_read_latency, num_trial);
			double dma_read_stdev = MathHelper::stdev(dma_read_latency, num_trial);
			double dma_write_avg = MathHelper::average(dma_write_latency, num_trial);
			double dma_write_stdev = MathHelper::stdev(dma_write_latency, num_trial);
				
			double cl_read_avg = MathHelper::average(cl_read_latency, num_trial);
			double cl_read_stdev = MathHelper::stdev(cl_read_latency, num_trial);
			double cl_write_avg = MathHelper::average(cl_write_latency, num_trial);
			double cl_write_stdev = MathHelper::stdev(cl_write_latency, num_trial);
			
			double cl_read_clk_count_avg = MathHelper::average(cl_read_clk_count, num_trial);
			double cl_read_clk_count_stdev = MathHelper::stdev(cl_read_clk_count, num_trial);
			
			double cl_write_clk_count_avg = MathHelper::average(cl_write_clk_count, num_trial);
			double cl_write_clk_count_stdev = MathHelper::stdev(cl_write_clk_count, num_trial);
	
			printf("dma,read,%lu,%f,%f\r\n", burst_len, dma_read_avg*1000, dma_read_stdev*1000);
			printf("dma,write,%lu,%f,%f\r\n", burst_len, dma_write_avg*1000, dma_write_stdev*1000);
			printf("cl,read,%lu,%f,%f\r\n", burst_len, cl_read_avg*1000, cl_read_stdev*1000);
			printf("cl,write,%lu,%f,%f\r\n", burst_len, cl_write_avg*1000, cl_write_stdev*1000);
			printf("internal_clk,read,%lu,%f,%f\r\n",burst_len, cl_read_clk_count_avg/CLK_FREQ*1000,
				cl_read_clk_count_stdev/CLK_FREQ*1000);
			printf("internal_clk,write,%lu,%f,%f\r\n",burst_len, cl_write_clk_count_avg/CLK_FREQ*1000,
				cl_write_clk_count_stdev/CLK_FREQ*1000);


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
	//delete pciHandler;
	delete dmaController;
	delete stopwatch;

	return 0;
}
