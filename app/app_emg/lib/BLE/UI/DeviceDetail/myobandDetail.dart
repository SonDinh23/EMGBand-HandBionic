import 'dart:async';
import 'dart:convert';
import 'dart:developer' as dev;

import 'package:app_emg/BLE/Helper/ManageJson.dart';
import 'package:app_emg/BLE/Service/bleController.dart';
import 'package:app_emg/BLE/Service/myobandProcess.dart';
import 'package:app_emg/Utils/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class MyobandDetail extends StatefulWidget {
  const MyobandDetail({super.key});

  @override
  State<MyobandDetail> createState() => _MyobandDetailState();
}

class _MyobandDetailState extends State<MyobandDetail> {
  BluetoothConnectionState? _connState; // null = chưa biết
  StreamSubscription<BluetoothConnectionState>? _connSub;
  bool _didStart = false;

  // grace window để tránh nháy disconnected khi vừa mở màn
  bool _inGrace = true;
  static const _graceMs = 500; // bạn đổi 700..1200 tùy thiết bị

  bool stateBtn = false;
  int emgCtrl = 0;

  @override
  void initState() {
    super.initState();
    // initData();
    // 2.1 Lấy trạng thái đã biết từ BLEController (last known, không đợi stream)
    final lastKnown = BLEController.connectionStates['MyoBand'];
    if (lastKnown != null) {
      _connState = lastKnown;
    }

    // 2.2 Mở grace window: trong ~900ms đầu, nếu chưa connected -> chỉ show loading
    Future.delayed(const Duration(milliseconds: _graceMs), () {
      if (!mounted) return;
      _inGrace = false;
      setState(() {}); // cập nhật UI sau khi hết grace
    });

    // 2.3 Bắt đầu theo dõi stream (distinct để bỏ trùng)
    final devc = BLEController.myoBandDevice;
    if (devc != null) {
      _connSub = devc.connectionState.distinct().listen((st) async {
        if (!mounted) return;
        final was = _connState;
        _connState = st;

        // lần đầu vào mà đã connected sẵn => start
        if (st == BluetoothConnectionState.connected && !_didStart) {
          _didStart = true;
          try {
            initData();
          } catch (e) {
            dev.log('start error: $e');
          }
        }

        // từ connected -> khác => stop
        if (was == BluetoothConnectionState.connected &&
            st != BluetoothConnectionState.connected &&
            _didStart) {
          _didStart = false;
          try {
            // await cancelData();
          } catch (_) {}
        }

        setState(() {}); // cập nhật UI theo state mới
      });
    }
    dev.log("LineThreshold initialized");
  }

  @override
  void dispose() {
    super.dispose();
    // cancelData();
    dev.log("LineThreshold disposed");
  }

  Future<void> initData() async {
    dev.log("LineThreshold initData called");
    await getStateEMGCtrl();
    // Add any initialization logic here if needed
  }

  Future<void> cancelData() async {
    dev.log("LineThreshold cancelData called");

    // Add any cancellation logic here if needed
  }

  Future<void> getStateEMGCtrl() async {
    await ManageJson.writeJson(MyobandProcess.settingChar!, {
      "mode": "set",
      "type": "upd",
      "val": "EMGCtrl",
    });
    final bytes = await MyobandProcess.settingChar!.read(); // List<int>
    final s = utf8.decode(bytes, allowMalformed: true); // -> String UTF-8
    dev.log("Threshold line (utf8): $s");
    final obj = jsonDecode(s) as Map<String, dynamic>;
    emgCtrl = (obj['val']['state'] as num).toInt();
    dev.log("EMGCtrl state: $emgCtrl");
    if (emgCtrl == 1) {
      stateBtn = true;
    } else {
      stateBtn = false;
    }
    setState(() {
      stateBtn = stateBtn;
      emgCtrl = emgCtrl;
    });
  }

