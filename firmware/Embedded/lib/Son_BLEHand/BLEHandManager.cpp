#include "BLEHandManager.h"

BLEHandManager::BLEHandManager(HandState& state): 
  handstate(state){
}

void BLEHandManager::onConnect(BLEServer* pServer, NimBLEConnInfo& connInfo) {
  if (connInfo.isSlave()) { 
    stateConnect = true;
    Serial.println("Connected to APP");
    pServerAPP = pServer;

    // Update connection configuration with peer
    // latency = 0; min_int = 80 (100ms); max_int = 200 (250ms); timeout = 4s;
    pServer->updateConnParams(connInfo.getConnHandle(), 0x10, 0x20, 0, 400);
    handstate.onConnect();
    handInforService->setService(pServerAPP, &connInfo);
  }  
}

void BLEHandManager::onDisconnect(BLEServer* pServer, NimBLEConnInfo& connInfo, int reason) {
  if (connInfo.isSlave()) {
    stateConnect = false;
    Serial.println("Disconnected with app");
    handstate.onDisconnect();
    startAdvertising();
  }else{
    if (stateConnect == false) {
      startAdvertising();
    }
  }
}

void BLEHandManager::onMTUChange(uint16_t MTU, NimBLEConnInfo &connInfo)
{
  Serial.printf("MTU updated: %u for connection ID: %u\n", MTU, connInfo.getConnHandle());
}

void BLEHandManager::setPower() {
    NimBLEDevice::setPowerLevel(ESP_PWR_LVL_P9, ESP_BLE_PWR_TYPE_DEFAULT);
    NimBLEDevice::setPowerLevel(ESP_PWR_LVL_P9, ESP_BLE_PWR_TYPE_ADV);
    NimBLEDevice::setPowerLevel(ESP_PWR_LVL_P9, ESP_BLE_PWR_TYPE_SCAN);
}

void BLEHandManager::setupAdvertising() {
  Serial.println("setupAdvertising");
    //get Name saved
    strncpy(name, handInforService->getName(), sizeof(name) - 1);
    name[sizeof(name) - 1] = '\0'; // Ensure null-termination
  
    //get MAC ID
    char macID[7] = {0};
    const uint8_t * pAddrID = NimBLEDevice::getAddress().getVal();
    uint16_t uuidServiceData = 0xFFFF;
  
    // Mac address value inversion
    macID[5] = *(pAddrID + 0);
    macID[4] = *(pAddrID + 1);
    macID[3] = *(pAddrID + 2);
    macID[2] = *(pAddrID + 3);
    macID[1] = *(pAddrID + 4);
    macID[0] = *(pAddrID + 5);
  
    // Main advertising data
    NimBLEAdvertisementData mainAdcData;
    mainAdcData.setPartialServices(BLEUUID(HAND_INFOR_SERVICE_UUID));
    mainAdcData.setServiceData(BLEUUID(uuidServiceData), macID);
    
    // Scan response data
    NimBLEAdvertisementData scanAdcData;
    scanAdcData.setName(name);
    
    BLEAdvertising *advertising = BLEDevice::getAdvertising();
    advertising->enableScanResponse(true);
    advertising->setMinInterval(48),
    advertising->setMaxInterval(96);
    advertising->setAdvertisementData(mainAdcData);
    advertising->setScanResponseData(scanAdcData);
}

void BLEHandManager::startAdvertising() {
    char _name[ADV_NAME_LENGTH - 1];
    strncpy(_name, handInforService->getName(), sizeof(name) - 1);
    _name[sizeof(_name) - 1] = '\0'; // Ensure null-termination
    
    if (strcmp(name, _name) != 0) {
      setupAdvertising();
      Serial.println("Name had been changed");
    }
    // Serial.println("start Advertising");
    BLEDevice::startAdvertising();
}

void BLEHandManager::startServer() {
    BLEDevice::init("");
    BLEDevice::setMTU(517);
    BLEServer *server = BLEDevice::createServer();
    server->setCallbacks(this);
  
    handInforService = new BLEHandInfo(server->createService(HAND_INFOR_SERVICE_UUID), handstate);
    handControlService = new BLEHandControl(server->createService(HAND_CONTROL_SERVICE_UUID), handstate, getSlaverAddr);
  
    handInforService->begin();
    handControlService->begin();
  
    // Restore original name after firmware upgrade
    strcpy(name, handInforService->getName());
}

void BLEHandManager::begin(void(*pGetSlaverAddr)()) {
    getSlaverAddr = pGetSlaverAddr;
    startServer();
    setPower();
    setupAdvertising();
    BLEDevice::startAdvertising();
}

uint8_t* BLEHandManager::getRxAddressBLE() {
    return handControlService->getRxAddrBLE();
}
  
bool BLEHandManager::isOnOTA() {
    return handInforService->isOnOTA();
}
  
void BLEHandManager::notifyDeviceStateConnect(bool state) {
    handInforService->onNotifyDeviceStateConnect(state);
}

BLEHandManager::~BLEHandManager() {
  free(handInforService);
  free(handControlService);
}