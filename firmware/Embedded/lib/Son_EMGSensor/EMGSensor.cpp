#include "EMGSensor.h"

static float normalize(float value, float min, float max) {
    return (value - min) / (max - min);
}

static float max(float a, float b) {
	return a > b ? a : b;
}

EMGSensor::EMGSensor(MCP3208 &_adc, Adafruit_NeoPixel &_pixels, BuzzerMusic &_buzzer):
	adc(_adc),
	pixels(&_pixels),
	buzzer(&_buzzer) {
}

void EMGSensor::testSensor() {
	sensor[0] = adc.read(MCP3208::Channel::SINGLE_4);
	sensor[1] = adc.read(MCP3208::Channel::SINGLE_3);
	sensor[2] = adc.read(MCP3208::Channel::SINGLE_0);
	sensor[3] = adc.read(MCP3208::Channel::SINGLE_6);
	sensor[4] = adc.read(MCP3208::Channel::SINGLE_7);
	sensor[5] = adc.read(MCP3208::Channel::SINGLE_5);
	
	Serial.printf("Sensor: %d\t%d\t%d\t%d\t%d\t%d\n", sensor[0], sensor[1], sensor[2], sensor[3], sensor[4], sensor[5]);
	
}

bool EMGSensor::begin() {
	buzzer->playSound(play_startup);
	for (uint8_t i = 0; i < 8; i++) {
		ftHighSensor[i].inithighpass(0, 5, FS);
		ftLowSensor[i].initlowpass(0, 0.1, FS);
	}
	pref.begin("emgSensor", false);
    esp_task_wdt_reset();
	SPIFFS.begin(true);

	// Get state Control EMG
	emgControl = static_cast<EMG_Control>(pref.getUShort("emgControl", EMG_CONTROL_SPIDER));
    setEMGControl(emgControl);

	switch (emgControl) {
		case EMG_CONTROL_LINE:
			// Get threshold line 
			if (pref.getBytes("thresholdLine", thresholdLine, sizeof(thresholdLine))) {
				Serial.printf("ThresholdLine: %d, %d, %d, %d\n", thresholdLine[0], thresholdLine[1], thresholdLine[2], thresholdLine[3]);
				if (thresholdLine[0] == 0) {
					Serial.println("Calibration line is false.\nYou must be calibration again!!!");
					restoreThresholdLine();
				}
			} else restoreThresholdLine();
			break;

		case EMG_CONTROL_SPIDER:
			// Get threshold Spider
			if (pref.getBytes("thresholdSpider", thresholdSpider, sizeof(thresholdSpider))) {
				if (thresholdSpider[0][0] == 0) {
					Serial.println("Calibration spider is false.\nYou must be calibration again!!!");
					restoreThresholdSpider();
				}	
			} else restoreThresholdSpider();

			for (size_t grip = 0; grip < 4; grip++) {
				Serial.printf("Girp: %d\t", grip);
				for (size_t i = 0; i < CHANELS; i++) {
					Serial.printf("%.4f\t", thresholdSpider[grip][i]);
				}
				Serial.println();
			}
			break;
		
		default:
			break;
	}
	
	// Get mode Logic Control
    setModeLogicControl(pref.getUShort("modeLogic", 1));

	Serial.println("Setup Myo Band");
	return waitRelax(TIME_SETUP_SENSOR);
}

int8_t EMGSensor::sync(bool isStreamBLE) {
	if (!stateReady) return stateControl = 0;
	uint32_t nowTime = micros();
	if (nowTime - timeCycle < CYCLE) return stateControl;
	timeCycle = nowTime;
	readSensor();
	filterSensor();
	switch (emgControl) {
		case EMG_CONTROL_LINE:
			syncLine(isStreamBLE);
			break;
		
		case EMG_CONTROL_SPIDER:
			syncSpider(isStreamBLE);
			break;

		default:
			break;
	}
	return stateControl;
}

void EMGSensor::syncLine(bool isStreamBLE) {
	float output = data[0] + data[1] + data[2] + data[3] + data[4] + data[5];
	if (output > thresholdLine[3]) stateControl = gripControl;
	else if (output > thresholdLine[2]) stateControl = close;
	else if (output > thresholdLine[1]) stateControl = hold;
	else stateControl = open;

	if (isStreamBLE) {
		// memcpy((void*)buffer, (void*) data, SIZE_ONE_PACKET_REV);
		converHaftFloat();
	}else {
		if (	data[0] > THRESHOLD_MAX && data[1] > THRESHOLD_MAX && data[2] > THRESHOLD_MAX
			&& 	data[3] > THRESHOLD_MAX && data[4] > THRESHOLD_MAX && data[5] > THRESHOLD_MAX) {
			stateControl = hold;
			waitRelax();
		}
	}
}

void EMGSensor::syncSpider(bool isStreamBLE) {
	normalizeData();
	checkGrip();
	if (isStreamBLE) {
		converHaftFloat();
	}else {
		if (	data[0] > THRESHOLD_MAX && data[1] > THRESHOLD_MAX && data[2] > THRESHOLD_MAX
			&& 	data[3] > THRESHOLD_MAX && data[4] > THRESHOLD_MAX && data[5] > THRESHOLD_MAX) {
			stateControl = hold;
			waitRelax();
		}
	}
}

