#include <Arduino.h>
#include "HandState.h"
#include "BLEHandManager.h"
#include "BLECentralManager.h"

#define DEBUG

TaskHandle_t task_handle_ble_master;
TaskHandle_t task_handle_control;

HandState handState;
BLEHandManager peripheral(handState);
BLECentralManager central(peripheral, handState);

uint32_t lastTimeScanBLE = millis();
uint32_t lastTimeAdvBLE = millis();

void getSlaverAddr() {
  memcpy(central.addrDeviceControl.val, peripheral.getRxAddressBLE(), sizeof(central.addrDeviceControl.val));
  if (central.pClient == nullptr || !central.connected) {
    Serial.println("device null");
    return;
  }
  Serial.print("deviceID curent connected: ");
  Serial.println(central.pClient->getPeerAddress().toString().c_str());
  uint8_t addrID[7] = {0};
  const uint8_t * pAddrID = central.pClient->getPeerAddress().getVal();
  uint16_t uuidServiceData = 0xFFFF;

  // Mac address value inversion
  addrID[5] = *(pAddrID + 0);
  addrID[4] = *(pAddrID + 1);
  addrID[3] = *(pAddrID + 2);
  addrID[2] = *(pAddrID + 3);
  addrID[1] = *(pAddrID + 4);
  addrID[0] = *(pAddrID + 5);
  if (!central.equals(addrID))
  {
    Serial.println("add new sensor control: ");
    central.pClient->disconnect();
    central.connected = false;
  }
}

void BleMasterOp(void* pParamter) { // task for BLE Master
  vTaskSuspend(NULL);
  for (;;) {
    if (central.isFindSensor == true) {
      central.isFindSensor = false;
      if (central.connectToServer()) {
        Serial.println("Connect: true");
        for (size_t i = 0; i < 2; i++)
        {
          uint8_t ledBlue[] = {0, 0, 255};
          handState.setRGB(ledBlue);
          vTaskDelay(100);
          uint8_t ledClear[] = {0, 0, 0};
          handState.setRGB(ledClear);
          vTaskDelay(100);
        }
        uint8_t ledWhite[] = {255, 255, 255};
        handState.setRGB(ledWhite);
        
      } else {
        Serial.println("Connect: false");
        for (size_t i = 0; i < 2; i++)
        {
          uint8_t ledRed[] = {255, 0, 0};
          handState.setRGB(ledRed);
          vTaskDelay(100);
          uint8_t ledClear[] = {0, 0, 0};
          handState.setRGB(ledClear);
          vTaskDelay(100);
        }
        uint8_t ledWhite[] = {255, 255, 255};
        handState.setRGB(ledWhite);
      }
    }

    if (!central.connected) {
      uint8_t ledWhite[] = {255, 255, 255};
      handState.setRGB(ledWhite);
      vTaskDelay(50);
      uint8_t ledClear[] = {0, 0, 0};
      handState.setRGB(ledClear);
      vTaskDelay(50);
    }

    if (central.connected == false) {
      // Serial.println("scanning...");
      if (millis() - lastTimeScanBLE > TIME_SCAN) {
        central.scanBLE();
        lastTimeScanBLE = millis();
      }
    }

    if (peripheral.stateConnect == false) {
      if (millis() - lastTimeAdvBLE > TIME_ADV) {
        peripheral.startAdvertising();
        lastTimeAdvBLE = millis();
      }
      
    }
    vTaskDelay(100);
  }
}

void ControlOp(void* pParamter) {
  vTaskSuspend(NULL);
  for (;;) {
    handState.updateSensor(central.cSensor);
    handState.update();
    vTaskDelay(1);
  }
}

void setup() {
  Serial.begin(115200);
  delay(50);

  handState.begin();
  peripheral.begin(getSlaverAddr);
  getSlaverAddr();

  central.begin();
  lastTimeScanBLE = millis();
  lastTimeAdvBLE = millis();

  xTaskCreatePinnedToCore(BleMasterOp, "BleMasterOp", 7000, NULL, 1, &task_handle_ble_master, 0);
  xTaskCreatePinnedToCore(ControlOp, "ControlOp", 7000, NULL, 7, &task_handle_control, 1);
  Serial.println("Start");
}

void loop() {

  // if (Serial.available()) {
  //   char pchar = Serial.read();
  //   if (pchar == 'a' || pchar == 'b' || pchar == 'c' || pchar == 'd') {
  //     handState.updateSensor(pchar);
  //     Serial.printf("Received command: %c\n", pchar);
  //   } else {
  //     Serial.printf("Unknown command: %c\n", pchar);
  //   }
  // }
  
  // handState.update(); // Update hand state



  static hand_status_t lastHandStatus = STATE_NONE;
  hand_status_t handStatus = handState.getHandState();

  if (handStatus != lastHandStatus) {
    lastHandStatus = handStatus;
    Serial.printf("Change task: %d\n", handStatus);
    switch (handStatus) {
      case STATE_NORMAL:
        vTaskResume(task_handle_ble_master);
        vTaskResume(task_handle_control);
        break;
      case STATE_OTA:
          vTaskSuspend(task_handle_ble_master);
          vTaskSuspend(task_handle_control);
          BLEDevice::getScan()->stop();
        break;
      default:
        break;
    }
    delay(50);
  }
}
