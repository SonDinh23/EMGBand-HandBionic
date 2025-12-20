import 'dart:async';
import 'dart:developer' as dev;
import 'dart:math';

import 'package:app_emg/BLE/Service/bleService.dart';
import 'package:app_emg/Utils/SharedPreferences.dart';
import 'package:app_emg/Utils/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_svg/svg.dart';

class ScanDevice extends StatefulWidget {
  const ScanDevice({super.key});

  @override
  State<ScanDevice> createState() => _ScanDeviceState();
}

class _ScanDeviceState extends State<ScanDevice> {
  bool isScanning = false;
  StreamSubscription? listenScanResult;
  StreamSubscription? listenScanState;
  List<ScanResult> scanResults = [];
  List<Guid> serviceUUIDs = BLEService.listAdvUUID.map((e) => Guid(e)).toList();

  @override
  void initState() {
    super.initState();
    dev.log('in');
    stopScan();
  }

  @override
  void dispose() {
    super.dispose();
    dev.log('out');
    stopScan();
  }

  Future<void> startScan() async {
    listenScanState?.cancel();
    listenScanState = FlutterBluePlus.isScanning.listen((state) {
      setState(() {
        isScanning = state;
      });
    });

    listenScanResult?.cancel();
    listenScanResult = FlutterBluePlus.scanResults.listen((results) {
      setState(() {
        scanResults = results;
      });
    });

    dev.log('startScan');

    await FlutterBluePlus.startScan(
      withServices: serviceUUIDs,
      removeIfGone: Duration(seconds: 4),
      continuousUpdates: true,
      continuousDivisor: 2,
    );
  }

  Future<void> stopScan() async {
    listenScanState?.cancel();
    listenScanResult?.cancel();
    await FlutterBluePlus.stopScan();
    dev.log('stopScan');
  }

  Future<void> saveScanResult(ScanResult result) async {
    dev.log('Device: ${result.device.platformName}');
    dev.log('ID: ${result.device.remoteId}');
    dev.log('RSSI: ${result.rssi}');
    dev.log('uuids: ${result.advertisementData.serviceUuids}');
    if (result.advertisementData.serviceUuids.toString().contains(
      BLEService.advUUIDRing,
    )) {
      dev.log('MyoBand Service Detected');
      await DeviceStorage.clearMyoBand();
      await DeviceStorage.saveMyoBand(
        ScanItem(
          advName: result.device.platformName,
          id: result.device.remoteId.toString(),
          rssi: result.rssi,
          serviceUuids: result.advertisementData.serviceUuids.toString(),
        ),
      );
    } else if (result.advertisementData.serviceUuids.toString().contains(
      BLEService.advUUIDHand,
    )) {
      dev.log('Hand Service Detected');
      await DeviceStorage.clearHand();
      await DeviceStorage.saveHand(
        ScanItem(
          advName: result.device.platformName,
          id: result.device.remoteId.toString(),
          rssi: result.rssi,
          serviceUuids: result.advertisementData.serviceUuids.toString(),
        ),
      );
    }
  }

  Widget iconDeviceResult(ScanResult result) {
    return result.advertisementData.serviceUuids.contains(
          Guid(BLEService.advUUIDRing),
        )
        ? Container(
            padding: const EdgeInsets.all(20.0),
            child: SvgPicture.asset('assets/images/layouts/myoband.svg'),
          )
        : result.advertisementData.serviceUuids.contains(
            Guid(BLEService.advUUIDHand),
          )
        ? Container(
            padding: const EdgeInsets.all(10.0),
            child: SvgPicture.asset('assets/images/layouts/hand.svg'),
          )
        : SvgPicture.asset('assets/images/layouts/hand.svg');
  }

  PreferredSizeWidget appBar() {
    return AppBar(
      backgroundColor: AppColors.primary,
      foregroundColor: AppColors.onPrimary,
      title: Text(
        "Scan",
        style: const TextStyle(
          color: AppColors.onPrimary,
          fontFamily: 'Livvic',
          fontWeight: FontWeight.w700,
          fontStyle: FontStyle.normal,
          fontSize: 30,
        ),
      ),
      centerTitle: true,
      leading: IconButton(
        icon: Icon(Icons.arrow_back_ios_new_rounded),
        onPressed: () {
          Navigator.of(context).pop();
        },
      ),
    );
  }

