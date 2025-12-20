#ifndef EMG_SENSOR_H
#define EMG_SENSOR_H

#include <esp_task_wdt.h>
#include <SPI.h>
#include <Preferences.h>
#include <Adafruit_NeoPixel.h>
#include <SimpleKalmanFilter.h>
#include "Mcp320x.h"
#include "SPIFFS.h"
#include "KickFiltersRT.h"
#include "Son_Utils.h"
#include "BuzzerMusic.h"

#define FS                    		    1000
#define CYCLE                    	    1000
#define ACCURACY 					    70.0

#define LIMITVALUEMAX				    40.0
#define LIMITVALUEMIN				    0.0

#define THRESHOLD_SETUP 			    80
#define THRESHOLD_DC    			    40
#define THRESHOLD_LOW   			    15
#define THRESHOLD_HIGH  			    35
#define THRESHOLD_GRIP  			    50
#define THRESHOLD_MAX   			    1000

#define TIME_READY 					    3000
#define TIME_SETUP_SENSOR			    30000

#define ADC_VREF    				    3300    				// 3.3V Vref
#define CHANELS     				    6      					// samples

#define SIZE_WRITE					    CHANELS * 4
#define LENGTH_FRAME				    (CHANELS + 1)

#define SIZE_ONE_PACKET_REV			    sizeof(float) * LENGTH_FRAME // array CHANELS + 1 float (CHANELS sensor + 1 time read)
#define NUMBER_PACKET_REV			    10							//10 packet/send
#define LENGTH_DATA_REV				    NUMBER_PACKET_REV * SIZE_ONE_PACKET_REV // <600 byte
#define SIZE_ONE_PACKET_REV_NOTIFY	    2 * LENGTH_FRAME //haft size array CHANELS + 1 float (CHANELS sensor + 1 time read)


enum EMG_Control{
    EMG_CONTROL_NONE = 0,
    EMG_CONTROL_LINE = 1,
    EMG_CONTROL_SPIDER = 2,
};

class EMGSensor {
    public:
        EMGSensor(MCP3208 &_adc, Adafruit_NeoPixel &_pixels, BuzzerMusic &_buzzer);
		void testSensor();
        bool begin();
		int8_t sync(bool isStreamBLE = false);
		void syncLine(bool isStreamBLE = false);
		void syncSpider(bool isStreamBLE = false);

        bool isReady();

        uint16_t* getThresholdLine();
		void setThresholdLine(uint16_t _threshol[]);
		void restoreThresholdLine();

        float* getThresholdSpider();
		void setThresholdSpider(uint32_t grip, float _threshol[]);
		void restoreThresholdSpider();

		int8_t getStateControl();
		void setModeLogicControl(uint8_t _mode);
		uint8_t getModeLogicControl();

		void notifyConfirm(bool isSuccess);
		void setLed(uint8_t r, uint8_t g, uint8_t b);

        void setEMGControl(EMG_Control state);
        EMG_Control getEMGControl();

		uint8_t bufferNotify[SIZE_ONE_PACKET_REV_NOTIFY];
        uint8_t buffer[SIZE_ONE_PACKET_REV];			
		float data[CHANELS+1] = {0};  // chanels + timeCycle

		Adafruit_NeoPixel* pixels;
		BuzzerMusic* buzzer;
    private:
        uint16_t SWSPL_FREQ;
        Preferences pref;
        
        MCP3208 &adc;
        KickFiltersRT<float> ftHighSensor[8];
		KickFiltersRT<float> ftLowSensor[8];

        SimpleKalmanFilter filter0 =  SimpleKalmanFilter(2, 2, 0.01);
		SimpleKalmanFilter filter1 =  SimpleKalmanFilter(2, 2, 0.01);
		SimpleKalmanFilter filter2 =  SimpleKalmanFilter(2, 2, 0.01);
		SimpleKalmanFilter filter3 =  SimpleKalmanFilter(2, 2, 0.01);
		SimpleKalmanFilter filter4 =  SimpleKalmanFilter(2, 2, 0.01);
		SimpleKalmanFilter filter5 =  SimpleKalmanFilter(2, 2, 0.01);

        EMG_Control emgControl = EMG_CONTROL_SPIDER;

		bool stateReady = false;        // State Ring

		//Variable of logic Control
		uint8_t modeLogic = 1; 
		int8_t open = -1;
		int8_t close = 1;
		int8_t hold = 0;
		int8_t gripControl = 2;

		int8_t stateControl = 0;

		uint32_t timeCycle;
		uint32_t timeSetRead;
		uint32_t timeRead = micros();
		uint8_t chanels = 6; 							//number of channels

		//Dynamic memory pointer
		float *dataPoint;

        //Threshold for control processing
		float thresholdSpider[4][6]= {
			{1.0, 1.0, 1.0, 1.0, 1.0, 1.0},
			{1.0, 1.0, 1.0, 1.0, 1.0, 1.0},
			{1.0, 1.0, 1.0, 1.0, 1.0, 1.0},
			{1.0, 1.0, 1.0, 1.0, 1.0, 1.0},
		};

        //Threshold for control processing
		uint16_t thresholdLine[4]= {THRESHOLD_SETUP, THRESHOLD_LOW, THRESHOLD_HIGH, THRESHOLD_GRIP};

        //Variable for sensor signal processing
		uint16_t sensor[CHANELS];
		float value[CHANELS];
		float valueAbs[CHANELS];
		float valueOut[CHANELS];
		float filterKalman[CHANELS];
		float output;

        float outputNormalize[CHANELS] = {1.0, 1.0, 1.0, 1.0, 1.0, 1.0};

		bool stateWait = false;

        bool isGetOnHand();
		void converHaftFloat();

        //Function for sensor signal processing
		void firstReadSensor();
		void readSensor();
		void filterSensor();
		void normalizeData();
		void checkGrip();
		bool waitSensor(uint16_t threshold, uint16_t waitTime);
		bool waitRelax(uint16_t maxTimeWait = 0);
};

#endif