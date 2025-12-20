import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class BLEService {
  static const String advUUIDHand = "3492a42f-4316-4c23-89cc-973b5fcf5c21";
  static const String advUUIDRing = "911da4e1-586f-4d4e-a00f-154d84c3aacc";

  static List<String> listAdvUUID = [advUUIDHand, advUUIDRing];
  static List<String> listAdvUUIDMaster = [advUUIDHand];
  static List<String> listAdvUUIDRing = [advUUIDRing];

  static String macAddressUUID = 'FFFF';

  static Map<String, String> servicesHand = {
    "HAND_INFOR_SERVICE_UUID": "3492a42f-4316-4c23-89cc-973b5fcf5c21",
    "HAND_CONTROL_SERVICE_UUID": "9c8f199d-4a54-4b3f-907c-0c4399b6329d",
  };

  static Map<String, String> servicesRing = {
    "RING_SERVICE_UUID": "911da4e1-586f-4d4e-a00f-154d84c3aacc",
    "SENSOR_SERVICE_UUID": "30923486-dc89-4a2e-8397-f9db7fe03144",
  };

  static Map<String, String> characteristicsHand = {
    "OTA_UUID": "76095ead-54c4-4883-88a6-8297ba18211a",
    "INFORMATION_UUID": "8b8f9b38-9af4-11ee-b9d1-0242ac120002",
    "CONNECT_UUID": "f2c513b7-6b51-4363-b6aa-1ef8bd08c56a",
    "SETTING_UUID": "a8302363-d1fa-4f07-80b6-47e47248bbf6",
  };

  static Map<String, String> characteristicsRing = {
    "OTA_UUID": "149f93ef-7481-4536-8f75-50b5b55ab058",
    "INFORMATION_UUID": "514bd5a1-1ef9-49c8-b569-127a84896d25",
    "SETTING_UUID": "39b2df5b-b7d4-48c6-afd2-e0095d4a999c",
    "STATE_CONTROL_UUID": "22e5bbd9-62d8-45eb-9ffd-4a2b88cd6c3a",
    "BATTERY_UUID": "d23b3d36-e178-4528-af4d-7e8f9139aa20",
  };
}
