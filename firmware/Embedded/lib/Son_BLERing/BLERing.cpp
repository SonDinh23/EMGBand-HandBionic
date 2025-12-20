#include "BLERing.h"
#include "freertos/FreeRTOS.h"

void  BLERing::getStringPref(Preferences& pref, 
    const char* key, char* data, size_t maxLen, const char* defaultVal) {
    
    size_t len = pref.getBytes(key, data, maxLen);
    if (len == 0) {
      len = strlen(defaultVal);
      memcpy(data, defaultVal, len);
    }
    data[len] = '\0';
}

BLERing::BLERing(BLEService* service, EMGSensor& pEMGSensor): BLEServiceManager(service), emgSensor(pEMGSensor) {
  addReadWrite(OTA_CHAR_UUID,
    authed([this](BLECharacteristic* p) {onReadOTA(p);}),
    authed([this](BLECharacteristic* p) {onWriteOTA(p);}), true);

  addReadWrite(MYOBAND_INFO_CHAR_UUID, 
    authed([this](BLECharacteristic* p) {onReadInfo(p);}), 
    authed([this](BLECharacteristic* p) {onWriteInfo(p);}));
}

void BLERing::begin() {
    BLEServiceManager::begin();
    SPIFFS.begin(true);
  
    updateInProgress = false;
    
    pref.begin("ble-info", false);

    Serial.printf("Version: %s\n", VERSION);

    getStringPref(pref, "name", name, MAX_NAME_LENGTH, INIT_NAME);
    Serial.printf("BLE MyoBand: %s\n",name);
    
    getStringPref(pref, "hardware", hardware, MAX_HARDWARE_LENGTH, INIT_HARDWARE);
    Serial.printf("Hardware Hand: %s\n",hardware);
}

const char* BLERing::getName() {
    return name;
}

const char* BLERing::getHardware() {
    return hardware;
}

const char* BLERing::getVersion() {
    return version;
}

void BLERing::onReadOTA(BLECharacteristic* pChar) {
    Serial.println("onReadOTA");
    pChar->setValue(VERSION);
}

void BLERing::onWriteOTA(BLECharacteristic* pChar) {
    // OTA save on esp_ota
    std::string rxData = pChar->getValue();
    if (rxData == UPDATE_START_MSG) {
      updateInProgress = true;
    //   ringState.notifyConfirm(true);
      Serial.println("Begin OTA");
      const esp_partition_t* partition = esp_ota_get_next_update_partition(NULL);
      Serial.println("Found partition");
      esp_err_t result = esp_ota_begin(partition, OTA_SIZE_UNKNOWN, &otaHandler);
      if (result == ESP_OK) {
        Serial.println("OTA operation commenced successfully");
      } else {
        Serial.print("Failed to commence OTA operation, error: ");
        Serial.println(result);
        resetOTA();
        return;
      }
      packageCounter = 0;
    //   ringState.setLed(255, 255, 255);
      Serial.println("Begin OTA done");
    }
    else if (rxData == UPDATE_END_MSG) {
      Serial.println("OTA: Upload completed");
      esp_err_t result = esp_ota_end(otaHandler);
      if (result == ESP_OK) {
        Serial.println("Newly written OTA app image is valid.");
      } else {
        Serial.print("Failed to validate OTA app image, error: ");
        Serial.println(result);
        resetOTA();
        return;
      }
      if (esp_ota_set_boot_partition(esp_ota_get_next_update_partition(NULL)) == ESP_OK) {
        // ringState.setLed(0, 255, 0);
        delay(1000);
        esp_restart();
      } else {
        Serial.println("OTA Error: Invalid boot partition");
        // ringState.setLed(255, 0, 0);
        delay(1000);
        // ringState.setLed(0, 0, 0);
        resetOTA();
        return;
      }
    }
    else {
      Serial.print(rxData.length()); 
      Serial.print("\t");
  
      if (esp_ota_write(otaHandler, rxData.c_str(), rxData.length()) == ESP_OK) {
        packageCounter++;
      }
      else {
        Serial.println("OTA is Fail, please try again!!!");
        packageCounter = UINT16_MAX;
      }
      Serial.println(packageCounter);
      onNotifyOTA(packageCounter);
      // Make the writes much more reliable
      vTaskDelay(1);
    }
    
}
  
