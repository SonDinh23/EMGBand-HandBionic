#include <Arduino.h>
#include <esp_task_wdt.h>
#include <Adafruit_NeoPixel.h>
#include "esp_adc_cal.h"
#include "freertos/FreeRTOS.h"
#include "BLERingManager.h"
#include "EMGSensor.h"
#include "BuzzerMusic.h"

#define DEBUG
#define WDT_TIMEOUT   120

#define SPI_CS    	15 		   // SPI slave select
#define ADC_CLK     8000000  // SPI clock 1.6MHz

#define PIN_LDO_CE      27
#define PIN_BUTTON      35

#define PIN_CHARGER     34
#define PIN_STD_BAT     36
#define PIN_CHR_BAT     37
#define PIN_BAT         38

#define PIN_BITMASK     0x400000000 // 2^33 in hex

#define PIN_RGB           4
#define PIN_LED_EN        32

#define PIN_MIC_EN        5

#define TIME_WAKEUP   1500
#define BATTERY_MAX   4150
#define BATTERY_MIN   3200

TaskHandle_t task_handle_emg_signal;
TaskHandle_t task_handle_ble_emg_signal;
TaskHandle_t task_handle_ring;
TaskHandle_t task_handle_mode;

SPIClass spiMCP3208(HSPI);
MCP3208 adc(ADC_VREF, SPI_CS, &spiMCP3208);

Adafruit_NeoPixel pixels = Adafruit_NeoPixel(1, PIN_RGB, NEO_GRB + NEO_KHZ800);
BuzzerMusic buzzer;
EMGSensor emgSensor(adc, pixels, buzzer);
BLERingManager ble(emgSensor);

int8_t stateControl = 0;
uint8_t stateSensor = 0;
uint8_t mode = 0;
uint8_t connectedCountBLE = 0;
bool stateSleep = true;
bool isStreamBLE = false;

void deepSleep();
void onSleep(bool _stateSleep);
void onWakeUp();
void onPower();
void onCharger();
uint8_t getBattery();

void ReadSensorBLEOP(void* pParamter) {
  static int8_t lastStateControl = 0;
  static uint32_t lastTimeControl = millis();
  vTaskSuspend(NULL);
  for(;;) {
    ble.notifyData(1);
    if (millis() - lastTimeControl > 250) {
      ble.sendControl(stateControl);
      lastTimeControl = millis();
    }
    vTaskDelay(5);
  }
}

void ReadSensorOP(void* pParamter) {
  static uint32_t timePrint = millis();
  for(;;) {
    stateControl = emgSensor.sync(isStreamBLE);

    if (millis() - timePrint >= 250) {
      switch (stateControl) {
        case -1:
          emgSensor.setLed(0, 255, 0);
          break;

        case 1:
          emgSensor.setLed(0, 0, 255);
          break;

        case 2:
          emgSensor.setLed(255, 0, 0);
          break;

        default:
          emgSensor.setLed(0, 0, 0);
          break;
      }
      timePrint = millis();
    }
    vTaskDelay(1); 
  }
}

void ModeOP(void* pParamter) {
  int8_t lastState = 0;
  uint32_t lastTime = millis();
  vTaskSuspend(NULL);
  ble.notifyBatery(getBattery());
  for(;;) {
    int8_t _state = stateControl;
    if (lastState != _state) {
      ble.sendControl(_state);
      lastState = _state;
    }
    if (millis() - lastTime > 5000) {
      ble.notifyBatery(getBattery());
      lastTime = millis();
    }
    vTaskDelay(8);
  }
}

void RingOP(void* pParamter) {
  for(;;) {
    connectedCountBLE = ble.getCountDevice();
    // Serial.printf("connectedCountBLE %d\n", connectedCountBLE);
    if((connectedCountBLE !=0) && (!ble.isOnOTA())) {
      stateSensor = ble.getModeReadSensor();
      if (stateSensor == 1) {
        isStreamBLE = true;
        vTaskSuspend(task_handle_mode);
        vTaskResume(task_handle_emg_signal);
        vTaskResume(task_handle_ble_emg_signal);
      }else {
        isStreamBLE = false;
        vTaskSuspend(task_handle_ble_emg_signal);
        vTaskResume(task_handle_mode);
        vTaskResume(task_handle_emg_signal);
      }
      // Serial.println("use");
    }
    else {
      isStreamBLE = false;
      vTaskSuspend(task_handle_ble_emg_signal);
      vTaskSuspend(task_handle_mode);
      vTaskSuspend(task_handle_emg_signal);
      Serial.println("disconnect or update");
    }
    onPower();
    vTaskDelay(150);
  }
}

