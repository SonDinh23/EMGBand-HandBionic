#include "BLERingManager.h"

BLERingManager::BLERingManager(EMGSensor& pEMGSensor):emgSensor(pEMGSensor) {
}

void BLERingManager::onConnect(NimBLEServer* pServer, NimBLEConnInfo& connInfo) {
    stateConnect = true;
    Serial.println("Connected");
	Serial.print("MTU: ");
	Serial.println(connInfo.getMTU());
    pServer->updateConnParams(connInfo.getConnHandle(), 0x10, 0x20, 0, 400);
	emgSensor.buzzer->playSound(play_beep_double);
}

void BLERingManager::onDisconnect(NimBLEServer* pServer, NimBLEConnInfo& connInfo, int reason) {
    stateConnect = false;
    Serial.println("Disconnected");
    ringService->resetOTA();
	emgSensor.buzzer->playSound(play_warning);
}

void BLERingManager::onMTUChange(uint16_t MTU, NimBLEConnInfo &connInfo)
{
  Serial.printf("MTU updated: %u for connection ID: %u\n", MTU, connInfo.getConnHandle());
}

void BLERingManager::setPower() {
    NimBLEDevice::setPowerLevel(ESP_PWR_LVL_P9, ESP_BLE_PWR_TYPE_DEFAULT);
    NimBLEDevice::setPowerLevel(ESP_PWR_LVL_P9, ESP_BLE_PWR_TYPE_ADV);
    NimBLEDevice::setPowerLevel(ESP_PWR_LVL_P9, ESP_BLE_PWR_TYPE_SCAN);
}

void BLERingManager::setupAdvertising() {
    Serial.println("setupAdvertising");

	//get Name saved
    strncpy(name, ringService->getName(), sizeof(name) - 1);
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
    mainAdcData.setPartialServices(BLEUUID(MYOBAND_SERVICE_UUID));
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

void BLERingManager::startAdvertising() {
	char _name[ADV_NAME_LENGTH - 1];
    strncpy(_name, ringService->getName(), sizeof(name) - 1);
    _name[sizeof(_name) - 1] = '\0'; // Ensure null-termination
    
    if (strcmp(name, _name) != 0) {
      setupAdvertising();
      Serial.println("Name had been changed");
    }
    // Serial.println("start Advertising");
    BLEDevice::startAdvertising();
}

void BLERingManager::stopAdvertising() {
    BLEDevice::stopAdvertising();
}

void BLERingManager::startServer() {
	BLEDevice::init("");
	BLEDevice::setMTU(517);
	server = BLEDevice::createServer();
	server->setCallbacks(this);

	ringService = new BLERing(server->createService(MYOBAND_SERVICE_UUID), emgSensor);
	emgSensorService = new BLEEMGSensor(server->createService(BLEUUID(SENSOR_SERVICE_UUID)), emgSensor);

	ringService->begin();
	emgSensorService->begin();
	
	// Restore original name after firmware upgrade
	strcpy(name, ringService->getName());
	BLEDevice::setDeviceName(name);

	Serial.println("BLE started");
}
  
void BLERingManager::begin() {
	startServer();
	setPower();
	setupAdvertising();
	BLEDevice::startAdvertising();
}
  
bool BLERingManager::waitConnect(uint8_t _pinTurnOff, uint16_t _checkTimeWakeup) {
	uint32_t lastTime = millis();
	while ((millis() - lastTime < TIME_CONNECT) && (!stateConnect)) {
	  esp_task_wdt_reset();
	  emgSensor.pixels->setPixelColor(0, emgSensor.pixels->Color(255, 255, 255));
	  emgSensor.pixels->show();
	  emgSensor.buzzer->playSound(play_beep_short);
	  delay(300);
	  emgSensor.pixels->clear();
	  emgSensor.pixels->show();
	  emgSensor.buzzer->playSound(play_beep_short);
	  delay(1000);
  
	  uint32_t timeWakeUp;
	  if (!digitalRead(_pinTurnOff)) {
		timeWakeUp = millis();
		emgSensor.buzzer->playSound(play_beep);
		vTaskDelay(100);
	  }
  
	  while (!digitalRead(_pinTurnOff)) {
		if (millis() - timeWakeUp > _checkTimeWakeup) {
		  emgSensor.pixels->setPixelColor(0, emgSensor.pixels->Color(255, 0, 0));
		  emgSensor.pixels->show();
		  while(!digitalRead(_pinTurnOff)){
			esp_task_wdt_reset();
			vTaskDelay(10);
		  }
		  return stateConnect;
		  emgSensor.buzzer->playSound(play_beep_long);
		  vTaskDelay(100);
		}
		esp_task_wdt_reset();
	  }
  
	}
  
	if (stateConnect) {
	  esp_task_wdt_reset();
	  emgSensor.pixels->setPixelColor(0, emgSensor.pixels->Color(0, 255, 0));
	  emgSensor.pixels->show();
	  delay(200);
	  emgSensor.pixels->clear();
	  emgSensor.pixels->show();
	  delay(500);
	  emgSensor.pixels->setPixelColor(0, emgSensor.pixels->Color(0, 255, 0));
	  emgSensor.pixels->show();
	  emgSensor.buzzer->playSound(play_melody);
	  delay(200);
	}
	return stateConnect;
}
  
  
bool BLERingManager::isOnOTA() {
	return ringService->isOnOTA();
}
  
void BLERingManager::notifyData(uint8_t _state) {
	emgSensorService->onNotifySetting(_state);
}
  
void BLERingManager::sendControl(int8_t stateControl) {
	emgSensorService->onNotifyStateControl(stateControl);
}
  
void BLERingManager::notifyBatery(uint8_t battery) {
	emgSensorService->onNotifyBattery(battery);
}
  
uint8_t BLERingManager::getCountDevice() {
	return server->getConnectedCount();
}
  
uint8_t BLERingManager::getModeReadSensor() {
	return emgSensorService->getModeReadSensor();
}
  
BLERingManager::~BLERingManager() {
	free(ringService);
	free(emgSensorService);
}