void BLERing::onNotifyOTA(uint16_t stateOTA) {
  BLECharacteristic* pCharacteristic = service->getCharacteristic(OTA_CHAR_UUID);
  pCharacteristic->setValue(stateOTA);
  pCharacteristic->notify();
}

bool BLERing::isOnOTA() {
    return updateInProgress;
}
  
void BLERing::resetOTA() {
    updateInProgress = false;
}

void BLERing::onWriteInfo(BLECharacteristic* pChar) {
  const char* s = pChar->getValue().c_str();
  if (strlen(s) == 0) {
    emgSensor.buzzer->playSound(play_error);
    return;
  }
  Serial.println(s);
  char strJson[strlen(s) + 1] = {0};
  memcpy(strJson, s, strlen(s));
  strJson[strlen(s)] = '\0';
  decode(strJson);
  emgSensor.buzzer->playSound(play_beep_short);
}
  
void BLERing::onReadInfo(BLECharacteristic* pChar) {
  if (stateSetting == stateSet_Default) {
    emgSensor.buzzer->playSound(play_error);
    return;
  }
  const char* s;
  encode(s);
  // Serial.println(s);
  pChar->setValue(s);
  emgSensor.buzzer->playSound(play_beep_short);
}


void BLERing::encode(const char* &pData) {
  JsonDocument doc;
  String strSetting;
  switch (stateSetting) {
    case stateSet_Name:
      doc["mode"] = SETTING;
      doc["type"] = UPDATE;
      doc["val"]["type"] = NAME_JSON;
      doc["val"]["code"] = name;
      break;

    case stateSet_Hardware:
      doc["mode"] = SETTING;
      doc["type"] = UPDATE;
      doc["val"]["type"] = HARDWARE_JSON;
      doc["val"]["code"] = hardware;
      break;

    default:
      break;
  }
  stateSetting = stateSet_Default;
  serializeJsonPretty(doc, strSetting);
  Serial.println(strSetting);
  pData = strSetting.c_str();
}

void BLERing::decode(char* pData) {
  JsonDocument json;
  DeserializationError errorJson = deserializeJson(json, pData);
  if (errorJson) return;
  const char* mode = json["mode"];
  const char* type = json["type"];

  if (memcmp(type , COMMAND, strlen(COMMAND)) == 0) {
    sendSetting(json);
  }else if(memcmp(type , UPDATE, strlen(UPDATE)) == 0) {
    readSetting(json);
  }
}

void BLERing::sendSetting(JsonDocument json) {
  const char* type = json["val"]["type"];
  if (memcmp(type , NAME_JSON, strlen(NAME_JSON)) == 0) {
    const char *s = json["val"]["code"];
    memcpy(name, s, strlen(s) + 1);
    pref.putBytes("name", s, strlen(s));
    // Update device name, name is change after esp reset 
    BLEDevice::setDeviceName(name);
    Serial.printf("Name: %s\n", name);
  }else if (memcmp(type , HARDWARE_JSON, strlen(HARDWARE_JSON)) == 0) {
    const char *s = json["val"]["code"];
    memcpy(hardware, s, strlen(s) + 1);
    pref.putBytes("hardware", s, strlen(s));
    Serial.printf("Hardware: %s\n", hardware);
  }
}

void BLERing::readSetting(JsonDocument json) {
  const char* val = json["val"];
  if (memcmp(val , NAME_JSON, strlen(NAME_JSON)) == 0) {
    stateSetting = stateSet_Name;
  }else if (memcmp(val , HARDWARE_JSON, strlen(HARDWARE_JSON)) == 0) {
    stateSetting = stateSet_Hardware;
  }
}