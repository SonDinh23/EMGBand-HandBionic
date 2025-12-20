#include "BLECentralManager.h"

BLECentralManager::BLECentralManager(BLEHandManager &pPeripheralBLE, HandState &pHandState) 
                    : peripheralBLE(pPeripheralBLE), handState(pHandState) {}

void BLECentralManager::onConnect(NimBLEClient* pClient) {
    canScan = false;
    switch (typeDeviceSensor) {
        case myoband:
            Serial.println("Connect to MyO Band");
            currentDeviceConnect = 1;
            break;
        default:
            Serial.println("Connect to other device");
            currentDeviceConnect = 0;
            break;
    }
    Serial.print("deviceID curent connect: ");
    Serial.println(pClient->getPeerAddress().toString().c_str());
}

void BLECentralManager::onDisconnect(NimBLEClient* pClient, int reason) {
  peripheralBLE.notifyDeviceStateConnect(false);
  uint8_t ledRGB[] = {0, 0, 0};
  cSensor = 'c';
  handState.setRGB(ledRGB);

  switch (currentDeviceConnect) {
    case 1:
        Serial.println("DisConnect to MyO Band");
        break;
    default:
        Serial.println("DisConnect to other device");
        break;
  }
  connected = false;
}

void BLECentralManager::onResult(const NimBLEAdvertisedDevice* advertisedDevice) {
  // Serial.printf("Advertised Device found: %s\n", advertisedDevice->toString().c_str());
  // get MAC ID
  char macID[7] = {0};
  const uint8_t *pAddrID = advertisedDevice->getAddress().getVal();

  // Mac address value inversion
  macID[5] = *(pAddrID + 0);
  macID[4] = *(pAddrID + 1);
  macID[3] = *(pAddrID + 2);
  macID[2] = *(pAddrID + 3);
  macID[1] = *(pAddrID + 4);
  macID[0] = *(pAddrID + 5);

  if (equals((const uint8_t *)macID)) {
    if (advertisedDevice->isAdvertisingService(NimBLEUUID(RING_ADV_UUID)))
    {
      serviceUUID = NimBLEUUID(RING_SERVICE_UUID);
      charControlUUID = NimBLEUUID(RING_CONTROL_CHAR_UUID);
      typeDeviceSensor = myoband;
      Serial.println("myoband");
    }else return;

    NimBLEDevice::getScan()->stop();
    myDevice = new BLEAdvertisedDevice(*advertisedDevice);
    isFindSensor = true;
    Serial.println("OnResult");
  } // Found our server
} // onResult

void BLECentralManager::begin() {
  NimBLEDevice::init("");
  pClient = NimBLEDevice::createClient();
  pClient->setClientCallbacks(this);
  NimBLEScan *pBLEScan = NimBLEDevice::getScan();
  // pBLEScan->setScanCallbacks(&scanCallbacks, false);
  pBLEScan->setScanCallbacks(this);
  pBLEScan->setInterval(1349);
  pBLEScan->setWindow(449);
  pBLEScan->setActiveScan(true);
  canScan = true;
}

void BLECentralManager::controlNotifyCallback (NimBLERemoteCharacteristic* pBLERemoteCharacteristic,uint8_t* pData, size_t length, bool isNotify) {
  switch (*pData)
  {
    case 1: cSensor = 'a'; break;
    case 2: cSensor = 'c'; break;
    case 3: cSensor = 'b'; break;
    case 4: cSensor = 'd'; break;
    default: cSensor = 'c'; break;
  }
  // Serial.println(cSensor);
}

bool BLECentralManager::equals(const uint8_t *_addBLE) {
  return memcmp(_addBLE, addrDeviceControl.val, ESP_BD_ADDR_LEN) == 0;
} // equals MAC address BLE

void BLECentralManager::scanBLE() {
  
  NimBLEDevice::getScan()->clearResults();
  NimBLEDevice::getScan()->start(TIME_SCAN, false);
  // Serial.println(NimBLEDevice::getScan()->start(TIME_SCAN, false));
}

bool BLECentralManager::connectToServer() {
  bool isConnect = pClient->connect(myDevice);
  Serial.printf("state connect: %d\n", isConnect);// if you pass BLEAdvertisedDevice instead of address, it will be recognized type of peer device address (public or private)
  if (!isConnect) {
    pClient->disconnect();
    Serial.println("Connect False");
    connected = false;
    return false;
  }

  BLERemoteService* pRemoteService = pClient->getService(serviceUUID);

  if (pRemoteService == nullptr) {
    Serial.print("Failed to find our service UUID: ");
    Serial.println(serviceUUID.toString().c_str());
    Serial.println();
    pClient->disconnect();
    delay(100);
    connected = false;
    return false;
  }
   
  pControlCharacteristic = pRemoteService->getCharacteristic(charControlUUID);
  if (pControlCharacteristic == nullptr) {
    Serial.print("Failed to find our characteristic UUID: ");
    Serial.println(charControlUUID.toString().c_str());
    pClient->disconnect();
    delay(100);
    connected = false;
    return false;
  }

  if(pControlCharacteristic->canNotify())
    pControlCharacteristic->subscribe(true, [this](BLERemoteCharacteristic* pBLERemoteCharacteristic,uint8_t* pData, size_t length, bool isNotify) 
                                        {this -> controlNotifyCallback (pBLERemoteCharacteristic, pData, length, isNotify);});
  else {
    pClient->disconnect();
    delay(100);
    connected = false;
    return false;
  }

  connected = true;
  peripheralBLE.notifyDeviceStateConnect(true);
  Serial.println("connected sensor");
  return true;
}