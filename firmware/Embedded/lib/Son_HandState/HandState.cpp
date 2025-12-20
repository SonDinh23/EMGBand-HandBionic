#include "HandState.h"

HandState::HandState() {
}

void HandState::begin(void) {
    angleOpen = -1;
	angleClose = 1;

    if (!ina3221_1st.begin(ADDRESS_INA3221_1ST, &Wire)) {
        Serial.println("Failed to find ina3221 1st chip");
    }

    if (!ina3221_2nd.begin(ADDRESS_INA3221_2ND, &Wire)) {
        Serial.println("Failed to find ina3221 2nd 1st chip");
    }

    // Set shunt resistances for all channels to 0.1 ohms
    for (uint8_t i = 0; i < 3; i++) {
        ina3221_1st.setShuntResistance(i, 0.1);
        ina3221_2nd.setShuntResistance(i, 0.1);
    }

	ina3221_1st.setAveragingMode(INA3221_AVG_16_SAMPLES);
	ina3221_2nd.setAveragingMode(INA3221_AVG_16_SAMPLES);

	pref.begin("hand-info", false);

    ESP32PWM::allocateTimer(0);
  	ESP32PWM::allocateTimer(1);
  	ESP32PWM::allocateTimer(2);
  	ESP32PWM::allocateTimer(3);

	for (uint8_t i = 0; i < COUNT_SERVO; i++) {
		servoChannel[i].attach(pinServo[i],500,2500);
	}
	delay(50);
	
	// // set up servo channels
    // for (uint8_t i = 0; i < 5; i++) servoChannel[i].attach(pinServo[i]);
    // delay(500);

    // minAngle = pref.getUShort("minAngle", MIN_ANGLE_DEFAULT);
	// maxAngle = pref.getUShort("maxAngle", MAX_ANGLE_DEFAULT);

    // Serial.printf("MinAngle: %d\n", minAngle);
	// Serial.printf("MaxAngle: %d\n", maxAngle);

	// startAngle = (minAngle + maxAngle)/2;
    // angle = startAngle;
	// Serial.printf("startAngle: %d\n", startAngle);
	// for (uint8_t i = 0; i < 5; i++) servoChannel[i].write(angle);
    // pwmValueMin = map(minAngle, 0, 180, DEFAULT_uS_LOW, DEFAULT_uS_HIGH);
	// pwmValueMax = map(maxAngle, 0, 180, DEFAULT_uS_LOW, DEFAULT_uS_HIGH);
	// Serial.printf("pwmValueMin: %d\n", pwmValueMin);
	// Serial.printf("pwmValueMax: %d\n", pwmValueMax);

    readSpeed();

    pixels.begin();
	pixels.setBrightness(10);
	pixels.clear();
	pixels.show();
}

void HandState::onConnect() {
	isConnect = true;
	pixels.setPixelColor(1, pixels.Color(0, 0, 255));
	pixels.show();
}

void HandState::onDisconnect() {
	isConnect = false;
	pixels.setPixelColor(1, pixels.Color(255, 0, 0));
	pixels.show();
}

void HandState::setHandStatus(hand_status_t _status) {
	Serial.printf("setHandStatus: %d\n", _status);
	handStatus = _status;
}

void HandState::setSpeed(uint8_t _speed) {
	speed = _speed;
	switch (speed) {
		case 1:
			openSpeed = 0.75; 
			closeSpeed = 0.75;
			break;

		case 2:
			openSpeed = 1; 
			closeSpeed = 1;
			break;

		case 3:
			openSpeed = 1.25; 
			closeSpeed = 1.25;
			break;
		
		default:
			openSpeed = 0.75; 
			closeSpeed = 0.75;
			break;
	}

	pref.putUShort("speedAngle", speed);
	Serial.printf("SpeedAngle: %d\n",speed);
}

void HandState::setRGB(uint8_t rgbArray[]) {
	for (uint8_t i = 0; i < 3; i++) {
		RGB[i] = rgbArray[i];
	}
	pixels.setPixelColor(0, pixels.Color(RGB[0], RGB[1], RGB[2]));
	pixels.show();
	// Serial.printf("RGB: %d:%d:%d\n", RGB[0], RGB[1], RGB[2]);
}

hand_status_t HandState::getHandState() {
	return handStatus;
}

uint8_t HandState::getSpeedAngle() {
	return speed;
}

void  HandState::readSpeed() {
	speed = pref.getUShort("speedAngle", 1);
	Serial.printf("SpeedAngle: %d\n",speed);
	switch (speed) {
		case 1:
			openSpeed = 0.75; 
			closeSpeed = 0.75;
			break;

		case 2:
			openSpeed = 1; 
			closeSpeed = 1;
			break;

		case 3:
			openSpeed = 1.25; 
			closeSpeed = 1.25;
			break;
		
		default:
			openSpeed = 0.75; 
			closeSpeed = 0.75;
			break;
	}
}

void HandState::updateSensor(char pchar) {
	if (pchar == 'a')
	{
		lastMode = mode;
		mode = Open;
	}
	else if (pchar == 'b')
	{
		lastMode = mode;
		mode = Close;
	}
	else if (pchar == 'c')
	{
		lastMode = mode;
		mode = Hold;
	}
	else if (pchar == 'd')
	{
		lastMode = mode;
		mode = Change;
	}
}

void HandState::update() {
	detectMode();
	setServo();
}

