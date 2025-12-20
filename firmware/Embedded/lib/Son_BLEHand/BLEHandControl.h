#ifndef BLE_HAND_CONTROL_H
#define BLE_HAND_CONTROL_H

#include <NimBLEDevice.h>
#include <Preferences.h>
#include <FS.h>
#include <Update.h>
#include <ArduinoJson.h>
#include "SPIFFS.h"
#include "HandState.h"
#include "BLEServiceManager.h"

#define SETTING_CHAR_UUID					"a8302363-d1fa-4f07-80b6-47e47248bbf6"

#define SETTING					"set"
#define COMMAND					"cmd"
#define UPDATE					"upd"

#define ADDRESS_SENSOR_JSON     "addr"
#define SPEED_HAND_JSON         "sp"

class BLEHandControl:public BLEServiceManager<2> {
    public:
        BLEHandControl(BLEService* service, HandState& phandState, void(*pGetSlaverAddr)());
        virtual void begin();
        uint8_t* getRxAddrBLE();

    private:
        Preferences pref;
        HandState& handState;
        
        void(*getSlaverAddr)();

        uint8_t RGB[3];

        uint8_t txAddrBLE[6];			//MAC address BLE master
        uint8_t rxAddrBLE[6];

        uint8_t typeDevice = 0;

        typedef enum  {
			stateSet_Default = 0,
			stateSet_AddrSens = 1,
            stateSet_Speed = 2,
		}stateSet;

        stateSet stateSetting = stateSet_Default;

		void onReadSetting(BLECharacteristic* pChar);
		void onWriteSetting(BLECharacteristic* pChar);

		void encode(const char* &pData);
        void decode(char* pData);

        void sendSetting(JsonDocument json);
        void readSetting(JsonDocument json);

		void printAddrBLE();
		void getStringPref(Preferences& p, const char* key, char* data, size_t maxLen, const char* defaultVal);
};

#endif