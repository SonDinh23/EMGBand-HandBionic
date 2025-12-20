import 'dart:async';
import 'dart:developer' as dev;

import 'package:app_emg/BLE/Helper/pageOffBLE.dart';
import 'package:app_emg/BLE/Service/bleController.dart';
import 'package:app_emg/BLE/Service/myobandProcess.dart';
import 'package:app_emg/BLE/UI/DeviceDetail/myobandDetail.dart';
import 'package:app_emg/BLE/UI/scanDevice.dart';
import 'package:app_emg/Utils/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_svg/svg.dart';

class DeviceUser extends StatefulWidget {
  const DeviceUser({super.key});

  @override
  State<DeviceUser> createState() => _DeviceUserState();
}

class _DeviceUserState extends State<DeviceUser> {
  Timer? _scanTimeoutTimer;
  bool _myoBandDiscovered = false; // Cờ tránh discovery lặp lại
  bool _myoBandDiscoveryCompleted = false; // Cờ đánh dấu discovery hoàn thành

  @override
  void initState() {
    super.initState();
    _initDevices();
    dev.log('initState');
    FlutterBluePlus.setLogLevel(LogLevel.none);
  }

  Future<void> _initDevices() async {
    await BLEController.loadSavedDevices();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _scanTimeoutTimer?.cancel();
    BLEController.handConnection?.cancel();
    BLEController.myoBandConnection?.cancel();
    stopScan();
    super.dispose();
    dev.log('dispose');
  }

  Future<void> checkFullConnection() async {
    final handConnected =
        BLEController.connectionStates['Hand'] ==
        BluetoothConnectionState.connected;
    final myoBandConnected =
        BLEController.connectionStates['MyoBand'] ==
        BluetoothConnectionState.connected;

    // MyoBand vừa kết nối -> discovery ngay (chỉ 1 lần)
    if (myoBandConnected &&
        BLEController.myoBandDevice != null &&
        !_myoBandDiscovered) {
      _myoBandDiscovered = true;
      dev.log('MyoBand connected, discovering...');
      try {
        await Future.delayed(Duration(milliseconds: 800));
        await MyobandProcess.discovery(BLEController.myoBandDevice);
        dev.log('MyoBand discovery completed');
        // Đánh dấu discovery hoàn thành và tắt loading
        if (mounted) {
          setState(() {
            _myoBandDiscoveryCompleted = true;
            BLEController.isScanning['MyoBand'] = false;
          });
        }
      } catch (e) {
        dev.log('MyoBand discovery error: $e');
        _myoBandDiscovered = false; // Cho phép thử lại nếu lỗi
        if (mounted) {
          setState(() {
            BLEController.isScanning['MyoBand'] = false;
          });
        }
      }
    }

    // Cả 2 thiết bị đã kết nối
    if (handConnected && myoBandConnected) {
      dev.log('Both devices connected');
      _scanTimeoutTimer?.cancel();
      setState(() {
        BLEController.stateConnection = StateConnection.connected;
      });
      await FlutterBluePlus.stopScan();
      return;
    }

    // Hand vừa kết nối -> bắt đầu timeout cho thiết bị còn lại
    if (handConnected && !myoBandConnected) {
      dev.log('Hand connected, waiting for MyoBand...');
      _startScanTimeout('MyoBand');
    }

    // MyoBand kết nối nhưng Hand chưa -> bắt đầu timeout
    if (myoBandConnected && !handConnected) {
      _startScanTimeout('Hand');
    }

    // Cập nhật trạng thái nếu có ít nhất 1 thiết bị kết nối
    if (handConnected || myoBandConnected) {
      if (BLEController.stateConnection != StateConnection.connected) {
        setState(() {
          BLEController.stateConnection = StateConnection.scanning;
        });
      }
    } else {
      _myoBandDiscovered = false; // Reset cờ khi không có thiết bị nào kết nối
      setState(() {
        BLEController.stateConnection = StateConnection.disconnected;
      });
    }
  }

  void _startScanTimeout(String waitingFor) {
    // Nếu thiết bị còn lại không được lưu thì dừng scan luôn
    final savedIndex = waitingFor == 'Hand' ? 0 : 1;
    if (BLEController.dataSaved[savedIndex] == null) {
      dev.log('$waitingFor not saved, stopping scan');
      _finishScanWithPartialConnection();
      return;
    }

    // Hủy timer cũ nếu có
    _scanTimeoutTimer?.cancel();
    dev.log('Starting 10s timeout for $waitingFor');

    _scanTimeoutTimer = Timer(const Duration(seconds: 10), () {
      if (!mounted) return;
      final otherConnected = waitingFor == 'Hand'
          ? BLEController.connectionStates['Hand'] ==
                BluetoothConnectionState.connected
          : BLEController.connectionStates['MyoBand'] ==
                BluetoothConnectionState.connected;

      if (!otherConnected) {
        dev.log('Timeout: $waitingFor not found after 10s');
        _finishScanWithPartialConnection();
      }
    });
  }

