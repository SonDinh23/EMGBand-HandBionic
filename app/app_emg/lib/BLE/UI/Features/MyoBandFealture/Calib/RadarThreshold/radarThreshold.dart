import 'dart:async';
import 'dart:convert';
import 'dart:developer' as dev;
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:app_emg/BLE/Helper/ConvertNum.dart';
import 'package:app_emg/BLE/Helper/ManageJson.dart';
import 'package:app_emg/BLE/Service/bleController.dart';
import 'package:app_emg/BLE/Service/myobandProcess.dart';
import 'package:app_emg/Utils/theme.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class RadarProfile {
  final int id; // id (map với FW nếu muốn)
  List<double> values; // 6 giá trị 0..40
  final Color color; // màu hiển thị
  bool visible; // dùng khi Show all

  RadarProfile({
    required this.id,
    required this.values,
    required this.color,
    this.visible = false,
  });
}

class RadarThreshold extends StatefulWidget {
  const RadarThreshold({super.key});

  @override
  State<RadarThreshold> createState() => _RadarThresholdState();
}

class _RadarThresholdState extends State<RadarThreshold> {
  // Ngưỡng nhận dạng giống FW
  static const double kAccuracy = 70.0;

  // điểm khớp cho từng profile (cùng chiều dài _profiles)
  late List<double> _scores; // 0..100
  int? _bestIdx; // index profile khớp nhất (>= kAccuracy)
  double _bestScore = 0; // % khớp tốt nhất

  BluetoothConnectionState? _connState; // null = chưa biết
  StreamSubscription<BluetoothConnectionState>? _connSub;
  bool _didStart = false;

  // grace window để tránh nháy disconnected khi vừa mở màn
  bool _inGrace = true;
  static const _graceMs = 500; // bạn đổi 700..1200 tùy thiết bị

  // ==== giống FW ====
  static const double kLimitMin = 0; // LIMITVALUEMIN
  static const double kLimitMax = 40; // LIMITVALUEMAX
  static const double kRadarMax = 1; // thang hiển thị

  // 6 giá trị mới nhất để vẽ radar
  final List<double> _radarVals = List<double>.filled(6, 0);

  // demo 4 mẫu; sau có thể thay bằng dữ liệu đọc từ FW
  final List<RadarProfile> _profiles = [
    RadarProfile(
      id: 0,
      values: [0.1, 0.12, 0.11, 0.09, 0.13, 0.10],
      color: Colors.deepPurpleAccent,
    ),
    RadarProfile(
      id: 1,
      values: [0.16, 0.15, 0.12, 0.14, 0.18, 0.17],
      color: Colors.greenAccent,
    ),
    RadarProfile(
      id: 2,
      values: [0.24, 0.22, 0.25, 0.23, 0.21, 0.24],
      color: Colors.blueAccent,
    ),
    RadarProfile(
      id: 3,
      values: [0.33, 0.31, 0.30, 0.28, 0.29, 0.32],
      color: Colors.redAccent,
    ),
  ];

  final List<String> _profileNames = ['Hold', 'Close', 'Open', 'Grip'];

  bool _showAll = false; // chế độ show all
  int? _activeProfile; // id mẫu đang chọn khi không show all

  // throttle: chỉ rebuild ~12fps cho mượt
  int _lastMs = 0;
  static const int _frameMs = 40;

  double _normToRadar(double v) {
    final t = ((v - kLimitMin) / (kLimitMax - kLimitMin));
    return t;
  }

  double _matchPercent(List<double> cur, List<double> templ) {
    double sum = 0;
    for (int i = 0; i < 6; i++) {
      final t = templ[i];
      final c = cur[i];

      if (t.abs() <= 1e-6) {
        // template ~0: khớp 100% nếu c cũng ~0, ngược lại 0%
        sum += (c.abs() <= 1e-6) ? 100.0 : 0.0;
      } else {
        final ratio = 1.0 - ((c - t).abs() / t.abs());
        sum += (ratio.clamp(0.0, 1.0)) * 100.0;
      }
    }
    return sum / 6.0; // % trung bình
  }