bool EMGSensor::waitSensor(uint16_t threshold, uint16_t waitTime) {
	static uint32_t _timeReady = millis();
	readSensor();
	filterSensor();
	// Serial.printf("%.2f\t%.2f\t%.2f\t%.2f\t%.2f\t%.2f\n", value[0], value[1], value[2], value[3], value[4], value[5]);
	// Serial.printf("%.2f\t%.2f\t%.2f\t%.2f\t%.2f\t%.2f\t", valueDC[0], valueDC[1], valueDC[2], valueDC[3], valueDC[4], valueDC[5]);
	// Serial.println();
	if ((data[0] < threshold) && (data[1] < threshold) && (data[2] < threshold)
		&& (data[3] < threshold) && (data[4] < threshold) && (data[5] < threshold)) {
		if (!stateWait) {
            _timeReady = millis();
            stateWait = true;
		}
		if (millis() - _timeReady > waitTime) return true;
		else return false;
	} else {
		stateWait = false;
		return false;
	}
}

bool EMGSensor::waitRelax(uint16_t maxTimeWait)  {
    stateReady = false;
	pixels->setPixelColor(0, pixels->Color(0, 0, 250));		//Setup Ring LED BLUE
	pixels->show();
	memset(sensor, 0, sizeof(sensor));
  	memset(value, 0, sizeof(value));
    memset(valueAbs, 0, sizeof(valueAbs));
  	memset(valueOut, 0, sizeof(valueOut));
  	memset(filterKalman, 0, sizeof(filterKalman));

    for (int i = 0; i < 5000; i++) {
		firstReadSensor();
		esp_task_wdt_reset();
	}
	Serial.println("Myoband wait get on Hand");

    while(!isGetOnHand()) {
		esp_task_wdt_reset();
	}
	Serial.println("Myoband on Setup");

    stateWait = false;
	static uint32_t lastTimeRelax = millis();
	while (!waitSensor(THRESHOLD_SETUP, TIME_READY)) {
		esp_task_wdt_reset();
		if (maxTimeWait > 0) if (millis() - lastTimeRelax > maxTimeWait) return false;
	}
 	Serial.println("myoban wait relax");
  	delay(200);
	Serial.println("MyoBand running");
  	delay(200);
	pixels->setPixelColor(0, pixels->Color(0, 255, 0));		//Ready Ring LED GREEN
	pixels->show();
	buzzer->playSound(play_melody);
	stateReady = true;
	return true;
}

void EMGSensor::firstReadSensor() {
	readSensor();
	filterSensor();
}

void EMGSensor::readSensor() {
	static uint32_t lastTimeCycle = micros();
	sensor[0] = adc.read(MCP3208::Channel::SINGLE_4);
	sensor[1] = adc.read(MCP3208::Channel::SINGLE_3);
	sensor[2] = adc.read(MCP3208::Channel::SINGLE_0);
	sensor[3] = adc.read(MCP3208::Channel::SINGLE_6);
	sensor[4] = adc.read(MCP3208::Channel::SINGLE_7);
	sensor[5] = adc.read(MCP3208::Channel::SINGLE_5);
	
	// Serial.printf("%d\t%d\t%d\t%d\t%d\t%d\n", sensor[0], sensor[1], sensor[2], sensor[3], sensor[4], sensor[5]);
	data[CHANELS] = micros() - lastTimeCycle;							//timeCycle
	lastTimeCycle = micros();
}

void EMGSensor::filterSensor() {
	for (uint8_t i = 0; i < CHANELS; i++) {
		valueAbs[i] = abs(ftHighSensor[i].highpass(sensor[i]));
		UTILS_LOW_PASS_FILTER_2(value[i], valueAbs[i], 0.005, 0.05);
	}
	data[0] = filter0.updateEstimate(value[0]);
	data[1] = filter1.updateEstimate(value[1]);
	data[2] = filter2.updateEstimate(value[2]);
	data[3] = filter3.updateEstimate(value[3]);
	data[4] = filter4.updateEstimate(value[4]);
	data[5] = filter5.updateEstimate(value[5]);
	// Serial.printf("%.2f\t%.2f\t%.2f\t%.2f\t%.2f\t%.2f\n", value[0], value[1], value[2], value[3], value[4], value[5]);
}

void EMGSensor::normalizeData() {
	for (size_t i = 0; i < CHANELS; i++) outputNormalize[i] = normalize(data[i], LIMITVALUEMIN, LIMITVALUEMAX);
}

