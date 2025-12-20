#include "BLEHandControl.h"

void  BLEHandControl::getStringPref(Preferences& pref, 
    const char* key, char* data, size_t maxLen, const char* defaultVal) {
    
    size_t len = pref.getBytes(key, data, maxLen);
    if (len == 0) {
      len = strlen(defaultVal);
      memcpy(data, defaultVal, len);
    }
    data[len] = '\0';
}

BLEHandControl::BLEHandControl(BLEService* service, HandState& phandState, void(*pGetSlaverAddr)()): 
    BLEServiceManager(service), handState(phandState){
  getSlaverAddr = pGetSlaverAddr;
  addReadWrite(SETTING_CHAR_UUID, 
    authed([this](BLECharacteristic* p) {onReadSetting(p);}), 
    authed([this](BLECharacteristic* p) {onWriteSetting(p);}), true);
}

void BLEHandControl::begin() {
    BLEServiceManager::begin();
    pref.begin("ble-control", false);
    
    // get BLE master
    const uint8_t* _addrBLE = NimBLEDevice::getAddress().getVal();
    uint8_t addrBLE[6] = {0};
  
    // Mac address value inversion
    addrBLE[5] = *(_addrBLE + 0);
    addrBLE[4] = *(_addrBLE + 1);
    addrBLE[3] = *(_addrBLE + 2);
    addrBLE[2] = *(_addrBLE + 3);
    addrBLE[1] = *(_addrBLE + 4);
    addrBLE[0] = *(_addrBLE + 5);
  
    memcpy((void*)txAddrBLE, addrBLE, sizeof(txAddrBLE));
    Serial.print("MAC Address Master: ");
    for (size_t i = 0; i < 6; i++){
      Serial.printf("%x:",txAddrBLE[i]);
    }
    Serial.println();
  
    // get BLE slave
    pref.getBytes("txAddrBLE", rxAddrBLE, sizeof(rxAddrBLE));
    printAddrBLE();
}

uint8_t* BLEHandControl::getRxAddrBLE() {
    // pref.getBytes("txAddrBLE", rxAddrBLE, sizeof(rxAddrBLE));
    // printAddrBLE();
    return rxAddrBLE;
}

void BLEHandControl::onReadSetting(BLECharacteristic* pChar) {  
  if (stateSetting == stateSet_Default) return;
  const char* s;
  encode(s);
  // Serial.println(s);
  pChar->setValue(s);
}

void BLEHandControl::onWriteSetting(BLECharacteristic* pChar) {
  const char* s = pChar->getValue().c_str();
  if (strlen(s) == 0) return;
  Serial.println(s);
  char strJson[strlen(s) + 1] = {0};
  memcpy(strJson, s, strlen(s));
  strJson[strlen(s)] = '\0';
  decode(strJson);
}

void BLEHandControl::encode(const char *&pData) {
  JsonDocument doc;
  String strSetting;
  switch (stateSetting) {
    case stateSet_AddrSens: {
      char result[35];
      pref.getBytes("typeDevice", &typeDevice, sizeof(typeDevice));
      sprintf(result, "%d@%x:%x:%x:%x:%x:%x", typeDevice, rxAddrBLE[0], rxAddrBLE[1], rxAddrBLE[2], rxAddrBLE[3], rxAddrBLE[4], rxAddrBLE[5]);
      doc["mode"] = SETTING;
      doc["type"] = UPDATE;
      doc["val"]["type"] = ADDRESS_SENSOR_JSON;
      doc["val"]["sens"] = result;
      break;
    }

    case stateSet_Speed: {
      doc["mode"] = SETTING;
      doc["type"] = UPDATE;
      doc["val"]["type"] = ADDRESS_SENSOR_JSON;
      doc["val"]["sp"] = handState.getSpeedAngle();
      break;
    }

    default:
      break;
  }
  stateSetting = stateSet_Default;
  serializeJsonPretty(doc, strSetting);
  Serial.println(strSetting);
  pData = strSetting.c_str();
}

void BLEHandControl::decode(char *pData) {
  JsonDocument json;
  DeserializationError errorJson = deserializeJson(json, pData);
  if (errorJson) {
    Serial.println("Error json");
    return;
  }
  const char* mode = json["mode"];
  const char* type = json["type"];

  if (memcmp(type , COMMAND, strlen(COMMAND)) == 0) {
    sendSetting(json);
  }else if(memcmp(type , UPDATE, strlen(UPDATE)) == 0) {
    readSetting(json);
  }
}

void BLEHandControl::sendSetting(JsonDocument json) {
  const char* type = json["val"]["type"];
  if (memcmp(type , ADDRESS_SENSOR_JSON, strlen(ADDRESS_SENSOR_JSON)) == 0) {
    const char *sens = json["val"]["sens"];
    int data[6];
    uint8_t numAddr;
    sscanf(sens, "%d@%x:%x:%x:%x:%x:%x", &numAddr, &data[0], &data[1], &data[2], &data[3], &data[4], &data[5]);
    rxAddrBLE[0] = (uint8_t) data[0];
    rxAddrBLE[1] = (uint8_t) data[1];
    rxAddrBLE[2] = (uint8_t) data[2];
    rxAddrBLE[3] = (uint8_t) data[3];
    rxAddrBLE[4] = (uint8_t) data[4];
    rxAddrBLE[5] = (uint8_t) data[5];
    pref.putBytes("txAddrBLE", rxAddrBLE, sizeof(rxAddrBLE));
    pref.putBytes("typeDevice", &numAddr, sizeof(numAddr));
    printAddrBLE();
    vTaskDelay(300);
    getSlaverAddr();
  }else if (memcmp(type, SPEED_HAND_JSON, strlen(SPEED_HAND_JSON)) == 0) {
    uint8_t speedHand = json["val"]["sp"];
    handState.setSpeed(speedHand);
    Serial.printf("speedHand: %d\n", speedHand);
  }
}

void BLEHandControl::readSetting(JsonDocument json) {
  const char* val = json["val"];
  if (memcmp(val , ADDRESS_SENSOR_JSON, strlen(ADDRESS_SENSOR_JSON)) == 0) {
    stateSetting = stateSet_AddrSens;
  }else if (memcmp(val , SPEED_HAND_JSON, strlen(SPEED_HAND_JSON)) == 0) {
    stateSetting = stateSet_Speed;
  }
}

void BLEHandControl::printAddrBLE() {
    // Serial.println("MAC Address in BLE");
    // // BLE slave 1
    Serial.print("MAC Address sensor control: ");
    for (size_t i = 0; i < 6; i++){
      Serial.printf("%x:", rxAddrBLE[i]);
    }
    Serial.println();
}