  Widget buildTitle() {
    return Padding(
      padding: const EdgeInsets.only(top: 10.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          InkWell(
            splashColor: AppColors.outline,
            borderRadius: BorderRadius.circular(10.0),
            onTap: () {
              startScan();
            },
            child: Container(
              padding: EdgeInsets.all(10.0),
              child: Container(
                padding: const EdgeInsets.only(
                  left: 5.0,
                  right: 5.0,
                  top: 3.0,
                  bottom: 3.0,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer,
                  borderRadius: BorderRadius.circular(9),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.onSurfaceVariant,
                      spreadRadius: 0.5,
                      blurRadius: 3,
                      offset: Offset(2, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(5.0),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Icon(
                        Icons.scanner,
                        color: AppColors.onPrimaryContainer,
                        size: 20,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        'Start',
                        style: const TextStyle(
                          color: AppColors.onSurface,
                          fontFamily: 'Quicksand',
                          fontWeight: FontWeight.w900,
                          fontStyle: FontStyle.normal,
                          fontSize: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          InkWell(
            splashColor: AppColors.outline,
            borderRadius: BorderRadius.circular(10.0),
            onTap: () {
              stopScan();
              setState(() {
                isScanning = false;
              });
            },
            child: Container(
              padding: EdgeInsets.all(10.0),
              child: Container(
                padding: const EdgeInsets.only(
                  left: 5.0,
                  right: 5.0,
                  top: 3.0,
                  bottom: 3.0,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer,
                  borderRadius: BorderRadius.circular(9),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.onSurfaceVariant,
                      spreadRadius: 0.5,
                      blurRadius: 3,
                      offset: Offset(2, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(5.0),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Icon(
                        Icons.stop,
                        color: AppColors.onPrimaryContainer,
                        size: 20,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        'Stop',
                        style: const TextStyle(
                          color: AppColors.onSurface,
                          fontFamily: 'Quicksand',
                          fontWeight: FontWeight.w900,
                          fontStyle: FontStyle.normal,
                          fontSize: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildLinearProgressIndicator() {
    return isScanning
        ? Center(
            child: Container(
              height: 20,
              width: 320,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  backgroundColor: AppColors.tertiary,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppColors.onSecondary,
                  ),
                ),
              ),
            ),
          )
        : Container();
  }

  Widget buildDeviceList() {
    return Expanded(
      child: ListView.builder(
        itemCount: scanResults.length,
        itemBuilder: (context, index) {
          if (scanResults[index].advertisementData.advName.isEmpty)
            return SizedBox.shrink();
          var indexEnd = scanResults[index].advertisementData.advName.codeUnits
              .indexWhere((e) => e == 0);
          String advName = indexEnd != -1
              ? scanResults[index].advertisementData.advName.substring(
                  0,
                  indexEnd,
                )
              : scanResults[index].advertisementData.advName;
          return Padding(
            padding: const EdgeInsets.all(15.0),
            child: InkWell(
              onTap: () async {
                await saveScanResult(scanResults[index]);
                stopScan();
                Navigator.of(context).pop();
              },
              child: Card(
                elevation: 5,
                shadowColor: AppColors.onSurfaceVariant,
                color: AppColors.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Container(
                  height: 150,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(10.0),
                        child: Container(
                          width: 130,
                          height: 130,
                          decoration: BoxDecoration(
                            color: AppColors.primaryContainer,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: iconDeviceResult(scanResults[index]),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 20),
                        child: Column(
                          // mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(
                                top: 15,
                                bottom: 5,
                              ),
                              child: Text(
                                scanResults[index].device.platformName
                                    .substring(
                                      0,
                                      min(
                                        8,
                                        scanResults[index]
                                            .device
                                            .platformName
                                            .length,
                                      ),
                                    ),
                                style: const TextStyle(
                                  color: AppColors.onSurface,
                                  fontFamily: 'Quicksand',
                                  fontWeight: FontWeight.w900,
                                  fontStyle: FontStyle.normal,
                                  fontSize: 28,
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 30),
                              child: Text(
                                'ID: ${scanResults[index].device.remoteId.toString()}',
                                style: const TextStyle(
                                  color: AppColors.onSurfaceVariant,
                                  fontFamily: 'Quicksand',
                                  fontWeight: FontWeight.w700,
                                  fontStyle: FontStyle.italic,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(left: 80),
                              child: Row(
                                children: [
                                  Text(
                                    '${scanResults[index].rssi} dB',
                                    style: const TextStyle(
                                      color: AppColors.onSurface,
                                      fontFamily: 'Quicksand',
                                      fontWeight: FontWeight.w700,
                                      fontStyle: FontStyle.normal,
                                      fontSize: 15,
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.only(left: 5),
                                    child: Icon(
                                      Icons.signal_cellular_alt,
                                      color: scanResults[index].rssi > -70
                                          ? AppColors.success
                                          : AppColors.error,
                                      size: 20,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: appBar(),
      body: Column(
        children: [
          buildTitle(),
          buildLinearProgressIndicator(),
          buildDeviceList(),
        ],
      ),
    );
  }
}