void HandState::setServo() {
	int CurrentThumbver = ina3221_1st.getCurrentAmps(0)* 1000;
    int CurrentThumbhor = ina3221_1st.getCurrentAmps(1)* 1000;
    int CurrentIndex = ina3221_1st.getCurrentAmps(2)* 1000;
    int CurrentMid = ina3221_2nd.getCurrentAmps(0)* 1000;
    int CurrentRing = ina3221_2nd.getCurrentAmps(1)* 1000;
    // Serial.print(CurrentThumbver);
    // Serial.print(", ");
    // Serial.print(CurrentThumbhor);
    // Serial.print(", ");
    // Serial.print(CurrentIndex);
    // Serial.print(", ");
    // Serial.print(CurrentMid);
    // Serial.print(", ");
    // Serial.print(CurrentRing);
    Control_Finger(0,maxUs_Thumbver[grip], minUs_Thumbver, minStep_Count, maxStep_Count/2, CurrentThumbver);
    Control_Finger(1,maxUs_Thumbhor, minUs_Thumbhor, maxStep_Count/2, maxStep_Count, CurrentThumbhor);
    Control_Finger(2,maxUs_Index, minUs_Index, minStep_Count, maxStep_Count, CurrentIndex);
    Control_Finger(3,maxUs_Mid, minUs_Mid, minStep_Count, maxStep_Count, CurrentMid);
    Control_Finger(4,maxUs_Ring, minUs_Ring, minStep_Count, maxStep_Count, CurrentRing);
}

void HandState::detectMode() {
	if (Fingers[1].Flag_threshold && Fingers[2].Flag_threshold && Fingers[3].Flag_threshold && Fingers[4].Flag_threshold) mode = Hold;
	if (StepControl <= minStep_Count && flagChange)
	{
		grip = (grip + 1) % 3;
		if (grip == 0)
		{
			Fingers[3].Flag_stateGrip = Fingers[4].Flag_stateGrip = false;
		}
		else if (grip == 1)
		{
			Fingers[4].state = 3;
			Fingers[4].Flag_stateGrip = true;
		}
		else if (grip == 2)
		{
			Fingers[3].state = 3;
			Fingers[3].Flag_stateGrip = true;
		}
		flagChange = false;
	}
	
	switch (mode)
	{
	case Close:
		// Serial.println("Close:");
		if (StepControl < maxStep_Count)
			StepControl = StepControl + stepUs;
		// flag_ChangeGrip = true;
		break;
	case Open:
		// Serial.println("open:");
		if (StepControl > minStep_Count)
			StepControl = StepControl - stepUs;
		Fingers[1].Flag_threshold = Fingers[2].Flag_threshold = Fingers[3].Flag_threshold = Fingers[4].Flag_threshold = false;
		// flag_ChangeGrip = true;
		break;
	case Hold:
		// Serial.println("hold:");
		// flag_ChangeGrip = true;
		Fingers[1].Flag_threshold = Fingers[2].Flag_threshold = Fingers[3].Flag_threshold = Fingers[4].Flag_threshold = false;
		break;
	case Change:
		// Serial.println("Change Grip");
			flagChange = true;
			// flag_ChangeGrip = true;
			mode = lastMode;
			lastMode = Change;
		break;
	}	
}

void HandState::Control_Finger(int Finger,int max, int min, int min_IN, int max_IN,  int Current_sensor) {
  int StepControl_inFcn = constrain(StepControl, min_IN, max_IN);
  float AngleControl = mapFloat(StepControl_inFcn,min_IN,max_IN,min,max);
  switch(Fingers[Finger].state){
    case 0:
    Fingers[Finger].valueAngleCurrent = AngleControl;
    servoChannel[Finger].writeMicroseconds(Fingers[Finger].valueAngleCurrent);
    if( Current_sensor  <= Current_Threshold[stepUs-1][Finger]){
      Fingers[Finger].state = 1;
      Fingers[Finger].Flag_threshold = true;
    }
    break;
    case 1:
    if(Current_sensor <= Current_Threshold[stepUs-1][Finger] - 50){
      Fingers[Finger].valueAngleCurrent = Fingers[Finger].valueAngleCurrent <= min ? min : Fingers[Finger].valueAngleCurrent - stepUs;
      servoChannel[Finger].writeMicroseconds(Fingers[Finger].valueAngleCurrent);
    }
    else Fingers[Finger].state = 2;
    break;
    case 2:
    if(mode == Open && AngleControl <=  Fingers[Finger].valueAngleCurrent) Fingers[Finger].state = 0;
    else servoChannel[Finger].writeMicroseconds(Fingers[Finger].valueAngleCurrent);
    break;
    case 3:
    if(Fingers[Finger].Flag_stateGrip)
    {
        Fingers[Finger].valueAngleCurrent = Fingers[Finger].valueAngleCurrent >= max ? max : Fingers[Finger].valueAngleCurrent + stepUs;
    }
    else{
		if(Fingers[Finger].valueAngleCurrent <= AngleControl){
			Fingers[Finger].valueAngleCurrent = AngleControl;
			Fingers[Finger].state = 0;
			break;
		}
		Fingers[Finger].valueAngleCurrent = Fingers[Finger].valueAngleCurrent <= min ? min : Fingers[Finger].valueAngleCurrent - stepUs;
    }
    servoChannel[Finger].writeMicroseconds(Fingers[Finger].valueAngleCurrent);
    break;
  }
}
