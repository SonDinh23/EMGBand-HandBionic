# 🚀 Firmware Stack

Two ESP32s, one bionic experience: the wearable EMG ring senses intent, and the hand controller turns it into motion. This guide focuses on how it works, the algorithms behind it, and why it survives real-world use.

## Topology
- Wearable EMG ring (ESP32-PICO): samples six EMG channels, filters/classifies intent, streams EMG or emits compact control states. See [firmware/Embedded/src/myoBand.cpp](firmware/Embedded/src/myoBand.cpp).
- Hand controller (ESP32-WROOM): scans/pairs to the ring, exposes services to the app, and drives five servos with current feedback. See [firmware/Embedded/src/handMain.cpp](firmware/Embedded/src/handMain.cpp).

## End-to-end flow
1) Ring: MCP3208 → filters → intent classifier in [firmware/Embedded/lib/Son_EMGSensor/EMGSensor.cpp](firmware/Embedded/lib/Son_EMGSensor/EMGSensor.cpp).
2) Ring BLE: advertises EMG, thresholds, mode, battery, and control state via [firmware/Embedded/lib/Son_BLERing/BLEEMGSensor.cpp](firmware/Embedded/lib/Son_BLERing/BLEEMGSensor.cpp) and [firmware/Embedded/lib/Son_BLERing/BLERingManager.cpp](firmware/Embedded/lib/Son_BLERing/BLERingManager.cpp).
3) Hand: acts as BLE central to the ring and peripheral to the app through [firmware/Embedded/lib/Son_BLEHand/BLEHandManager.cpp](firmware/Embedded/lib/Son_BLEHand/BLEHandManager.cpp) and [firmware/Embedded/lib/Son_BLEServiceManager/BLECentralManager.h](firmware/Embedded/lib/Son_BLEServiceManager/BLECentralManager.h).
4) Servo control: states (`open/hold/close/grip`) feed current-aware kinematics in [firmware/Embedded/lib/Son_HandState/HandState.cpp](firmware/Embedded/lib/Son_HandState/HandState.cpp).

## Core algorithms — EMG ring
- Sampling + filters: six MCP3208 channels → high-pass → low-pass smoothing → per-channel Kalman → aggregate magnitude [firmware/Embedded/lib/Son_EMGSensor/EMGSensor.cpp](firmware/Embedded/lib/Son_EMGSensor/EMGSensor.cpp).
- Control modes
	- LINE: sums channel magnitudes against four thresholds (setup/low/high/grip) to output `open/hold/close/grip` [firmware/Embedded/lib/Son_EMGSensor/EMGSensor.cpp](firmware/Embedded/lib/Son_EMGSensor/EMGSensor.cpp).
	- SPIDER: normalizes each channel to four grip templates, scores similarity, and picks the best above the accuracy bar [firmware/Embedded/lib/Son_EMGSensor/EMGSensor.cpp](firmware/Embedded/lib/Son_EMGSensor/EMGSensor.cpp).
- Safety envelope: `waitRelax()` enforces a quiet baseline; `isGetOnHand()` rejects saturated reads; over-activity forces hold and re-enters relax [firmware/Embedded/lib/Son_EMGSensor/EMGSensor.cpp](firmware/Embedded/lib/Son_EMGSensor/EMGSensor.cpp).
- Lean transport: half-precision packing (`converHaftFloat`) trims EMG frames for BLE; thresholds/mode/logic persist in NVS [firmware/Embedded/lib/Son_EMGSensor/EMGSensor.h](firmware/Embedded/lib/Son_EMGSensor/EMGSensor.h).

## Control algorithms — Hand controller
- Five servos, tailored pulse ranges, and dual INA3221 current sensing to halt motion when load thresholds trip—stall-safe by design [firmware/Embedded/lib/Son_HandState/HandState.cpp](firmware/Embedded/lib/Son_HandState/HandState.cpp).
- Modes `Open/Close/Hold/Change` map BLE states (`a/b/c/d`); grip cycling decides which fingers stay driven for each grasp style [firmware/Embedded/lib/Son_HandState/HandState.cpp](firmware/Embedded/lib/Son_HandState/HandState.cpp).
- Speed presets and RGB cues live in NVS; LEDs mirror connection and control state for instant field feedback [firmware/Embedded/lib/Son_HandState/HandState.cpp](firmware/Embedded/lib/Son_HandState/HandState.cpp).

## Tasking & real-time behavior
- EMG ring tasks [firmware/Embedded/src/myoBand.cpp](firmware/Embedded/src/myoBand.cpp):
	- `ReadSensorOP`: 1 kHz EMG sync + LED cue.
	- `ReadSensorBLEOP`: EMG BLE notify + periodic control state push.
	- `ModeOP`: battery notifications and control deltas.
	- `RingOP`: swaps advertising/streaming, respects OTA, manages sleep/wake.
