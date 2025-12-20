#include "BLEServiceManager.h"
#include "Arduino.h"

template <size_t N>
ReadWriteFunc BLEServiceManager<N>::doNothing = [](BLECharacteristic* p) {};

template <size_t N>
BLEServiceManager<N>::BLEServiceManager(BLEService* bleService) {
    this->service = bleService;
}

template <size_t N>
void BLEServiceManager<N>::begin() {
  service->start();
}

template <size_t N>
ReadWriteFunc BLEServiceManager<N>::authed(ReadWriteFunc f) {
  return [f, this](BLECharacteristic* p) {
      f(p);
  };
}

template <size_t N>
void BLEServiceManager<N>::onRead(BLECharacteristic* pCharacteristic, NimBLEConnInfo& connInfo) {
  const char* c = pCharacteristic->getUUID().toString().c_str();
  for (uint8_t i = 0; i < charCount; i++) {
    if (strcmp(c, uuids[i]) == 0) {
      readFuncs[i](pCharacteristic);
      return;
    }
  }
}

template <size_t N>
void BLEServiceManager<N>::onWrite(BLECharacteristic* pCharacteristic, NimBLEConnInfo& connInfo) {
  const char* c = pCharacteristic->getUUID().toString().c_str();
  for (uint8_t i = 0; i < charCount; i++) {
    if (strcmp(c, uuids[i]) == 0) {
      writeFuncs[i](pCharacteristic);
      return;
    }
  }
}

template <size_t N>
void BLEServiceManager<N>::addReadWrite(const char* charUUID, ReadWriteFunc readFunc, ReadWriteFunc writeFunc, bool isNotify) {
  addCharacteristic(charUUID, 
    (readFunc == NULL ? 0 : NIMBLE_PROPERTY::READ) | 
    (writeFunc == NULL ? 0 : NIMBLE_PROPERTY::WRITE) | 
    (!isNotify ? 0 : NIMBLE_PROPERTY::NOTIFY), 
    isNotify);
  uuids[charCount] = charUUID;
  readFuncs[charCount] = readFunc;
  writeFuncs[charCount] = writeFunc;
  charCount++;
}

template <size_t N>
void BLEServiceManager<N>::addNotify(const char* charUUID) {
  addCharacteristic(charUUID, NIMBLE_PROPERTY::NOTIFY, true);  
  uuids[charCount] = charUUID;
  charCount++;
}

template <size_t N>
void BLEServiceManager<N>::addCharacteristic(const char* charUUID, uint32_t mode, bool isNotify) {
  BLECharacteristic *characteristic = service->createCharacteristic(charUUID, mode);

  // if (isNotify) characteristic->addDescriptor(new BLE2902());

  // characteristic->setAccessPermissions(
  //     ESP_GATT_PERM_READ_ENCRYPTED | ESP_GATT_PERM_WRITE_ENCRYPTED);
  characteristic->setCallbacks(this);
}

template class BLEServiceManager<1>;
template class BLEServiceManager<2>;
template class BLEServiceManager<3>;
template class BLEServiceManager<4>;
template class BLEServiceManager<5>;
template class BLEServiceManager<6>;