  void _updateScores() {
    _bestIdx = null;
    _bestScore = 0;
    for (int i = 0; i < _profiles.length; i++) {
      _scores[i] = _matchPercent(_radarVals, _profiles[i].values);
      if (_scores[i] >= kAccuracy && _scores[i] > _bestScore) {
        _bestScore = _scores[i];
        _bestIdx = i;
      }
    }
  }

  void _onEmg(List<double> floats) {
    if (floats.length < 6) return;
    for (int i = 0; i < 6; i++) {
      _radarVals[i] = _normToRadar(floats[i]);
    }
    _updateScores();
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastMs > _frameMs && mounted) {
      _lastMs = now;
      setState(() {}); // cập nhật chart
    }
  }

  @override
  void initState() {
    super.initState();
    _scores = List<double>.filled(_profiles.length, 0);
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
            await initData();
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
            await cancelData();
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
    cancelData();
    dev.log("RadarThreshold disposed");
  }

  Future<void> initData() async {
    dev.log("RadarThreshold initData called");
    await getThresholdRadar();
    await startSignal(BLEController.myoBandDevice);
    // Add any initialization logic here if needed
  }

  Future<void> cancelData() async {
    dev.log("RadarThreshold cancelData called");
    await stopSignal(BLEController.myoBandDevice);
    // Add any cancellation logic here if needed
  }

  Future<void> stopSignal(BluetoothDevice? myoBandDevice) async {
    MyobandProcess.notifySubSignal?.cancel();
    myoBandDevice?.isConnected == true
        ? MyobandProcess.settingChar!.setNotifyValue(false)
        : null;
    await ManageJson.writeJson(MyobandProcess.settingChar!, {
      "mode": "set",
      "type": "cmd",
      "val": {"type": "RMS", "state": 0},
    });
  }

  Future<void> startSignal(BluetoothDevice? myoBandDevice) async {
    await ManageJson.writeJson(MyobandProcess.settingChar!, {
      "mode": "set",
      "type": "cmd",
      "val": {"type": "RMS", "state": 1},
    });
    myoBandDevice?.isConnected == true
        ? await MyobandProcess.settingChar!.setNotifyValue(true)
        : null;

    MyobandProcess.notifySubSignal?.cancel();
    MyobandProcess.notifySubSignal = MyobandProcess.settingChar!.onValueReceived
        .listen((value) {
          if (value.isNotEmpty) {
            final floats = decodeHalfFloat(Uint8List.fromList(value));
            // dev.log('Received floats: $floats');
            _onEmg(floats);
            // onDataReceived(floats);
          }
        });
  }

  Future<void> getThresholdRadar() async {
    try {
      // Yêu cầu thiết bị gửi THS
      await ManageJson.writeJson(MyobandProcess.settingChar!, {
        "mode": "set",
        "type": "upd",
        "val": "THS",
      });
      await Future.delayed(const Duration(milliseconds: 100));
      // Đọc phản hồi 1 frame
      final bytes = await MyobandProcess.settingChar!.read();
      var s = utf8.decode(bytes, allowMalformed: true).trim();
      dev.log("THS raw: $s");

      applyTHSVectorsJson(s);

      // Không khớp trường hợp nào
      dev.log('Unrecognized THS format');
    } catch (e) {
      dev.log('getThresholdRadar error: $e');
    }
  }

  Future<void> setThresholdRadar(int id, List<num> chValues) async {
    // id: ví dụ 2
    // chValues: danh sách 6 giá trị (double), ví dụ [2.3, 2.3, 2.3, 2.3, 2.3, 2.3]
    if (chValues.length != 6) {
      throw ArgumentError('chValues must have length = 6');
    }

    // chuẩn hoá & format 1 chữ số thập phân (tuỳ bạn đổi)
    final thBody = chValues
        .map((e) => (e as num).toDouble().toStringAsFixed(4))
        .join(':');

    final thString = '$id@$thBody';

    await ManageJson.writeJson(MyobandProcess.settingChar!, {
      "mode": "set",
      "type": "cmd",
      "val": {"type": "THS", "TH": thString},
    });
  }

  /// Giải mã nguyên mảng bytes (List<int>) thành List<double>.
  List<double> decodeHalfFloat(Uint8List data) {
    final result = <double>[];
    final bd16 = ByteData.sublistView(data);

    for (int i = 0; i + 1 < data.length; i += 2) {
      final half = bd16.getUint16(i, Endian.little);
      result.add(Convertnum().halfToFloat(half));
    }

    return result;
  }

  void applyTHSVectorsJson(String jsonStr) {
    try {
      final obj = jsonDecode(jsonStr) as Map<String, dynamic>;
      if (obj['type'] != 'THS') return;

      final list = obj['val'];
      if (list is! List) return;

      setState(() {
        for (int i = 0; i < list.length && i < _profiles.length; i++) {
          final row = list[i];
          if (row is List && row.length >= 6) {
            _profiles[i].values = row
                .take(6)
                .map((e) => (e as num).toDouble())
                .toList();
          }
        }
      });
    } catch (_) {
      // ignore parse errors
    }
  }

  PreferredSizeWidget appBar() {
    return AppBar(
      backgroundColor: AppColors.primary,
      foregroundColor: AppColors.onPrimary,
      title: Text(
        "Radar Graph",
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

  Widget _buildRadarChart() {
    const labels = ['CH1', 'CH2', 'CH3', 'CH4', 'CH5', 'CH6'];

    final sets = <RadarDataSet>[
      // mồi scale 0..40 (kRadarMax)
      RadarDataSet(
        dataEntries: List.generate(
          6,
          (_) => const RadarEntry(value: kRadarMax),
        ),
        fillColor: Colors.transparent,
        borderColor: Colors.transparent,
        borderWidth: 0,
        entryRadius: 0,
      ),
    ];

    // overlay các profile đang visible
    for (final p in _profiles.where((e) => e.visible)) {
      sets.add(
        RadarDataSet(
          dataEntries: p.values.map((v) => RadarEntry(value: v)).toList(),
          fillColor: p.color.withOpacity(0.25),
          borderColor: p.color,
          borderWidth: 2,
          entryRadius: 2,
        ),
      );
    }

    // realtime (luôn trên cùng)
    sets.add(
      RadarDataSet(
        dataEntries: _radarVals.map((v) => RadarEntry(value: v)).toList(),
        fillColor: Colors.amber.withAlpha((255.0 * 0.25).round()),
        borderColor: Colors.amber,
        borderWidth: 2,
        entryRadius: 3,
      ),
    );

    return AspectRatio(
      aspectRatio: 1,
      child: RadarChart(
        RadarChartData(
          radarShape: RadarShape.polygon,
          tickCount: 6,
          gridBorderData: BorderSide(color: Colors.grey.shade400, width: 1.5),
          tickBorderData: BorderSide(color: Colors.grey.shade400, width: 1.5),
          radarBackgroundColor: Colors.transparent,
          radarBorderData: const BorderSide(color: Colors.blueGrey, width: 3),
          borderData: FlBorderData(show: false),
          ticksTextStyle: const TextStyle(
            color: Colors.transparent,
            fontSize: 1,
          ),
          titleTextStyle: const TextStyle(
            color: AppColors.onSurface,
            fontFamily: 'Quicksand',
            fontWeight: FontWeight.w900,
            fontStyle: FontStyle.normal,
            fontSize: 18,
          ),
          titlePositionPercentageOffset: 0.05,
          getTitle: (i, angle) =>
              RadarChartTitle(text: labels[i], angle: angle),
          dataSets: sets,
          radarTouchData: RadarTouchData(enabled: false),
        ),
        duration: const Duration(milliseconds: 80),
        curve: Curves.easeOutCubic,
      ),
    );
  }

  Widget _miniRadar(RadarProfile p, int idx, {double size = 70}) {
    final selected = p.visible;
    final percent = (idx < _scores.length ? _scores[idx] : 0).toStringAsFixed(
      0,
    );

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => setState(() => p.visible = !p.visible), // toggle
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              _profileNames[p.id],
              style: TextStyle(
                color: p.color,
                fontFamily: 'Quicksand',
                fontWeight: FontWeight.w800,
                fontStyle: FontStyle.normal,
                fontSize: 20,
              ),
            ),
          ),

          Container(
            width: size,
            height: size,
            margin: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: const [
                BoxShadow(color: Colors.black38, blurRadius: 6),
              ],
              border: Border.all(
                color: selected
                    ? p.color
                    : p.color.withAlpha((255.0 * 0.5).round()),
                width: selected ? 4 : 2,
              ),
            ),
            padding: const EdgeInsets.all(6),
            child: RadarChart(
              RadarChartData(
                radarShape: RadarShape.polygon,
                tickCount: 1,
                gridBorderData: const BorderSide(color: Colors.transparent),
                tickBorderData: BorderSide(color: Colors.transparent),
                radarBackgroundColor: Colors.transparent,
                radarBorderData: const BorderSide(color: Colors.transparent),
                borderData: FlBorderData(show: false),
                ticksTextStyle: const TextStyle(
                  color: Colors.transparent,
                  fontSize: 0,
                ),
                titleTextStyle: const TextStyle(
                  color: Colors.transparent,
                  fontSize: 0,
                ),
                dataSets: [
                  RadarDataSet(
                    dataEntries: List.generate(
                      6,
                      (_) => const RadarEntry(value: kRadarMax),
                    ),
                    fillColor: Colors.transparent,
                    borderColor: Colors.transparent,
                    borderWidth: 0,
                    entryRadius: 0,
                  ),
                  RadarDataSet(
                    dataEntries: p.values
                        .map((v) => RadarEntry(value: v))
                        .toList(),
                    fillColor: p.color.withAlpha((255.0 * 0.35).round()),
                    borderColor: p.color,
                    borderWidth: 2,
                    entryRadius: 0,
                  ),
                ],
                radarTouchData: RadarTouchData(enabled: false),
              ),
              duration: Duration.zero,
            ),
          ),

          const SizedBox(height: 4),

          // --- chỉ hiện % khi profile đang bật ---
          if (p.visible)
            Text(
              '$percent%',
              style: TextStyle(
                color: p.color,
                fontFamily: 'Quicksand',
                fontWeight: FontWeight.w800,
                fontStyle: FontStyle.normal,
                fontSize: 18,
              ),
            ),
        ],
      ),
    );
  }

  Widget _pillButton({
    required String text,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          text,
          style: TextStyle(
            color: AppColors.primary,
            fontFamily: 'Quicksand',
            fontWeight: FontWeight.w900,
            fontStyle: FontStyle.normal,
            fontSize: 19,
          ),
        ),
      ),
    );
  }

  Widget _matchBanner() {
    if (_bestIdx == null) return const SizedBox.shrink();
    final p = _profiles[_bestIdx!];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: p.color.withAlpha((255.0 * 0.90).round()),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        'Detected: G${p.id + 1} • ${_bestScore.toStringAsFixed(0)}%',
        style: const TextStyle(
          color: AppColors.onPrimary,
          fontFamily: 'Quicksand',
          fontWeight: FontWeight.w800,
          fontStyle: FontStyle.normal,
          fontSize: 16,
        ),
      ),
    );
  }

  Widget connectedMyoband() {
    return SizedBox(
      width: double.infinity,
      height: double.infinity,
      child: Column(
        children: [
          const SizedBox(height: 30),

          SizedBox(height: 300, child: _buildRadarChart()),
          const SizedBox(height: 30),

          _matchBanner(),
          const SizedBox(height: 20),

          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: _profiles
                  .asMap()
                  .entries
                  .map((e) => _miniRadar(e.value, e.key))
                  .toList(),
            ),
          ),
          const SizedBox(height: 20),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _pillButton(
                text: 'Save',
                color: Colors.orange,
                onTap: () async {
                  // chọn các profile đang bật
                  final selected = _profiles.where((p) => p.visible).toList();

                  // 1) cập nhật state đồng bộ
                  setState(() {
                    for (final p in selected) {
                      p.values = List<double>.from(_radarVals);
                    }
                  });

                  // 2) gửi xuống FW ngoài setState
                  // tuần tự
                  for (final p in selected) {
                    await setThresholdRadar(p.id, p.values);
                  }
                },
              ),
              _pillButton(
                text: _showAll ? 'Hide all' : 'Show all',
                color: Colors.orange,
                onTap: () {
                  setState(() {
                    _showAll = !_showAll;
                    if (_showAll) {
                      for (final p in _profiles) p.visible = true;
                    } else {
                      for (final p in _profiles) p.visible = false;
                    }
                  });
                },
              ),
            ],
          ),
        ],
      ),
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