  Future<void> _finishScanWithPartialConnection() async {
    await FlutterBluePlus.stopScan();
    BLEController.scanController?.cancel();

    setState(() {
      BLEController.isScanning['Hand'] = false;
      BLEController.isScanning['MyoBand'] = false;
      // Nếu có ít nhất 1 thiết bị kết nối thì đánh dấu connected
      final anyConnected =
          BLEController.connectionStates['Hand'] ==
              BluetoothConnectionState.connected ||
          BLEController.connectionStates['MyoBand'] ==
              BluetoothConnectionState.connected;
      BLEController.stateConnection = anyConnected
          ? StateConnection.connected
          : StateConnection.disconnected;
    });

    dev.log('Scan finished with partial connection');
  }

  Future<void> listenHandConnected(BluetoothDevice device) async {
    BLEController.handConnection?.cancel();
    BLEController.handConnection = device.connectionState.listen((state) async {
      dev.log('Device ${device.platformName} state: $state');
      setState(() {
        if (state == BluetoothConnectionState.connected) {
          BLEController.connectionStates['Hand'] =
              BluetoothConnectionState.connected;
          BLEController.isScanning['Hand'] = false;
        } else if (state == BluetoothConnectionState.disconnected) {
          BLEController.connectionStates['Hand'] =
              BluetoothConnectionState.disconnected;
        }
      });
      await checkFullConnection();
    });
  }

  Future<void> listenMyoBandConnected(BluetoothDevice device) async {
    BLEController.myoBandConnection?.cancel();
    BLEController.myoBandConnection = device.connectionState.listen((
      state,
    ) async {
      dev.log('Device ${device.platformName} state: $state');
      setState(() {
        if (state == BluetoothConnectionState.connected) {
          BLEController.connectionStates['MyoBand'] =
              BluetoothConnectionState.connected;
          // Không tắt isScanning ở đây, đợi discovery xong
        } else if (state == BluetoothConnectionState.disconnected) {
          BLEController.connectionStates['MyoBand'] =
              BluetoothConnectionState.disconnected;
          // Reset các cờ khi disconnect
          _myoBandDiscovered = false;
          _myoBandDiscoveryCompleted = false;
          BLEController.isScanning['MyoBand'] = false;
        }
      });
      await checkFullConnection();
    });
  }

  Future<void> connectToDevice(BluetoothDevice device) async {
    try {
      // log('Connected to ${device.platformName} (${device.remoteId})');
      // log('handConnected: ${handConnectionState.toString()}, myobandConnected: ${myobandConnectionState.toString()}');

      if (BLEController.connectionStates['MyoBand'] ==
          BluetoothConnectionState.disconnected) {
        if (device.remoteId.toString() == BLEController.dataSaved[1]?.id) {
          dev.log('MyoBand: connecting.....');
          await listenMyoBandConnected(device);
          BLEController.connectionStates['MyoBand'] =
              BluetoothConnectionState.connecting;
          await device.connect(mtu: 512, autoConnect: false);
        }
      }

      if (BLEController.connectionStates['Hand'] ==
          BluetoothConnectionState.disconnected) {
        if (device.remoteId.toString() == BLEController.dataSaved[0]?.id) {
          dev.log('Hand: connecting.....');
          await listenHandConnected(device);
          BLEController.connectionStates['Hand'] =
              BluetoothConnectionState.connecting;
          await device.connect(mtu: 512, autoConnect: false);
        }
      }

      if (BLEController.connectionStates['Hand'] ==
              BluetoothConnectionState.connected &&
          BLEController.connectionStates['MyoBand'] ==
              BluetoothConnectionState.connected) {
        // log('Both devices connected');
        BLEController.scanController?.cancel();
        BLEController.isScanning['Hand'] = false;
        BLEController.isScanning['MyoBand'] = false;
        await FlutterBluePlus.stopScan();
      }
    } catch (e) {
      dev.log('Error connecting to device: $e', name: 'BLE Connect');
    }
  }

