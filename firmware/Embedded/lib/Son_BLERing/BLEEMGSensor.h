#ifndef BLE_EMG_SENSOR_H
#define BLE_EMG_SENSOR_H

#include <NimBLEDevice.h>
#include <Preferences.h>
#include <ArduinoJson.h>
#include "SPIFFS.h"
#include <FS.h>
#include <Update.h>
#include "esp_task_wdt.h"
#include "BLEServiceManager.h"
#include "EMGSensor.h"

#define SETTING_CHAR_UUID								    "39b2df5b-b7d4-48c6-afd2-e0095d4a999c"
#define STATE_CONTROL_CHAR_UUID						        "22e5bbd9-62d8-45eb-9ffd-4a2b88cd6c3a"
#define BATTERY_CHAR_UUID									"d23b3d36-e178-4528-af4d-7e8f9139aa20"

#define SETTING					"set"
#define COMMAND					"cmd"
#define UPDATE					"upd"

#define LOGIC_JSON       		"lgc"
#define THRESHOLD_LINE_JSON   	"THL"
#define THRESHOLD_SPIDER_JSON   "THS"
#define EMG_CONTROL_JSON   		"EMGCtrl"
#define READ_MODE_SENSOR_JSON   "RMS"

class BLEEMGSensor:public BLEServiceManager<4> {
  public:
		BLEEMGSensor(BLEService* service, EMGSensor& pEMGSensor);
		virtual void begin();
		void onNotifyStateControl(int8_t _stateControl);
		void onNotifyBattery(uint8_t _battery);
		void onNotifySetting(uint8_t _state);
		
		uint8_t getModeReadSensor();

  private:
		EMGSensor& emgSensor;
		uint8_t onRead = 0; 	// 0: normal | 1: read EMG sensor
		uint8_t batteryPercent = 0;

		float thresholdSpider[4][6]= {
			{1.0, 1.0, 1.0, 1.0, 1.0, 1.0},
			{1.0, 1.0, 1.0, 1.0, 1.0, 1.0},
			{1.0, 1.0, 1.0, 1.0, 1.0, 1.0},
			{1.0, 1.0, 1.0, 1.0, 1.0, 1.0},
		};

        uint16_t thresholdLine[4] = {0, 0, 0, 0};

		typedef enum  {
			stateSet_Default = 0,
			stateSet_Logic = 1,
			stateSet_ThresholdLine = 2,
			stateSet_ThresholdSpider= 3,
			stateSet_EMGCtrl = 4,
			stateSet_ReadModeSens = 5,
		}stateSet;
		
		stateSet stateSetting = stateSet_Default;

		void onReadSetting(BLECharacteristic* pChar);
		void onWriteSetting(BLECharacteristic* pChar);	

		void onReadStateControl(BLECharacteristic* pChar);

		void encode(const char* &pData);
        void decode(char* pData);

        void sendSetting(JsonDocument json);
        void readSetting(JsonDocument json);

		void onReadBattery(BLECharacteristic* pChar);
};

#endif