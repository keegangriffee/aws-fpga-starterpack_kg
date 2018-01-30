all:
	g++ -o app ./app.cpp ../common/*.h ../common/*.hpp ../common/*.cpp -lfpga_mgmt -I${SDK_DIR}/userspace/include/ -I../common/ -lrt -lpthread -std=c++0x

clean:
	rm app