  Future<void> startScan() async {
    // Check if the Bluetooth is connected
    if (BLEController.stateConnection == StateConnection.connected) {
      await Future.delayed(Duration(milliseconds: 200));
      if (BLEController.handDevice != null &&
          BLEController.connectionStates['Hand'] ==
              BluetoothConnectionState.connected) {
        dev.log('Hand device already connected');
        await BLEController.handDevice?.disconnect();
      } else {
        setState(() {
          BLEController.isScanning['Hand'] = false;
        });
      }

      if (BLEController.myoBandDevice != null &&
          BLEController.connectionStates['MyoBand'] ==
              BluetoothConnectionState.connected) {
        dev.log('Myoband device already connected');
        await BLEController.myoBandDevice?.disconnect();
      } else {
        setState(() {
          BLEController.isScanning['MyoBand'] = false;
        });
      }
      BLEController.stateConnection = StateConnection.disconnected;
      return;
    }

    if (BLEController.stateConnection == StateConnection.disconnected) {
      dev.log('Already scanning');
      if (BLEController.dataSaved[0] == null &&
          BLEController.dataSaved[1] == null) {
        dev.log('No devices saved to scan');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.red,
            content: Text(
              "No devices saved to scan",
              style: const TextStyle(
                color: AppColors.white,
                fontFamily: 'Quicksand',
                fontWeight: FontWeight.w900,
                fontStyle: FontStyle.normal,
                fontSize: 18,
              ),
            ),
            duration: Duration(seconds: 1),
          ),
        );
        return;
      }

      BLEController.scanController?.cancel();
      BLEController.scanController = FlutterBluePlus.scanResults.listen((
        event,
      ) async {
        if (event.isNotEmpty) {
          BluetoothDevice? tempHandDevice;
          BluetoothDevice? tempMyoBandDevice;
          for (final device in event) {
            if (device.device.remoteId.toString() ==
                BLEController.dataSaved[0]?.id) {
              // log('Hand device found: ${device.device.platformName}');
              tempHandDevice = device.device;
            }
            if (device.device.remoteId.toString() ==
                BLEController.dataSaved[1]?.id) {
              // log('MyoBand device found: ${device.device.platformName}');
              tempMyoBandDevice = device.device;
            }
          }
          if (tempHandDevice != null) {
            BLEController.handDevice = tempHandDevice;
            await connectToDevice(BLEController.handDevice!);
            return;
          }
          if (tempMyoBandDevice != null) {
            BLEController.myoBandDevice = tempMyoBandDevice;
            await connectToDevice(BLEController.myoBandDevice!);
            return;
          }
        }
      });

      await FlutterBluePlus.startScan(
        withRemoteIds: [
          if (BLEController.dataSaved[1] != null)
            BLEController.dataSaved[1]!.id,
          if (BLEController.dataSaved[0] != null)
            BLEController.dataSaved[0]!.id,
        ],
        removeIfGone: Duration(seconds: 4),
        continuousUpdates: true,
        continuousDivisor: 2,
      );

      setState(() {
        BLEController.stateConnection = StateConnection.scanning;
        BLEController.isScanning['Hand'] = true;
        BLEController.isScanning['MyoBand'] = true;
      });

