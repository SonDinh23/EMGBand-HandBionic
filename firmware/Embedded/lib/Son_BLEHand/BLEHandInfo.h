#ifndef BLE_HAND_INFOR_H
#define BLE_HAND_INFOR_H

#include <NimBLEDevice.h>
#include <Preferences.h>
#include <ArduinoJson.h>
#include "SPIFFS.h"
#include <FS.h>
#include <Update.h>

#include "esp_ota_ops.h"
#include "esp_task_wdt.h"
#include "BLEServiceManager.h"
#include "HandState.h"

#define OTA_CHAR_UUID				"76095ead-54c4-4883-88a6-8297ba18211a"
#define HAND_INFO_CHAR_UUID			"8b8f9b38-9af4-11ee-b9d1-0242ac120002"
#define CONNECT_CHAR_UUID		    "f2c513b7-6b51-4363-b6aa-1ef8bd08c56a"

#define UPDATE_START_MSG    "START_OTA"
#define UPDATE_END_MSG      "END_OTA"

#define VERSION             "0.0.1"
#define INIT_NAME           "Hand Crytals"
#define INIT_HARDWARE		"H01"

#define MAX_VERSION_LENGTH  10
#define MAX_NAME_LENGTH     30
#define MAX_HARDWARE_LENGTH	30

#define SETTING			"set"
#define COMMAND			"cmd"
#define UPDATE			"upd"

#define NAME_JSON       "nm"
#define HARDWARE_JSON   "hw"

class BLEHandInfo:public BLEServiceManager<3>
{
    public:
        BLEHandInfo(BLEService* service, HandState& phandState);

		virtual void begin();
		void setService(BLEServer* pServerAPP, NimBLEConnInfo* pConnInfo);

		const char* getName();
        const char* getHardware();
        const char* getVersion();

		bool isOnOTA();
		void setOTA();
		void resetOTA();

		void onNotifyDeviceStateConnect(bool state);

    private:
        Preferences pref;
        HandState& handState;

        BLEServer* serverAPP;
		NimBLEConnInfo* connInfo;
        // ble_gap_conn_desc* paramAPP;

        char version[MAX_VERSION_LENGTH + 1];
		char name[MAX_NAME_LENGTH + 1];
		char hardware[MAX_HARDWARE_LENGTH +1];

        uint8_t deviceStateConnect = false;

		bool updateInProgress = false;
		esp_ota_handle_t otaHandler = 0;
		uint32_t packageCounter = 0;

		typedef enum  {
            stateSet_Default = 0,
            stateSet_Name = 1,
            stateSet_Hardware = 2,
        }stateSet;

		stateSet stateSetting = stateSet_Default;

		void onReadOTA(BLECharacteristic* pChar);
		void onWriteOTA(BLECharacteristic* pChar);
		void onNotifyOTA(uint32_t stateOTA);

		void onReadInfo(BLECharacteristic* pChar);
		void onWriteInfo(BLECharacteristic* pChar);

		void onReadDeviceStateConnect(BLECharacteristic* pChar);
		
		void encode(const char* &pData);
        void decode(char* pData);

        void sendSetting(JsonDocument json);
        void readSetting(JsonDocument json);

		void getStringPref(Preferences& p, const char* key, char* data, size_t maxLen, const char* defaultVal);
};

#endif