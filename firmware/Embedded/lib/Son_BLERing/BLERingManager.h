#ifndef BLE_RING_MANAGER_H
#define BLE_RING_MANAGER_H

#include <Arduino.h>
#include <NimBLEDevice.h>
#include <NimBLEAdvertising.h>
#include "EMGSensor.h"
#include "BLERing.h"
#include "BLEEMGSensor.h"

#define MYOBAND_SERVICE_UUID        "911da4e1-586f-4d4e-a00f-154d84c3aacc"
#define SENSOR_SERVICE_UUID         "30923486-dc89-4a2e-8397-f9db7fe03144"

#define ADV_MAX_LENGTH      BLE_HS_ADV_MAX_SZ 
#define ADV_DATA_LENGTH     15
#define ADV_NAME_LENGTH     ADV_MAX_LENGTH - ADV_DATA_LENGTH

#define TIME_CONNECT   60000

class BLERingManager: public BLEServerCallbacks {
    public:
        BLERingManager(EMGSensor &pEMGSensor);
        ~BLERingManager();
        void begin();

        void setupAdvertising();
        void startAdvertising();
        void stopAdvertising();

        void onConnect(NimBLEServer* pServer, NimBLEConnInfo& connInfo);
        void onDisconnect(NimBLEServer* pServer, NimBLEConnInfo& connInfo, int reason);
        void onMTUChange(uint16_t MTU, NimBLEConnInfo& connInfo);

        void notifyData(uint8_t _state);
        void sendControl(int8_t stateControl);
        void notifyBatery(uint8_t battery);

        bool waitConnect(uint8_t _pinTurnOff, uint16_t _checkTimeWakeup);
        bool isOnOTA();

        uint8_t getCountDevice();

        uint8_t getModeReadSensor();

        bool stateConnect = false;

    private:
        double distance;
        char name[ADV_NAME_LENGTH - 1];
        
        BLEServer *server;
        EMGSensor& emgSensor;
        BLERing* ringService;
        BLEEMGSensor* emgSensorService;
    
        void setPower();
        void startServer();

};

#endif