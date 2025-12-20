#include "BLEEMGSensor.h"

BLEEMGSensor::BLEEMGSensor(BLEService* service, EMGSensor& pEMGSensor): 
    BLEServiceManager(service), emgSensor(pEMGSensor) {
  addReadWrite(SETTING_CHAR_UUID, 
    authed([this](BLECharacteristic* p) {onReadSetting(p);}), 
    authed([this](BLECharacteristic* p) {onWriteSetting(p);}), true);

  addReadWrite(STATE_CONTROL_CHAR_UUID, 
    authed([this](BLECharacteristic* p) {onReadStateControl(p);}), NULL, true);

  addReadWrite(BATTERY_CHAR_UUID, 
    authed([this](BLECharacteristic* p) {onReadBattery(p);}), NULL, true);
}

void BLEEMGSensor::begin() {
    BLEServiceManager::begin();
}

uint8_t BLEEMGSensor::getModeReadSensor() {
    return onRead;
}

void BLEEMGSensor::onNotifySetting(uint8_t _state) {
  BLECharacteristic* pCharacteristic = service->getCharacteristic(SETTING_CHAR_UUID);
  switch (_state) {
    case 0:
      /* code */
      break;

    case 1: {
      EMG_Control emgCtrl = emgSensor.getEMGControl();
      switch (emgCtrl) {
        case EMG_CONTROL_LINE:
          // pCharacteristic->setValue(emgSensor.buffer, SIZE_ONE_PACKET_REV);
          pCharacteristic->setValue(emgSensor.bufferNotify, SIZE_ONE_PACKET_REV_NOTIFY);
          pCharacteristic->notify();
          // Serial.printf("Notify: ");
          // for (uint8_t i = 0; i < SIZE_ONE_PACKET_REV_NOTIFY; i++)
          // {
          //   Serial.printf("0x%02x\t", emgSensor.bufferNotify[i]);
          // }
          // Serial.println();
          break;

        case EMG_CONTROL_SPIDER:
          pCharacteristic->setValue(emgSensor.bufferNotify, SIZE_ONE_PACKET_REV_NOTIFY);
          pCharacteristic->notify();
          break;
      
        default:
          break;
      }
      break;
    }

  default:
    break;
  }
}

void BLEEMGSensor::onReadSetting(BLECharacteristic* pChar) {
  if (stateSetting == stateSet_Default) return;
  const char* s;
  encode(s);
  Serial.println(strlen(s));
  pChar->setValue(s);
}

void BLEEMGSensor::onWriteSetting(BLECharacteristic* pChar) {
  const char* s = pChar->getValue().c_str();
  if (strlen(s) == 0) return;
  Serial.println(s);
  char strJson[strlen(s) + 1] = {0};
  memcpy(strJson, s, strlen(s));
  strJson[strlen(s)] = '\0';
  decode(strJson);
}