void setup() {
  Serial.begin(9600);
  delay(100);
  Serial.println("Myoband version 0.1");
  gpio_deep_sleep_hold_dis();

  pinMode(PIN_LED_EN, OUTPUT);
  digitalWrite(PIN_LED_EN, HIGH);
	pinMode(PIN_LDO_CE, OUTPUT);
	digitalWrite(PIN_LDO_CE, HIGH);

  pinMode(SPI_CS, OUTPUT);
  digitalWrite(SPI_CS, HIGH);

  pinMode(PIN_BUTTON, INPUT);
  pinMode(PIN_CHARGER, INPUT_PULLDOWN);
  pinMode(PIN_CHR_BAT, INPUT_PULLUP);
  pinMode(PIN_STD_BAT, INPUT_PULLUP);
  
  buzzer.begin();
  // buzzer.offBuzzer();

  pixels.begin();
  pixels.setBrightness(10);
	pixels.clear();
	pixels.show();

  Serial.printf("State sleep: %d\n", stateSleep);

  onWakeUp();

  SPISettings settings(ADC_CLK, MSBFIRST, SPI_MODE0);
  spiMCP3208.begin();
  spiMCP3208.beginTransaction(settings);

  esp_task_wdt_init(WDT_TIMEOUT, true);       //  enable panic so ESP32 restarts
  esp_task_wdt_add(NULL);                     //  add current thread to WDT watch

  stateSleep = !emgSensor.begin();
  onSleep(stateSleep);

  Serial.printf("Done %d\n",stateSleep);

  ble.begin();
  Serial.println();

  stateSleep = !ble.waitConnect(PIN_BUTTON, TIME_WAKEUP);
  onSleep(stateSleep);

  Serial.println("Start");
  xTaskCreatePinnedToCore(ReadSensorOP, "ReadSensorOP", 8000, NULL, 2, &task_handle_emg_signal, 1);
  xTaskCreatePinnedToCore(ReadSensorBLEOP, "ReadSensorBLEOP", 8000, NULL, 2, &task_handle_ble_emg_signal, 0);
  xTaskCreatePinnedToCore(ModeOP, "ModeOP", 8000, NULL, 1, &task_handle_mode, 0);
  xTaskCreatePinnedToCore(RingOP, "RingOP", 5000, NULL, 1, &task_handle_ring, 0);

}

void loop() {
  esp_task_wdt_reset();
  vTaskDelay(100);
}

void onWakeUp() {
  #ifndef DEBUG
    while (digitalRead(PIN_CHARGER)) {
      onCharger();
      delay(1000);
      esp_task_wdt_reset();
    }
  #endif

  uint32_t timeWakeUp = 0;
  if (!digitalRead(PIN_BUTTON)) {
    timeWakeUp = millis();
    buzzer.playSound(play_beep);
    vTaskDelay(100);
  }
  while (!digitalRead(PIN_BUTTON)) {
    esp_task_wdt_reset();
    if (millis() - timeWakeUp > TIME_WAKEUP) {
      stateSleep = !stateSleep;
      Serial.printf("State sleep: %d\n",stateSleep);
      pixels.setPixelColor(0, pixels.Color(255, 0, 0));
      pixels.show();
      while(!digitalRead(PIN_BUTTON)) {
        esp_task_wdt_reset();
        vTaskDelay(10);
      }
      buzzer.playSound(play_beep_long);
      vTaskDelay(100);
    }
  }
  onSleep(stateSleep);
}

void onSleep(bool _stateSleep) {
  if (!_stateSleep) return;
  Serial.println("On deep sleep");
  esp_task_wdt_reset();

  digitalWrite(PIN_LED_EN, HIGH);
  pixels.setPixelColor(0, pixels.Color(255, 0 , 0));
  pixels.show();
  vTaskDelay(250);
  pixels.clear();
  pixels.show();
  vTaskDelay(250);

  pixels.setPixelColor(0, pixels.Color(255, 0 , 0));
  pixels.show();
  buzzer.playSound(play_shutdown);
  vTaskDelay(250);
  pixels.clear();
  pixels.show();

  digitalWrite(PIN_LED_EN, LOW);
  digitalWrite(PIN_LDO_CE, LOW);
  buzzer.offBuzzer();

  gpio_deep_sleep_hold_en();  

  deepSleep();
}

