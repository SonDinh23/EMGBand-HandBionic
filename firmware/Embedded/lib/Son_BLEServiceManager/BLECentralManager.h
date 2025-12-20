#ifndef BLE_CENTRAL_MANAGER_H
#define BLE_CENTRAL_MANAGER_H

#include <Arduino.h>
#include <NimBLEDevice.h>
#include <Update.h>
#include <ArduinoJson.h>
#include "SPIFFS.h"
#include "HandState.h"
#include "BLEHandManager.h"

#define RING_ADV_UUID                   "911da4e1-586f-4d4e-a00f-154d84c3aacc"
#define RING_SERVICE_UUID               "30923486-dc89-4a2e-8397-f9db7fe03144"
#define RING_CONTROL_CHAR_UUID          "22e5bbd9-62d8-45eb-9ffd-4a2b88cd6c3a"

#define TIME_SCAN    3000                  //scan cycle
#define TIME_ADV     10 * 1000          //Adv cycle

class BLECentralManager: public NimBLEClientCallbacks, public NimBLEScanCallbacks {
    public:
        BLECentralManager(BLEHandManager &pPeripheralBLE, HandState &pHandState);
        void begin();

        bool equals(const uint8_t* _addBLE);
        void scanBLE();
        void onConnect(NimBLEClient* pClient);
        void onDisconnect(NimBLEClient* pClient, int reason);
        void onResult(const NimBLEAdvertisedDevice* advertisedDevice);
        
        bool connectToServer();

        NimBLEClient* pClient;
        bool isFindSensor = false;
        bool connected = false;
        ble_addr_t addrDeviceControl;

        char cSensor = 'c';

        enum DeviceType{none, myoband};

    private:
        BLEUUID serviceUUID;
        BLEUUID charControlUUID;

        NimBLERemoteCharacteristic* pControlCharacteristic;
        BLEAdvertisedDevice* myDevice;

        BLEHandManager &peripheralBLE;
        HandState &handState;

        uint8_t currentDeviceConnect = 0;
        DeviceType typeDeviceSensor;

        void controlNotifyCallback(NimBLERemoteCharacteristic* pBLERemoteCharacteristic,uint8_t* pData, size_t length, bool isNotify);

        bool canScan = true;
};

#endif