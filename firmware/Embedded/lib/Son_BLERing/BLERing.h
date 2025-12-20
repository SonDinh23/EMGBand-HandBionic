#ifndef BLE_RING_H
#define BLE_RING_H

#include <NimBLEDevice.h>
#include <Preferences.h>
#include <ArduinoJson.h>
#include "SPIFFS.h"
#include <FS.h>
#include <Update.h>
#include "esp_ota_ops.h"
#include "esp_task_wdt.h"
#include "BLEServiceManager.h"
#include "EMGSensor.h"

#define OTA_CHAR_UUID						"149f93ef-7481-4536-8f75-50b5b55ab058"
#define MYOBAND_INFO_CHAR_UUID			    "514bd5a1-1ef9-49c8-b569-127a84896d25"

#define UPDATE_START_MSG                    "START_OTA"
#define UPDATE_END_MSG                      "END_OTA"

#define VERSION                             "0.0.1"
#define INIT_NAME                           "MyoBand Crytals"
#define INIT_HARDWARE				        "MYO"

#define MAX_VERSION_LENGTH                  10
#define MAX_NAME_LENGTH                     30
#define MAX_HARDWARE_LENGTH	                30

#define SETTING			"set"
#define COMMAND			"cmd"
#define UPDATE			"upd"

#define NAME_JSON       "nm"
#define HARDWARE_JSON   "hw"

class BLERing:public BLEServiceManager<2> {
    public:
        BLERing(BLEService* service, EMGSensor& pEMGSensor);
        virtual void begin();

        const char* getName();
        const char* getHardware();
        const char* getVersion();

        bool isOnOTA();
        void resetOTA();

    private:
        Preferences pref;
        char version[MAX_VERSION_LENGTH + 1];
        char name[MAX_NAME_LENGTH + 1];
        char hardware[MAX_HARDWARE_LENGTH +1];

        bool updateInProgress = false;
        uint32_t packageCounter = 0;
        esp_ota_handle_t otaHandler = 0;

        typedef enum  {
            stateSet_Default = 0,
            stateSet_Name = 1,
            stateSet_Hardware = 2,
        }stateSet;

        stateSet stateSetting = stateSet_Default;

        EMGSensor& emgSensor;

        void onReadOTA(BLECharacteristic* pChar);
        void onWriteOTA(BLECharacteristic* pChar);
        void onNotifyOTA(uint16_t stateOTA);

        void onReadInfo(BLECharacteristic* pChar);
		void onWriteInfo(BLECharacteristic* pChar);

        void encode(const char* &pData);
        void decode(char* pData);

        void sendSetting(JsonDocument json);
        void readSetting(JsonDocument json);

        void getStringPref(Preferences& p, const char* key, char* data, size_t maxLen, const char* defaultVal);
};

#endif