      return;
    }

    if (BLEController.stateConnection == StateConnection.scanning) {
      dev.log('stop scanning');
      await stopScan();
      return;
    }
  }

  Future<void> stopScan() async {
    dev.log('stopScan');
    _scanTimeoutTimer?.cancel();
    _myoBandDiscovered = false; // Reset cờ khi dừng scan
    _myoBandDiscoveryCompleted = false;
    BLEController.scanController?.cancel();
    setState(() {
      BLEController.isScanning['Hand'] = false;
      BLEController.isScanning['MyoBand'] = false;
      BLEController.stateConnection = StateConnection.disconnected;
    });

    await FlutterBluePlus.stopScan();
  }

  Future<void> deleteDevice(String device) async {
    dev.log('Device: $device');
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.background,
        title: Text(
          'Confirm device delete',
          style: TextStyle(
            color: AppColors.onSurface,
            fontFamily: 'Quicksand',
            fontWeight: FontWeight.w700,
            fontStyle: FontStyle.normal,
            fontSize: 21,
          ),
        ),
        content: Text(
          'Are you sure you want to delete this device?',
          style: TextStyle(
            color: AppColors.onSurface,
            fontFamily: 'Quicksand',
            fontWeight: FontWeight.w400,
            fontStyle: FontStyle.normal,
            fontSize: 16,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'No',
              style: TextStyle(
                color: AppColors.secondary,
                fontFamily: 'Quicksand',
                fontWeight: FontWeight.w700,
                fontStyle: FontStyle.normal,
                fontSize: 15,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.surfaceVariant,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              'Yes',
              style: TextStyle(
                color: AppColors.secondary,
                fontFamily: 'Quicksand',
                fontWeight: FontWeight.w700,
                fontStyle: FontStyle.normal,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirm == true) {
      dev.log('User confirms device deleted');
      BLEController.deleteDevice(device);
      if (device == 'Hand') {
        BLEController.handDevice?.disconnect();
        setState(() {
          BLEController.handDevice = null;
          BLEController.connectionStates['Hand'] =
              BluetoothConnectionState.disconnected;
          BLEController.isScanning['Hand'] = false;
          BLEController.stateConnection = StateConnection.disconnected;
        });
      } else if (device == 'MyoBand') {
        BLEController.myoBandDevice?.disconnect();
        setState(() {
          BLEController.myoBandDevice = null;
          BLEController.connectionStates['MyoBand'] =
              BluetoothConnectionState.disconnected;
          BLEController.isScanning['MyoBand'] = false;
          BLEController.stateConnection = StateConnection.disconnected;
        });
      }
      BLEController.loadSavedDevices();
      setState(() {
        BLEController.dataSaved;
      });
    }
  }

  Widget buildTitle() {
    return Padding(
      padding: const EdgeInsets.only(top: 15.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 10.0),
            child: Text(
              'Devices',
              style: const TextStyle(
                color: AppColors.onSurface,
                fontFamily: 'Quicksand',
                fontWeight: FontWeight.w900,
                fontStyle: FontStyle.normal,
                fontSize: 22,
              ),
            ),
          ),
          InkWell(
            splashColor: AppColors.outline,
            borderRadius: BorderRadius.circular(1.0),
            onTap: () async => startScan(),
            child: Container(
              padding: const EdgeInsets.only(
                right: 15.0,
                left: 10.0,
                top: 10.0,
                bottom: 10.0,
              ),
              child: Container(
                padding: const EdgeInsets.all(5.0),
                decoration: BoxDecoration(
                  color: AppColors.onSurface,
                  borderRadius: BorderRadius.circular(9),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.outline,
                      spreadRadius: 0.5,
                      blurRadius: 3,
                      offset: Offset(2, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(5.0),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Icon(
                        Icons.link,
                        color: AppColors.onSurface,
                        size: 20,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 8.0),
                      child: Text(
                        // "test",
                        BLEController.stateConnection.label,
                        // stateConnection.label,
                        style: const TextStyle(
                          color: AppColors.onPrimary,
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

  Widget buildHandItem() {
    return InkWell(
      splashColor: AppColors.outline,
      borderRadius: BorderRadius.circular(20.0),
      onLongPress: () async => deleteDevice('Hand'),
      onTap: () async {
        await Future.delayed(Duration(milliseconds: 200));
        // if (handConnectionState == BluetoothConnectionState.connected) {
        //   await Navigator.of(
        //     context,
        //   ).push(MaterialPageRoute(builder: (context) => Hand()));
        // }
      },
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 10.0, horizontal: 10.0),
        child: Card(
          elevation: 10,
          shadowColor: Colors.black,
          color: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: SizedBox(
            height: 160,
            width: 320,
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.all(15.0),
                  child: SizedBox(
                    height: 150,
                    width: 130,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.primaryContainer,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: SvgPicture.asset(
                          'assets/images/layouts/hand.svg',
                        ),
                      ),
                    ),
                  ),
                ),
                Center(child: SizedBox(width: 5)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Hand",
                        style: const TextStyle(
                          color: AppColors.onSurface,
                          fontFamily: 'Quicksand',
                          fontWeight: FontWeight.w900,
                          fontStyle: FontStyle.normal,
                          fontSize: 30,
                        ),
                      ),
                      const SizedBox(height: 15),
                      Row(
                        children: [
                          Text(
                            "Status",
                            style: const TextStyle(
                              color: AppColors.onSurface,
                              fontFamily: 'Quicksand',
                              fontWeight: FontWeight.w800,
                              fontStyle: FontStyle.normal,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(width: 30),
                          BLEController.isScanning['Hand']! == true
                              ? CircularProgressIndicator(
                                  color: AppColors.blue,
                                  strokeWidth: 5.0,
                                )
                              : Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(9),
                                    color:
                                        BLEController
                                                .connectionStates['Hand'] ==
                                            BluetoothConnectionState.connected
                                        ? AppColors.green
                                        : AppColors.red,
                                  ),
                                  child: SizedBox(width: 20, height: 20),
                                ),
                        ],
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
  }

  Widget buildRingItem() {
    return InkWell(
      splashColor: AppColors.outline,
      borderRadius: BorderRadius.circular(20.0),
      onLongPress: () async => deleteDevice('MyoBand'),
      onTap: () async {
        await Future.delayed(Duration(milliseconds: 200));
        if (BLEController.connectionStates['MyoBand'] ==
            BluetoothConnectionState.connected) {
          await Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (context) => MyobandDetail()));
        }
      },
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 10.0, horizontal: 10.0),
        child: Card(
          elevation: 10,
          shadowColor: Colors.black,
          color: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: SizedBox(
            height: 160,
            width: 320,
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.all(15.0),
                  child: SizedBox(
                    height: 150,
                    width: 130,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.primaryContainer,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: SvgPicture.asset(
                          'assets/images/layouts/myoband.svg',
                        ),
                      ),
                    ),
                  ),
                ),
                Center(child: SizedBox(width: 5)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "MyoBand",
                        style: const TextStyle(
                          color: AppColors.onSurface,
                          fontFamily: 'Quicksand',
                          fontWeight: FontWeight.w900,
                          fontStyle: FontStyle.normal,
                          fontSize: 30,
                        ),
                      ),
                      const SizedBox(height: 15),
                      Row(
                        children: [
                          Text(
                            "Status",
                            style: const TextStyle(
                              color: AppColors.onSurface,
                              fontFamily: 'Quicksand',
                              fontWeight: FontWeight.w800,
                              fontStyle: FontStyle.normal,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(width: 30),
                          // Hiển thị loading khi đang scan HOẶC đang discovery
                          (BLEController.isScanning['MyoBand'] == true ||
                                  (BLEController.connectionStates['MyoBand'] ==
                                          BluetoothConnectionState.connected &&
                                      !_myoBandDiscoveryCompleted))
                              ? CircularProgressIndicator(
                                  color: AppColors.blue,
                                  strokeWidth: 5.0,
                                )
                              : Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(9),
                                    color:
                                        BLEController
                                                .connectionStates['MyoBand'] ==
                                            BluetoothConnectionState.connected
                                        ? AppColors.green
                                        : AppColors.red,
                                  ),
                                  child: SizedBox(width: 20, height: 20),
                                ),
                        ],
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
  }

  Widget buildDeviceList() {
    return Column(
      children: [
        BLEController.dataSaved[0] != null ? buildHandItem() : Container(),
        BLEController.dataSaved[1] != null ? buildRingItem() : Container(),
      ],
    );
  }

  Widget buildBtnScan() {
    return Padding(
      padding: const EdgeInsets.only(top: 50.0),
      child: InkWell(
        splashColor: AppColors.outline,
        borderRadius: BorderRadius.circular(10.0),
        onTap: () async {
          await Future.delayed(Duration(milliseconds: 200));
          await Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (context) => ScanDevice()));
          BLEController.loadSavedDevices();
          setState(() {
            BLEController.dataSaved;
          });
        },
        child: Container(
          padding: EdgeInsets.all(10.0),
          child: Container(
            width: 60,
            decoration: BoxDecoration(
              color: AppColors.inversePrimary,
              borderRadius: BorderRadius.circular(10.0),
              boxShadow: [
                BoxShadow(
                  color: AppColors.onSurfaceVariant,
                  spreadRadius: 0.5,
                  blurRadius: 3,
                  offset: Offset(2, 4),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.only(top: 5, bottom: 5),
              child: SvgPicture.asset('assets/images/icons/add.svg'),
            ),
          ),
        ),
      ),
    );
  }

  Widget buildBLEOnScreen() {
    return Container(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [buildTitle(), buildDeviceList(), buildBtnScan()],
      ),
    );
  }

  Widget buildContent() {
    return StreamBuilder<BluetoothAdapterState>(
      stream: FlutterBluePlus.adapterState,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Container(color: AppColors.white);
        }
        return Container(
          child: snapshot.data == BluetoothAdapterState.on
              ? buildBLEOnScreen()
              : const PageOffBLE(),
        );
      },
    );
  }

  PreferredSizeWidget appBar() {
    return AppBar(
      backgroundColor: AppColors.primary,
      foregroundColor: AppColors.onPrimary,
      title: Text(
        "Home",
        style: const TextStyle(
          color: AppColors.onPrimary,
          fontFamily: 'Livvic',
          fontWeight: FontWeight.w700,
          fontStyle: FontStyle.normal,
          fontSize: 30,
        ),
      ),
      centerTitle: true,
      actions: [
        IconButton(onPressed: () {}, icon: Icon(Icons.notifications_none)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: appBar(),
      body: buildContent(),
    );
  }
}
