#ifndef HAND_STATE_H
#define HAND_STATE_H

#include <ESP32Servo.h>
#include <Adafruit_NeoPixel.h>
#include <Wire.h>
#include <Son_Utils.h>
#include <LinearRegression.h>
#include <Preferences.h>
#include "Adafruit_INA3221.h"

#define LED_PIN   					    4
#define LED_COUNT 					    2

#define SvoThumbverPin                  32
#define SvoThumbhorPin                  33
#define SvoIndexPin                     25
#define SvoMiddlePin                    26
#define SvoRingPin                      27

#define minUs_Thumbver                  1500     // Range Control of thumb finger
#define maxUs_Thumbver_Grip0            650
#define maxUs_Thumbver_Grip1            700
#define maxUs_Thumbver_Grip2            825

#define minUs_Thumbhor                  625    // Range Control of Little finger
#define maxUs_Thumbhor                  2500

#define minUs_Index                     625     // Range Control of Index finger
#define maxUs_Index                     2500

#define minUs_Mid                       625       // Range Control of Middle finger
#define maxUs_Mid                       2500

#define minUs_Ring                      700      // Range Control of Ring finger
#define maxUs_Ring                      2500

#define minStep_Count                   0     // general Step Control
#define maxStep_Count                   1500

#define ADDRESS_INA3221_1ST             0x40
#define ADDRESS_INA3221_2ND             0x41

#define COUNT_SERVO                      5

typedef enum {
  Close,
  Open,
  Hold,
  Change
}Mode;

typedef enum 
{
    THUMBVER = 0,
    THUMBHOR = 1,
    INDEX = 2,
    MIDDLE = 3,
    RING = 4
}FingerName;

typedef enum {
    SPEED_US_LV1 = 1,
    SPEED_US_LV2 = 2,
    SPEED_US_LV3 = 3,
    SPEED_US_LV4 = 4,
    SPEED_US_LV5 = 5,
}speedUS;
typedef enum {
	STATE_NONE 		= 0,
	STATE_NORMAL 	= 1,
	STATE_OTA 		= 2,
}hand_status_t;

const uint8_t pinServo[COUNT_SERVO] = {SvoThumbverPin, SvoThumbhorPin, SvoIndexPin, SvoMiddlePin, SvoRingPin}; // pin for servo

class HandState
{
	public:
        HandState();
        void begin(void);
        void updateSensor(char pchar);
        void update();

        void onConnect();
        void onDisconnect();

        void setHandStatus(hand_status_t _status);
        void setSpeed(uint8_t pSpeed);
        void setRGB(uint8_t rgbArray[]);

        hand_status_t getHandState();
        uint8_t getSpeedAngle();

    private:
        Preferences pref;

        Servo servoChannel[COUNT_SERVO];

        Adafruit_INA3221 ina3221_1st;
        Adafruit_INA3221 ina3221_2nd;

        Adafruit_NeoPixel pixels = Adafruit_NeoPixel(LED_COUNT, LED_PIN, NEO_GRB + NEO_KHZ800);

        void Control_Finger(int Finger,int max, int min, int min_IN, int max_IN,  int Current_sensor);
        typedef struct 
        {
            bool Flag_threshold = false;
            bool Flag_stateGrip = true;
            float valueAngleCurrent;
            uint8_t state = 0;
            uint8_t delayThreshold;
        }StateFinger;

        uint16_t StepControl = 0;
        speedUS stepUs = SPEED_US_LV3;
        uint8_t grip = 0;
        bool flagChange = false;
        // bool flag_ChangeGrip = true;
        int maxUs_Thumbver[3] = {maxUs_Thumbver_Grip0, maxUs_Thumbver_Grip1, maxUs_Thumbver_Grip2};
        int Current_Threshold[3][5] = {
            {-500, -200, -150, -200, -200},
            {-500, -300, -210, -300, -250},
            {-500, -320, -280, -350, -300}};

        Mode mode = Open;
        Mode lastMode = Hold;
        StateFinger Fingers[5];

        hand_status_t handStatus = STATE_NORMAL;

        byte txAddr[6];     // not use
		byte rxAddr[6];     //Sensor box address

        int8_t angleOpen = -1;								//gradually go to large angle
		int8_t angleClose = 1;								//gradually go to small angle

        uint8_t speed = 1;
		float openSpeed = 1.0;             		// multiply this per step
		float closeSpeed = 1.0;             	// multiply this per step 
		uint8_t startAngle = 90;

        uint8_t angle = startAngle;         	// when turn on, hand goes to this angle
		uint16_t minAngle = 80;            		// servo lower limit
		uint16_t maxAngle = 100;  
        
        float pwmValue;
        uint16_t pwmValueMin;
		uint16_t pwmValueMax;// servo upper limit

        uint8_t RGB[3] = {0};					
		bool isConnect = false;							//state BLE

        void setServo();

        void detectMode();

        void readSpeed();
};

#endif