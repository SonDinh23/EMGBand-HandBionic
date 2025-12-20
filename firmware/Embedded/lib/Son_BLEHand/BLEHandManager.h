#ifndef BLE_HAND_MANAGER_H
#define BLE_HAND_MANAGER_H

#include <Arduino.h>
#include <NimBLEDevice.h>
#include <NimBLEAdvertising.h>
#include "BLEHandInfo.h"
#include "BLEHandControl.h"
#include "HandState.h"

#define HAND_INFOR_SERVICE_UUID         "3492a42f-4316-4c23-89cc-973b5fcf5c21"
#define HAND_CONTROL_SERVICE_UUID       "9c8f199d-4a54-4b3f-907c-0c4399b6329d"

#define ESP_BD_ADDR_LEN 6

#define ADV_MAX_LENGTH      BLE_HS_ADV_MAX_SZ 
#define ADV_DATA_LENGTH     15
#define ADV_NAME_LENGTH     ADV_MAX_LENGTH - ADV_DATA_LENGTH

class BLEHandManager: public BLEServerCallbacks {
    public:
        BLEHandManager(HandState& state);
        ~BLEHandManager();
        void begin(void(*pGetSlaverAddr)());

        void onConnect(BLEServer* pServer, NimBLEConnInfo& connInfo);
        void onDisconnect(BLEServer* pServer, NimBLEConnInfo& connInfo, int reason);
        void onMTUChange(uint16_t MTU, NimBLEConnInfo& connInfo);

        uint8_t* getRxAddressBLE();
        bool isOnOTA();

        void notifyDeviceStateConnect(bool state);

        void startAdvertising();

        bool stateConnect = false;
    private:
        char name[ADV_NAME_LENGTH - 1];
        
        BLEServer* pServerAPP;
        // ble_gap_conn_desc* paramAPP; 

        HandState& handstate;

        BLEHandInfo* handInforService;
        BLEHandControl* handControlService;

        void setPower();
        void setupAdvertising();
        
        void startServer();

        void(*getSlaverAddr)();
};

#endif