  Future<void> setStateEMGCtrl(bool state) async {
    dev.log("Set EMGCtrl state: $state");
    final newEmgCtrl = state ? 1 : 2;

    // Kiểm tra kết nối trước khi ghi
    if (BLEController.myoBandDevice?.isConnected != true) {
      dev.log('MyoBand not connected, cannot set EMGCtrl');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.orange,
            content: Text(
              'MyoBand chưa kết nối. Vui lòng kết nối lại.',
              style: TextStyle(color: Colors.white),
            ),
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    // Lưu state cũ để khôi phục nếu lỗi
    final oldEmgCtrl = emgCtrl;
    final oldStateBtn = stateBtn;

    // Cập nhật UI ngay để người dùng thấy phản hồi
    setState(() {
      emgCtrl = newEmgCtrl;
      stateBtn = state;
    });

    try {
      await ManageJson.writeJson(MyobandProcess.settingChar!, {
        "mode": "set",
        "type": "cmd",
        "val": {"type": "EMGCtrl", "state": newEmgCtrl},
      });
      dev.log('setStateEMGCtrl success: $newEmgCtrl');
    } catch (e) {
      dev.log('setStateEMGCtrl error: $e');

      // Khôi phục state cũ
      if (mounted) {
        setState(() {
          emgCtrl = oldEmgCtrl;
          stateBtn = oldStateBtn;
        });

        // Kiểm tra nếu bị disconnect
        final isDisconnected =
            e.toString().contains('not connected') ||
            e.toString().contains('disconnected');

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red,
            content: Text(
              isDisconnected
                  ? 'Mất kết nối với MyoBand. Vui lòng kết nối lại.'
                  : 'Lỗi BLE. Vui lòng thử lại.',
              style: TextStyle(color: Colors.white),
            ),
            duration: Duration(seconds: 3),
          ),
        );

        // Nếu bị disconnect, quay về màn hình trước
        if (isDisconnected) {
          await Future.delayed(Duration(seconds: 1));
          if (mounted) {
            Navigator.of(context).pop();
          }
        }
      }
    }
  }

  PreferredSizeWidget appBar() {
    return AppBar(
      backgroundColor: AppColors.primary,
      foregroundColor: AppColors.onPrimary,
      title: Text(
        "MyoBand Detail",
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

  Widget connectedMyoband() {
    return Column(
      // mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Container(
          height: AppSizes.screen1_3_h,
          width: AppSizes.fullScreen_w / 1.5,
          padding: EdgeInsets.symmetric(vertical: 10.0, horizontal: 10.0),
          child: Card(
            elevation: 10,
            shadowColor: Colors.black,
            color: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Text(
                      "Control",
                      style: const TextStyle(
                        color: AppColors.onSurface,
                        fontFamily: 'Quicksand',
                        fontWeight: FontWeight.w900,
                        fontStyle: FontStyle.normal,
                        fontSize: 20,
                      ),
                    ),
                    SizedBox(width: 10.0),
                    Switch(
                      // This bool value toggles the switch.
                      value: stateBtn,
                      // activeColor: Colors.red,
                      activeThumbColor: Colors.yellow,
                      onChanged: (bool value) async {
                        // Gọi setStateEMGCtrl, nó sẽ tự cập nhật state khi thành công
                        await setStateEMGCtrl(value);
                      },
                    ),
                    SizedBox(width: 10.0),
                    Text(
                      emgCtrl == 1
                          ? "Line Algorithm"
                          : emgCtrl == 2
                          ? "Radar Algorithm"
                          : "Off",
                      style: const TextStyle(
                        color: AppColors.onSurface,
                        fontFamily: 'Quicksand',
                        fontWeight: FontWeight.w900,
                        fontStyle: FontStyle.normal,
                        fontSize: 20,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget disconnectedMyoband() {
    return Center(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              vertical: 50.0,
              horizontal: 20.0,
            ),
            child: Padding(
              padding: const EdgeInsets.only(top: 15.0),
              child: Text(
                "You do not have any MyoBand connected. Please connect a MyoBand.",
                style: const TextStyle(
                  color: AppColors.onSurface,
                  fontFamily: 'Quicksand',
                  fontWeight: FontWeight.w900,
                  fontStyle: FontStyle.normal,
                  fontSize: 18,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          Icon(
            Icons.bluetooth_connected,
            size: 200.0,
            color: AppColors.primaryContainer,
          ),
        ],
      ),
    );
  }

  Widget buildContent() {
    // Chưa biết state hoặc đang trong grace window mà chưa thấy connected -> Loading
    if (_connState == null ||
        (_inGrace && _connState != BluetoothConnectionState.connected)) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_connState == BluetoothConnectionState.connected) {
      return connectedMyoband();
    } else {
      return disconnectedMyoband();
    }
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