- Hand controller tasks [firmware/Embedded/src/handMain.cpp](firmware/Embedded/src/handMain.cpp):
	- `BleMasterOp`: scan/connect to ring, blink status RGB.
	- `ControlOp`: 1 ms sensor/servo update loop.
	- Main loop: toggles OTA-safe state and suspends tasks when flashing.

## BLE + OTA
- Ring: EMG stream, thresholds, logic mode, battery, and control state; JSON writes set thresholds/mode; OTA-safe path baked in [firmware/Embedded/lib/Son_BLERing/BLEEMGSensor.cpp](firmware/Embedded/lib/Son_BLERing/BLEEMGSensor.cpp).
- Hand: publishes control/info to the app while central to the ring; OTA mode pauses control tasks to keep flash safe [firmware/Embedded/src/handMain.cpp](firmware/Embedded/src/handMain.cpp).

### JSON command/response shape
- Control channel speaks JSON strings over BLE characteristics. The `mode`/`type` fields gate actions; `val.type` selects payload (logic mode, line thresholds, spider templates, EMG control).
- Line thresholds: `THRESHOLD_LINE_JSON` carries four ints (setup/low/high/grip); spider templates: `THRESHOLD_SPIDER_JSON` parses `grip@f1:f2:f3:f4:f5:f6` into six floats per grip [firmware/Embedded/lib/Son_BLERing/BLEEMGSensor.cpp](firmware/Embedded/lib/Son_BLERing/BLEEMGSensor.cpp).
- Reads use `encode()` to serialize current settings; writes use `decode()`/`sendSetting()` to apply and persist to NVS, then optionally reboot when control mode changes.

### Binary efficiency (half-float packing)
- EMG frames are packed as IEEE 754 half-precision via `floatToHaft()` in [firmware/Embedded/lib/Son_Filter/Son_Utils.h](firmware/Embedded/lib/Son_Filter/Son_Utils.h) and sent as 12-byte notify (6 channels + timestamp) [firmware/Embedded/lib/Son_EMGSensor/EMGSensor.cpp](firmware/Embedded/lib/Son_EMGSensor/EMGSensor.cpp).
- On the receiver (app/hand), expand each 16-bit half to float32 to reconstruct magnitudes; control states remain single-byte to keep latency minimal.

### OTA discipline
- Both nodes reserve an OTA state: the hand’s main loop suspends BLE master and control tasks before flashing; the ring halts streaming/advertising when OTA is requested to protect flash writes.
- Keep MTU negotiated (517) before large transfers and avoid long-running callbacks during OTA; watchdog remains armed to recover from stalled uploads.

## Power, UX, and safety
- Ring: button-controlled deep sleep, charger guard, battery percent with low-batt tones/LED, mic/LED gating, WDT on critical loops [firmware/Embedded/src/myoBand.cpp](firmware/Embedded/src/myoBand.cpp).
- Hand: per-finger stall prevention via current sensing, RGB for connection/OTA, conservative servo steps to protect mechanics [firmware/Embedded/lib/Son_HandState/HandState.cpp](firmware/Embedded/lib/Son_HandState/HandState.cpp).

## Why this stack is strong
- Robust by design: enforced relax-before-use, over-activity clamp, stall-aware servos, watchdog-backed tasks.
- BLE-efficient: half-float frames, tuned MTU, tiny control states, dual-role topology (central + peripheral).
- Field-friendly: thresholds/modes/speeds live in NVS; LEDs/buzzer narrate state; OTA on both nodes keeps updates painless.
- Modular: EMG processing, BLE transport, hand kinematics, and alerts are isolated libraries—swap or tune without domino effects.

## Build & flash
- Uses PlatformIO (`platformio.ini` in `firmware/Embedded`). Typical flow: `pio run -t upload` from the `Embedded` folder, selecting the appropriate environment for ring vs hand.

## Quick file map
- Ring runtime: [firmware/Embedded/src/myoBand.cpp](firmware/Embedded/src/myoBand.cpp)
- EMG processing: [firmware/Embedded/lib/Son_EMGSensor/EMGSensor.cpp](firmware/Embedded/lib/Son_EMGSensor/EMGSensor.cpp)
- Ring BLE services: [firmware/Embedded/lib/Son_BLERing/BLEEMGSensor.cpp](firmware/Embedded/lib/Son_BLERing/BLEEMGSensor.cpp)
- Hand runtime: [firmware/Embedded/src/handMain.cpp](firmware/Embedded/src/handMain.cpp)
- Hand kinematics: [firmware/Embedded/lib/Son_HandState/HandState.cpp](firmware/Embedded/lib/Son_HandState/HandState.cpp)