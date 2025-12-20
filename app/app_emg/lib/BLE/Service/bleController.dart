import 'dart:async';
import 'dart:developer' as dev;
import 'dart:ffi';
import 'package:app_emg/Utils/SharedPreferences.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

enum StateConnection {
  connected('Disconnect'),
  disconnected('Scan'),
  scanning('Scanning');

  const StateConnection(this.label);
  final String label;
}

class BLEController {
  static List<ScanItem?> dataSaved = List.filled(
    2,
    null,
    growable: false,
  ); // dataSaved[0] = Hand, dataSaved[1] = MyoBand

  static Map<String, bool> isScanning = {'Hand': false, 'MyoBand': false};

  static Map<String, BluetoothConnectionState> connectionStates = {
    'Hand': BluetoothConnectionState.disconnected,
    'MyoBand': BluetoothConnectionState.disconnected,
  };

  static BluetoothDevice? handDevice;
  static BluetoothDevice? myoBandDevice;

  static StreamSubscription? scanController;
  static StreamSubscription? handConnection;
  static StreamSubscription? myoBandConnection;

  static StateConnection stateConnection = StateConnection.disconnected;

  static Future<List<ScanItem?>> loadSavedDevices() async {
    dev.log('loadDeviceSaved');
    // List<ScanItem?> dataSaved = [];
    dataSaved[0] = await DeviceStorage.loadHand();
    dataSaved[1] = await DeviceStorage.loadMyoBand();
    dev.log('dataSaved: ${BLEController.dataSaved}');
    return BLEController.dataSaved;
  }

  static Future<void> deleteDevice(String device) async {
    dev.log('deleteDevice: $device');
    if (device == 'Hand') {
      await DeviceStorage.clearHand();
    } else if (device == 'MyoBand') {
      await DeviceStorage.clearMyoBand();
    }
  }
}
