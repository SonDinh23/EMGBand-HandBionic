#ifndef BLE_SERVICE_MANAGER_H
#define BLE_SERVICE_MANAGER_H

#include <NimBLEDevice.h>

typedef std::function<void (BLECharacteristic*)> ReadWriteFunc;

template <size_t N>
class BLEServiceManager: public BLECharacteristicCallbacks {
  public:
    BLEServiceManager(BLEService* service);

    void onWrite(BLECharacteristic *pCharacteristic, NimBLEConnInfo& connInfo);
    void onRead(BLECharacteristic *pCharacteristic, NimBLEConnInfo& connInfo);

    virtual void begin();

  protected:
    void addReadWrite(const char* charUUID, ReadWriteFunc readFunc, ReadWriteFunc writeFunc, bool isNotify = false);
    void addNotify(const char* charUUID); 
    ReadWriteFunc authed(ReadWriteFunc f);
    void addCharacteristic(const char* charUUID, uint32_t mode, bool isNotify = false);
    static ReadWriteFunc doNothing;
    BLEService* service;
    
  private:
    uint8_t charCount = 0;
    const char* uuids[N];
    ReadWriteFunc readFuncs[N], writeFuncs[N];
};

#endif