void BLEEMGSensor::encode(const char *&pData) {
  JsonDocument doc;
  String strSetting;
  switch (stateSetting) {
    case stateSet_Logic: {
      doc["mode"] = SETTING;
      doc["type"] = UPDATE;
      doc["val"]["type"] = LOGIC_JSON;
      doc["val"]["state"] = emgSensor.getModeLogicControl();
      break;
    }

    case stateSet_ThresholdLine: {
      memcpy(thresholdLine, emgSensor.getThresholdLine(), sizeof(thresholdLine));
      doc["mode"] = SETTING;
      doc["type"] = UPDATE;
      JsonObject valObj = doc["val"].to<JsonObject>();
      valObj["type"] = THRESHOLD_LINE_JSON;
      JsonArray arr = valObj["val"].to<JsonArray>();
      arr.add(thresholdLine[0]);
      arr.add(thresholdLine[1]);
      arr.add(thresholdLine[2]);
      arr.add(thresholdLine[3]);
      break;
    }

    case stateSet_ThresholdSpider: {
      memcpy(thresholdSpider, emgSensor.getThresholdSpider(), sizeof(thresholdSpider));
      // doc["mode"] = SETTING;
      // doc["type"] = UPDATE;
      // JsonObject valObj = doc["val"].to<JsonObject>();
      // valObj["type"] = THRESHOLD_SPIDER_JSON;
      // JsonArray outer = valObj["val"].to<JsonArray>();
      // for (int i = 0; i < 4; i++) {
      //   JsonArray inner = outer.add<JsonArray>(); 
      //   for (int j = 0; j < 6; j++) {
      //     inner.add(thresholdSpider[i][j]);
      //   }
      // }
      doc["type"] = THRESHOLD_SPIDER_JSON;
      JsonArray outer = doc["val"].to<JsonArray>();
      for (int i = 0; i < 4; i++) {
        JsonArray inner = outer.add<JsonArray>(); 
        for (int j = 0; j < 6; j++) {
          inner.add(thresholdSpider[i][j]);
        }
      }
      break;
    }

    case stateSet_EMGCtrl: {
      doc["mode"] = SETTING;
      doc["type"] = UPDATE;
      doc["val"]["type"] = EMG_CONTROL_JSON;
      doc["val"]["state"] = emgSensor.getEMGControl();
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

void BLEEMGSensor::decode(char *pData) {
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

void BLEEMGSensor::sendSetting(JsonDocument json) {
  const char* type = json["val"]["type"];
  if (memcmp(type , LOGIC_JSON, strlen(LOGIC_JSON)) == 0) {
    uint8_t modeLogic = json["val"]["state"];
    emgSensor.setModeLogicControl(modeLogic);
    Serial.printf("ModeLogic: %s\n", modeLogic);
  }else if (memcmp(type, THRESHOLD_LINE_JSON, strlen(THRESHOLD_LINE_JSON)) == 0) {
    const char *s = json["val"]["TH"];
    sscanf(s, "%d:%d:%d:%d", &thresholdLine[0], &thresholdLine[1], &thresholdLine[2], &thresholdLine[3]);
    Serial.printf("Threshold BLE: %d, %d, %d, %d\n", thresholdLine[0], thresholdLine[1], thresholdLine[2], thresholdLine[3]);
    emgSensor.setThresholdLine(thresholdLine);
  }else if (memcmp(type, THRESHOLD_SPIDER_JSON, strlen(THRESHOLD_SPIDER_JSON)) == 0) {
    // const char *s = json["val"]["TH"];
    // float thresholdNet[6];
    // uint32_t grip;
    // vTaskDelay(250);
    // // Serial.printf("Set Threshold Spider: %s\n", s);
    // sscanf(s, "%d@%f:%f:%f:%f:%f:%f", &grip, &thresholdNet[0], &thresholdNet[1], &thresholdNet[2], &thresholdNet[3], &thresholdNet[4], &thresholdNet[5]);
    // Serial.printf("BLE Grip: %d\t", grip);
    // for (size_t i = 0; i < 6; i++) {
    //   Serial.printf("%.4f\t", thresholdNet[i]);
    // }
    // Serial.println();
    // emgSensor.setThresholdSpider((uint32_t)grip, thresholdNet);
    const char *s = json["val"]["TH"];
    float thresholdNet[6];
    uint32_t grip;

    // vTaskDelay(250); // ❌ bỏ: dễ treo task nimble_host

    if (!s || !*s)
    {
      Serial.println("ERR: TH null/empty");
      return;
    }

    // parse "grip@f1:f2:f3:f4:f5:f6"
    char *endp = nullptr;
    unsigned long g = strtoul(s, &endp, 10);
    if (endp == s || *endp != '@')
    {
      Serial.println("ERR: format grip@...");
      return;
    }
    grip = (uint32_t)g;

    const char *p = endp + 1;
    for (int i = 0; i < 6; ++i)
    {
      thresholdNet[i] = strtof(p, &endp);
      if (p == endp)
      {
        Serial.printf("ERR: float #%d\n", i);
        return;
      }
      if (i < 5)
      {
        if (*endp != ':')
        {
          Serial.printf("ERR: missing ':' after #%d\n", i);
          return;
        }
        p = endp + 1;
      }
    }

    Serial.printf("BLE Grip: %u\t", grip);
    for (size_t i = 0; i < 6; ++i)
      Serial.printf("%.4f\t", thresholdNet[i]);
    Serial.println();

    emgSensor.setThresholdSpider(grip, thresholdNet);
  }else if (memcmp(type, EMG_CONTROL_JSON, strlen(EMG_CONTROL_JSON)) == 0) {
    uint8_t emgCtrl = json["val"]["state"];
    if (emgSensor.getEMGControl() == static_cast<EMG_Control>(emgCtrl)) return;
    emgSensor.setEMGControl(static_cast<EMG_Control>(emgCtrl));
    Serial.printf("EMG ctrl: %d\n", emgCtrl);
    delay(300);
    esp_cpu_reset(1);
  }else if (memcmp(type, READ_MODE_SENSOR_JSON, strlen(READ_MODE_SENSOR_JSON)) == 0) {
    uint8_t modeRead = json["val"]["state"];
    onRead = modeRead;
    Serial.printf("OnRead: %d\n", onRead);
  }
}

void BLEEMGSensor::readSetting(JsonDocument json) {
  const char* val = json["val"];
  if (memcmp(val , LOGIC_JSON, strlen(LOGIC_JSON)) == 0) {
    stateSetting = stateSet_Logic;
  }else if (memcmp(val , THRESHOLD_LINE_JSON, strlen(THRESHOLD_LINE_JSON)) == 0) {
    stateSetting = stateSet_ThresholdLine;
  }else if (memcmp(val , THRESHOLD_SPIDER_JSON, strlen(THRESHOLD_SPIDER_JSON)) == 0) {
    stateSetting = stateSet_ThresholdSpider;
  }else if (memcmp(val , EMG_CONTROL_JSON, strlen(EMG_CONTROL_JSON)) == 0) {
    stateSetting = stateSet_EMGCtrl;
  }else if (memcmp(val , READ_MODE_SENSOR_JSON, strlen(READ_MODE_SENSOR_JSON)) == 0) {
    stateSetting = stateSet_ReadModeSens;
  }
}

/*  Read State Control
    1: relax
    2: hold
    3: flex
*/
void BLEEMGSensor::onReadStateControl(BLECharacteristic* pChar) {
    uint8_t _stateControl = emgSensor.getStateControl() + 2;
    pChar->setValue(&_stateControl, 1);
}
  
void BLEEMGSensor::onNotifyStateControl(int8_t _stateControl) {
    uint8_t stateControl = _stateControl + 2;
    BLECharacteristic* pCharacteristic = service->getCharacteristic(STATE_CONTROL_CHAR_UUID);
    pCharacteristic->setValue(&stateControl, 1);
    pCharacteristic->notify();
  }
  
void BLEEMGSensor::onReadBattery(BLECharacteristic* pChar) {
    pChar->setValue(&batteryPercent, 1);
}

  
void BLEEMGSensor::onNotifyBattery(uint8_t _battery) {
    BLECharacteristic* pCharacteristic = service->getCharacteristic(BATTERY_CHAR_UUID);
    if (batteryPercent == _battery) return;
    batteryPercent = _battery;
    pCharacteristic->setValue(&batteryPercent, 1);
    pCharacteristic->notify();
}