void EMGSensor::checkGrip() {
	float errorGrip[4];

	for (size_t grip = 0; grip < 4; grip++) {
		float sum = 0;
		for (size_t CH = 0; CH < CHANELS; CH++) {
			float errorPerCH = max(0, (1 - abs(outputNormalize[CH] - thresholdSpider[grip][CH]) / thresholdSpider[grip][CH]))*100;
			sum += errorPerCH;
		}
		errorGrip[grip] = sum / CHANELS;
	}

	int index = -1;
	float maxValue = errorGrip[0];
	for (size_t grip = 0; grip < 4; grip++) {
		if (errorGrip[grip] >= ACCURACY && errorGrip[grip] > maxValue) {
			maxValue = errorGrip[grip];
			index = grip;
		}
	}

	switch (index) {
		case 0:
			stateControl = 0;
			break;
		case 1:
			stateControl = close;
			break;
		case 2:
			stateControl = open;
			break;
		case 3:
			stateControl = 2;
			break;
		default:
			float sumOutput = data[0] + data[1] + data[2] + data[3] + data[4] + data[5];
			if (sumOutput < THRESHOLD_SETUP) {
				stateControl = 0;
			}
			break;
	}
}

bool EMGSensor::isGetOnHand() {
	readSensor();
	filterSensor();
	if (	data[0] < THRESHOLD_MAX && data[1] < THRESHOLD_MAX && data[2] < THRESHOLD_MAX
		&& 	data[3] < THRESHOLD_MAX && data[4] < THRESHOLD_MAX && data[5] < THRESHOLD_MAX)
	return true;
	else return false;
}

void EMGSensor::converHaftFloat() {
	for (uint8_t i = 0; i < LENGTH_FRAME; i++) {
		uint16_t haftFloat = floatToHaft(data[i]);
		bufferNotify[i * 2] = haftFloat & 0xff;
		bufferNotify[i * 2 + 1] = haftFloat >> 8;
	}
}

void EMGSensor::setEMGControl(EMG_Control state) {
    Serial.printf("EMG control: %d\n", state);
    if (state == EMG_CONTROL_NONE) return;
    emgControl = state;
    pref.putUShort("emgControl", emgControl);
}

EMG_Control EMGSensor::getEMGControl() {
    return emgControl;
}

uint16_t *EMGSensor::getThresholdLine() {
    return thresholdLine;
}

void EMGSensor::setThresholdLine(uint16_t _threshold[]) {
    memcpy((void*)thresholdLine, (void*)_threshold, sizeof(thresholdLine));
	pref.putBytes("thresholdLine", thresholdLine, sizeof(thresholdLine));
}

void EMGSensor::restoreThresholdLine() {
    thresholdLine[0] = THRESHOLD_SETUP;
	thresholdLine[1] = THRESHOLD_LOW;
	thresholdLine[2] = THRESHOLD_HIGH;
    thresholdLine[3] = THRESHOLD_GRIP;
}

float *EMGSensor::getThresholdSpider() {
    return &thresholdSpider[0][0];
}

void EMGSensor::setThresholdSpider(uint32_t grip, float _threshold[]) {
    if (grip <= 3) memcpy((void*)thresholdSpider[grip], (void*)_threshold, sizeof(thresholdSpider[grip]));
	Serial.printf("Girp: %d\t", grip);
    for (size_t i = 0; i < CHANELS; i++) {
      Serial.printf("%.4f\t", thresholdSpider[grip][i]);
    }
    Serial.println();
	pref.putBytes("thresholdSpider", thresholdSpider, sizeof(thresholdSpider));
}

void EMGSensor::restoreThresholdSpider() {
    for (size_t grip = 0; grip < 4; grip++) {
		for (size_t CH = 0; CH < CHANELS; CH++) {
			thresholdSpider[grip][CH] = 1.0;
		}
	}
}

int8_t EMGSensor::getStateControl() {
    return stateControl;
}

void EMGSensor::setModeLogicControl(uint8_t _mode) {
    Serial.printf("Mode control: %d\n",_mode);
	if (_mode == 0) return;
	modeLogic = _mode;
	pref.putUShort("modeLogic", modeLogic);
	switch (_mode) {
		case 1:
			open = -1;
			close = 1;
			break;
		case 2: 
			open = 1;
			close = -1;
			break;
		default:
			break;
	}
}

uint8_t EMGSensor::getModeLogicControl() {
    return modeLogic;
}

void EMGSensor::setLed(uint8_t r, uint8_t g, uint8_t b) {
	pixels->setPixelColor(0, pixels->Color(r, g, b) );		//Setup Ring LED RED
	pixels->show();
}

void EMGSensor::notifyConfirm(bool isSuccess) {
	uint32_t cLed = isSuccess 
					? pixels->Color(0, 255, 0) 
					: pixels->Color(255, 0, 0);
									
	pixels->setPixelColor(0, cLed);		//Setup Ring LED RED
	pixels->show();
	delay(100);

	pixels->clear();
	pixels->show();
	delay(100);

	pixels->setPixelColor(0, cLed);		//Setup Ring LED RED
	pixels->show();
	delay(100);

	pixels->clear();
	pixels->show();
	delay(100);

	pixels->setPixelColor(0, pixels->Color(0, 255, 0));		//Setup Ring LED RED
	pixels->show();
}

bool EMGSensor::isReady() {
	return stateReady;
}


