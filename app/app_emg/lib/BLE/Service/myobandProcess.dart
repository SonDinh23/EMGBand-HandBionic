import 'dart:async';
import 'dart:developer' as dev;
import 'dart:typed_data';

import 'package:app_emg/BLE/Helper/ConvertNum.dart';
import 'package:app_emg/BLE/Helper/ManageJson.dart';
import 'package:app_emg/BLE/Service/bleService.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class MyobandProcess {
  static BluetoothCharacteristic? otaChar;
  static BluetoothCharacteristic? informationChar;

  static BluetoothCharacteristic? settingChar;
  static BluetoothCharacteristic? batteryChar;
  static BluetoothCharacteristic? controlChar;

  static StreamSubscription? notifySubSignal;

  static Future<void> discovery(BluetoothDevice? myoBandDevice) async {
    if (myoBandDevice == null) return;
    List<BluetoothService> services = await myoBandDevice!.discoverServices();
    for (var service in services) {
      dev.log('service uuid: ${service.serviceUuid}');
      for (var charc in service.characteristics) {
        dev.log('charc : ${charc.characteristicUuid}');
        if (charc.characteristicUuid.toString() ==
            BLEService.characteristicsRing['SETTING_UUID']) {
          settingChar = charc;
        }
      }
      dev.log('----------------');
    }
  }
}
