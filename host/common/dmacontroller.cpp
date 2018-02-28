/**
 *	DMA controller for transferring data between host buffer and DRAM attached to FPGA.
 *
 *	@author Tommy Jung
 *	@version 1.0
 */

#include <iostream>
#include <stdexcept>
#include <string>
#include <fcntl.h>
#include "dmacontroller.h"
#include "stopwatch.h"
using namespace std;

#define	MEM_16G	(1ULL << 34)
#define DMA_OFFSET 0x00000000

/*
 * 	default constructor.
 */
DMAController::DMAController()
{
	_fd = -1;
}

/*
 * 	destructor.
 */
DMAController::~DMAController()
{
	if (_fd >= 0)
	{
		close(_fd);
	}
}

/*
 * 	Open the EDMA file descriptor.
 *	@param slot_id FPGA slot id.
 */
void DMAController::init(int slot_id)
{
	int rc;
	char device_file_name[256];
	
	sprintf(device_file_name, "/dev/edma%i_queue_0", slot_id);

	_fd = open(device_file_name, O_RDWR);

	if (_fd < 0)
	{
		throw runtime_error("failed to open /dev/edma" + to_string(slot_id) +
			"_queue_0. error_code: " + to_string(_fd) + "\r\n");
	} 
}


/*
 * 	Write the content of the buffer to CL.
 *	@param buf the starting address of buffer on host.
 *	@param buf_size the size of the buffer.
 *	@param channel DMA channel number.
 *	@param offset offset address on CL.
 */
#include <iostream>
#include <cstdlib>

void DMAController::write(char * buf, size_t buf_size, int channel, size_t offset)
{
	if (_fd < 0) throw runtime_error("File descriptor is not open.\r\n");
	
	auto stopwatch_long = new Stopwatch();
	stopwatch_long->start();
	int rc;
	size_t write_offset = 0;
	
	while (write_offset < buf_size)
	{
		rc = pwrite(_fd,
			buf + write_offset,
			buf_size - write_offset, 
			DMA_OFFSET + channel*MEM_16G + offset + write_offset);
		
		if (rc < 0)
		{
			throw runtime_error("pwrite() failed. error_code: " + to_string(rc) + "\r\n");
		}

	 	write_offset += rc;
	}

	// Used for calculating the performance impact of fsync
	//double pwrite_time = stopwatch_long->stop();
	//printf("pwrite runtime: %f\r\n", pwrite_time*1000);
	//delete stopwatch_long;

	//auto stopwatch = new Stopwatch();
	//stopwatch->start();
	fsync(_fd);
	//double timeFsync = stopwatch->stop();
	//printf("fsync runtime: %f\r\n", timeFsync*1000);
	//delete stopwatch;
}

/*
 *	Read from CL and transfer data to buffer.
 *	@param buf the starting address of buffer on host.
 *	@param buf_size the size of the buffer.
 *	@param channel DMA channel number.
 *	@param offset offset address on CL.
 */
void DMAController::read(char * buf, size_t buf_size, int channel, size_t offset)
{
	if (_fd < 0) throw runtime_error("File descriptor is not open.\r\n");

	int rc;
	size_t read_offset = 0;

	while (read_offset < buf_size)
	{
		rc = pread(_fd,
			buf + read_offset,
			buf_size - read_offset,
			DMA_OFFSET + channel*MEM_16G + offset + read_offset);

		if (rc < 0)
		{
			throw runtime_error("pread() failed. error_code: " + to_string(rc) + "\r\n");
		}

		read_offset += rc;
	}
}