void deepSleep() {
  // parameter Hibernate mode
  // esp_sleep_pd_config(ESP_PD_DOMAIN_RTC_PERIPH,   ESP_PD_OPTION_AUTO);
  // esp_sleep_pd_config(ESP_PD_DOMAIN_RTC_SLOW_MEM, ESP_PD_OPTION_OFF);
  // esp_sleep_pd_config(ESP_PD_DOMAIN_RTC_FAST_MEM, ESP_PD_OPTION_OFF);
  // esp_sleep_pd_config(ESP_PD_DOMAIN_XTAL,         ESP_PD_OPTION_OFF);

  // enable RCT_IO wakeup
  esp_sleep_enable_ext0_wakeup(GPIO_NUM_35, 0);

  #ifndef DEBUG
    esp_sleep_enable_ext1_wakeup(PIN_BITMASK, ESP_EXT1_WAKEUP_ANY_HIGH);
  #endif
  esp_task_wdt_delete(NULL);

  //start sleep
  esp_deep_sleep_start();
}

uint8_t getBattery() {
  static float Vin = analogReadMilliVolts(PIN_BAT) * 2;   //resistor voltage divider
  UTILS_LOW_PASS_FILTER(Vin, analogReadMilliVolts(PIN_BAT) * 2, 0.01);
  int16_t batteryPercent = (Vin - BATTERY_MIN) / (BATTERY_MAX - BATTERY_MIN) * 100;
  batteryPercent = constrain(batteryPercent, 0, 100);

  return batteryPercent;
}

void onCharger() {
  uint8_t batteryPercent = getBattery();

  Serial.print("Battery Percent");
  Serial.print("\t");
  Serial.println(batteryPercent);

  if (batteryPercent > 90)      pixels.setPixelColor(0, pixels.Color(0, 255, 0));
  else                          pixels.setPixelColor(0, pixels.Color(255, 0, 0));
  pixels.show();
}

void onPower() {
  #ifndef DEBUG
    if (digitalRead(PIN_CHARGER)) esp_cpu_reset(1);
  #endif

  uint32_t timeWakeUp = 0;
  if (!digitalRead(PIN_BUTTON)) {
    timeWakeUp = millis();
    buzzer.playSound(play_beep);
    vTaskDelay(100);
  }
  
  while (!digitalRead(PIN_BUTTON)) {
    if (millis() - timeWakeUp > TIME_WAKEUP) {
      stateSleep = !stateSleep;
      Serial.printf("State sleep: %d\n",stateSleep);
      pixels.setPixelColor(0, pixels.Color(255, 0, 0));
      pixels.show();
      while(!digitalRead(PIN_BUTTON)) {
        esp_task_wdt_reset();
        vTaskDelay(10);
      }
      buzzer.playSound(play_beep_long);
      vTaskDelay(100);
    }
    esp_task_wdt_reset();
  }

  if (!stateSleep) {
    switch (connectedCountBLE)
    {
    case 0:
      if (!emgSensor.isReady()) {
        stateSleep = true;
        onSleep(stateSleep);
      }
      ble.startAdvertising();
      stateSleep = !ble.waitConnect(PIN_BUTTON, TIME_WAKEUP);
      if (!stateSleep) {
        if(emgSensor.isReady()) {
          // pixels.setPixelColor(0, pixels.Color(0, 255, 0));
          // pixels.show();
        }
      }
      break;
    case 1: 
      ble.startAdvertising();
      break;
    
    default:
      ble.stopAdvertising();
      break;
    }
  }

  static uint32_t lastTimeBattery = millis();
  if (millis() - lastTimeBattery > 1000) {
    uint8_t batteryPersent = getBattery();
    if (batteryPersent < 15) {
      for (uint8_t i = 0; i < 3; i++) {
        pixels.setPixelColor(0, pixels.Color(255, 0, 0));
        pixels.show();
        buzzer.playSound(play_beep_short);
        vTaskDelay(200);

        pixels.clear();
        pixels.show();
        buzzer.playSound(play_beep_short);
        vTaskDelay(200);
      }
      if (batteryPersent < 5) {
        pixels.setPixelColor(0, pixels.Color(255, 0, 0));
        pixels.show();
        buzzer.playSound(play_warning);
        vTaskDelay(2000);
        stateSleep = true;
      }
    }   
    lastTimeBattery = millis();
  }

  onSleep(stateSleep);
}