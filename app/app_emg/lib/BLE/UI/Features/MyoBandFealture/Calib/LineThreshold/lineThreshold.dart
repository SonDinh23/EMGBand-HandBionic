import 'dart:async';
import 'dart:collection';
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
import 'package:numberpicker/numberpicker.dart';

class LineThreshold extends StatefulWidget {
  const LineThreshold({super.key});

  @override
  State<LineThreshold> createState() => _LineThresholdState();
}

class _LineThresholdState extends State<LineThreshold> {
  BluetoothConnectionState? _connState; // null = chưa biết
  StreamSubscription<BluetoothConnectionState>? _connSub;
  bool _didStart = false;

  // grace window để tránh nháy disconnected khi vừa mở màn
  bool _inGrace = true;
  static const _graceMs = 500; // bạn đổi 700..1200 tùy thiết bị

  // BluetoothCharacteristic? settingChar;
  // StreamSubscription? notifySubSignal;

  bool isAdvanceChart = false;

  int _currentLowThreshold = 3;
  int _currentHighThreshold = 7;
  int _currentGripThreshold = 10;

  int maxPoints = 500;
  static const double _smoothingFactor = 0.2;
  static const Duration _chartUpdateInterval = Duration(milliseconds: 33);
  final List<double?> _lastSmoothedValues = List<double?>.filled(
    6,
    null,
    growable: false,
  );
  Timer? _chartRefreshTimer;

  // Trục X (tăng dần mỗi mẫu)
  int _tick = 0;

  // 6 kênh độc lập
  final ListQueue<FlSpot> ch1Spots = ListQueue();
  final ListQueue<FlSpot> ch2Spots = ListQueue();
  final ListQueue<FlSpot> ch3Spots = ListQueue();
  final ListQueue<FlSpot> ch4Spots = ListQueue();
  final ListQueue<FlSpot> ch5Spots = ListQueue();
  final ListQueue<FlSpot> ch6Spots = ListQueue();

  // Tổng 6 kênh
  final ListQueue<FlSpot> sumSpots = ListQueue();

  // Màu cho 6 kênh
  final List<Color> lineColors = const [
    Colors.red,
    Colors.green,
    Colors.yellow,
    Colors.blue,
    Colors.orange,
    Colors.purple,
  ];

  // ====== HẰNG & HELPER ======
  static const int kMin = 0;
  static const int kMax = 500;

  int _clamp(int v, int lo, int hi) => v < lo ? lo : (v > hi ? hi : v);

  void _resetSmoothing() {
    for (int i = 0; i < _lastSmoothedValues.length; i++) {
      _lastSmoothedValues[i] = null;
    }
    _cancelChartTimer();
  }

  double _smoothSample(double value, int index) {
    final prev = _lastSmoothedValues[index];
    final smoothed = prev == null
        ? value
        : prev + _smoothingFactor * (value - prev);
    _lastSmoothedValues[index] = smoothed;
    return smoothed;
  }

  void _cancelChartTimer() {
    _chartRefreshTimer?.cancel();
    _chartRefreshTimer = null;
  }

  void _scheduleChartRedraw() {
    if (_chartRefreshTimer?.isActive ?? false) return;
    _chartRefreshTimer = Timer(_chartUpdateInterval, () {
      _chartRefreshTimer = null;
      if (!mounted) return;
      setState(() {});
    });
  }

  // ====== RANGE AN TOÀN CHO MỖI PICKER ======
  int get lowMin => kMin;
  int get lowMax => (_currentHighThreshold - 1).clamp(kMin, kMax - 1);

  int get highMin => (_currentLowThreshold + 1).clamp(kMin + 1, kMax - 1);
  int get highMax => (_currentGripThreshold - 1).clamp(highMin, kMax - 1);

  int get gripMin => (_currentHighThreshold + 1).clamp(kMin + 2, kMax);
  int get gripMax => kMax;

  // ====== ONCHANGED – CLAMP & ĐỒNG BỘ ======
  void _onLowChanged(int v) {
    final newLow = _clamp(v, lowMin, lowMax);
    if (newLow == _currentLowThreshold) return;
    setState(() {
      _currentLowThreshold = newLow; // KHÔNG đụng high trừ khi bắt buộc
      if (_currentHighThreshold <= _currentLowThreshold) {
        _currentHighThreshold = _currentLowThreshold + 1;
      }
    });
  }

  void _onHighChanged(int v) {
    final newHigh = _clamp(v, highMin, highMax);
    if (newHigh == _currentHighThreshold) return;
    setState(() {
      _currentHighThreshold = newHigh;
      // đảm bảo low < high
      if (_currentLowThreshold >= _currentHighThreshold) {
        _currentLowThreshold = _currentHighThreshold - 1;
      }
    });
  }

  void _onGripChanged(int v) {
    final newGrip = _clamp(v, gripMin, gripMax);
    if (newGrip == _currentGripThreshold) return;
    setState(() {
      _currentGripThreshold = newGrip;
      // đảm bảo high < grip và low < high
      if (_currentHighThreshold >= _currentGripThreshold) {
        _currentHighThreshold = _currentGripThreshold - 1;
      }
      if (_currentLowThreshold >= _currentHighThreshold) {
        _currentLowThreshold = _currentHighThreshold - 1;
      }
    });
  }

  double _yMax() {
    final thMax = math.max(
      _currentGripThreshold.toDouble(),
      math.max(
        _currentHighThreshold.toDouble(),
        _currentLowThreshold.toDouble(),
      ),
    );

    double dataMax = 0;
    if (isAdvanceChart) {
      for (final list in [
        ch1Spots,
        ch2Spots,
        ch3Spots,
        ch4Spots,
        ch5Spots,
        ch6Spots,
      ]) {
        for (final s in list) {
          if (s.y > dataMax) dataMax = s.y;
        }
      }
    } else {
      for (final s in sumSpots) {
        if (s.y > dataMax) dataMax = s.y;
      }
    }

    final y = math.max(thMax, dataMax);
    return y <= 0 ? 1 : y * 1.1; // +10% cho thoáng
  }

  // tiện ích: push + cắt đuôi để giữ tối đa maxPoints
  void _push(ListQueue<FlSpot> queue, FlSpot spot) {
    queue.addLast(spot);
    if (queue.length > maxPoints) {
      queue.removeFirst();
    }
  }

  List<FlSpot> _spotList(ListQueue<FlSpot> queue) {
    if (queue.isEmpty) {
      return const <FlSpot>[];
    }
    return List<FlSpot>.unmodifiable(queue);
  }

  // ====== NHẬN DỮ LIỆU ======
  void onDataReceived(List<double> floats) {
    if (floats.length < 6) return;

    final double x = _tick.toDouble();
    _tick++;

    // áp dụng bộ lọc low-pass để đường biểu diễn mượt mà hơn
    final double ch1 = _smoothSample(floats[0], 0);
    final double ch2 = _smoothSample(floats[1], 1);
    final double ch3 = _smoothSample(floats[2], 2);
    final double ch4 = _smoothSample(floats[3], 3);
    final double ch5 = _smoothSample(floats[4], 4);
    final double ch6 = _smoothSample(floats[5], 5);

    final double sum = ch1 + ch2 + ch3 + ch4 + ch5 + ch6;

    _push(ch1Spots, FlSpot(x, ch1));
    _push(ch2Spots, FlSpot(x, ch2));
    _push(ch3Spots, FlSpot(x, ch3));
    _push(ch4Spots, FlSpot(x, ch4));
    _push(ch5Spots, FlSpot(x, ch5));
    _push(ch6Spots, FlSpot(x, ch6));

    _push(sumSpots, FlSpot(x, sum));

    _scheduleChartRedraw();
  }

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
    _connSub?.cancel();
    cancelData();
    _cancelChartTimer();
    super.dispose();
    dev.log("LineThreshold disposed");
  }

  Future<void> initData() async {
    dev.log("LineThreshold initData called");
    // await MyobandProcess.discovery(BLEController.myoBandDevice);
    await getThresholdLine();
    await startSignal(BLEController.myoBandDevice);
    // Add any initialization logic here if needed
  }

  Future<void> cancelData() async {
    dev.log("LineThreshold cancelData called");
    _resetSmoothing();
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
    _resetSmoothing();
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
            onDataReceived(floats);
          }
        });
  }

  Future<void> getThresholdLine() async {
    await ManageJson.writeJson(MyobandProcess.settingChar!, {
      "mode": "set",
      "type": "upd",
      "val": "THL",
    });
    final bytes = await MyobandProcess.settingChar!.read(); // List<int>
    final s = utf8.decode(bytes, allowMalformed: true); // -> String UTF-8
    dev.log("Threshold line (utf8): $s");
    final obj = jsonDecode(s) as Map<String, dynamic>;
    final inner = obj['val']; // { "type":"THL", "val":[...] }
    final list = inner['val']; // [50,10,20,30]
    if (list is! List) throw const FormatException('val.val is not a list');
    List<int> vals = list.map((e) => (e as num).toInt()).toList();
    dev.log(
      'vals=$vals setup=${vals[0]} low=${vals[1]} high=${vals[2]} grip=${vals[3]}',
    );
    setState(() {
      _currentLowThreshold = vals[1];
      _currentHighThreshold = vals[2];
      _currentGripThreshold = vals[3];
    });
  }

  Future<void> setThresholdLine(int low, int high, int grip) async {
    await ManageJson.writeJson(MyobandProcess.settingChar!, {
      "mode": "set",
      "type": "cmd",
      "val": {"type": "THL", "TH": "80:$low:$high:$grip"},
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

  PreferredSizeWidget appBar() {
    return AppBar(
      backgroundColor: AppColors.primary,
      foregroundColor: AppColors.onPrimary,
      title: Text(
        "Line Graph",
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

  // ====== CHART DATA ======
  LineChartData lineChartData() {
    final bars = <LineChartBarData>[
      LineChartBarData(
        spots: _spotList(ch1Spots),
        isCurved: true,
        color: lineColors[0],
        barWidth: 2,
        dotData: FlDotData(show: false),
      ),
      LineChartBarData(
        spots: _spotList(ch2Spots),
        isCurved: true,
        color: lineColors[1],
        barWidth: 2,
        dotData: FlDotData(show: false),
      ),
      LineChartBarData(
        spots: _spotList(ch3Spots),
        isCurved: true,
        color: lineColors[2],
        barWidth: 2,
        dotData: FlDotData(show: false),
      ),
      LineChartBarData(
        spots: _spotList(ch4Spots),
        isCurved: true,
        color: lineColors[3],
        barWidth: 2,
        dotData: FlDotData(show: false),
      ),
      LineChartBarData(
        spots: _spotList(ch5Spots),
        isCurved: true,
        color: lineColors[4],
        barWidth: 2,
        dotData: FlDotData(show: false),
      ),
      LineChartBarData(
        spots: _spotList(ch6Spots),
        isCurved: true,
        color: lineColors[5],
        barWidth: 2,
        dotData: FlDotData(show: false),
      ),
    ];

    return LineChartData(
      // Để FLChart tự fit theo dữ liệu; không cần ép minX nếu muốn “trượt”
      // minX: 0,
      minY: 0,

      maxY: isAdvanceChart ? null : _yMax(),
      borderData: FlBorderData(
        show: true,
        border: const Border(
          left: BorderSide(color: Colors.transparent),
          bottom: BorderSide(color: Colors.transparent),
          top: BorderSide(color: Colors.transparent),
          right: BorderSide(color: Colors.transparent),
        ),
      ),

      titlesData: FlTitlesData(
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        bottomTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 22,
            getTitlesWidget: (v, _) => Text(
              '${v.toInt()}',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
        ),
      ),

      gridData: const FlGridData(show: true, drawVerticalLine: false),

      extraLinesData: isAdvanceChart
          ? null
          : ExtraLinesData(
              horizontalLines: [
                HorizontalLine(
                  y: _currentLowThreshold.toDouble(),
                  color: Colors.green,
                  dashArray: [10, 5],
                  strokeWidth: 1,
                ),
                HorizontalLine(
                  y: _currentHighThreshold.toDouble(),
                  color: Colors.red,
                  dashArray: [10, 5],
                  strokeWidth: 1,
                ),
                HorizontalLine(
                  y: _currentGripThreshold.toDouble(),
                  color: Colors.orange,
                  dashArray: [10, 5],
                  strokeWidth: 1,
                ),
              ],
            ),

      // Hiển thị 6 kênh hoặc 1 kênh tổng tuỳ cờ isAdvanceChart
      lineBarsData: isAdvanceChart
          ? bars
          : [
              LineChartBarData(
                spots: _spotList(sumSpots),
                isCurved: true,
                color: Colors.white,
                barWidth: 2,
                dotData: FlDotData(show: false),
                belowBarData: BarAreaData(
                  show: true,
                  color: Colors.grey.withOpacity(0.8),
                ),
              ),
            ],
    );
  }

  Widget buildChart() {
    return Container(
      padding: const EdgeInsets.all(5),
      child: Card(
        elevation: 10,
        shadowColor: AppColors.black,
        color: AppColors.chartLine,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: SizedBox(
          height: 300,
          width: double.infinity,
          child: Padding(
            padding: const EdgeInsets.only(left: 20, top: 20, bottom: 20),
            child: LineChart(
              lineChartData(),
              duration: Duration.zero,
              curve: Curves.easeInOut,
            ),
          ),
        ),
      ),
    );
  }

  Widget buildLowThreshold() {
    return Card(
      elevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(40)),
      color: AppColors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Low',
              style: TextStyle(
                color: AppColors.green,
                fontFamily: 'Quicksand',
                fontStyle: FontStyle.normal,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            NumberPicker(
              key: ValueKey('low-${lowMin}-${lowMax}'),
              value: _currentLowThreshold,
              minValue: lowMin,
              maxValue: lowMax,
              step: 1,
              itemHeight: 48,
              itemWidth: 60,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
                border: Border.symmetric(
                  horizontal: BorderSide(color: AppColors.green, width: 3),
                ),
              ),
              textStyle: TextStyle(
                color: Colors.grey,
                fontSize: 15,
                fontFamily: 'Quicksand',
                fontWeight: FontWeight.w500,
              ),
              selectedTextStyle: TextStyle(
                color: AppColors.green,
                fontSize: 24,
                fontFamily: 'Quicksand',
                fontWeight: FontWeight.w900,
              ),
              // onChanged: (value) {
              //   setState(() => _currentLowThreshold = value);
              // },
              onChanged: _onLowChanged,
            ),
          ],
        ),
      ),
    );
  }

  Widget buildHighThreshold() {
    return Card(
      elevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(40)),
      color: AppColors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Close',
              style: TextStyle(
                color: AppColors.red,
                fontFamily: 'Quicksand',
                fontStyle: FontStyle.normal,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            NumberPicker(
              key: ValueKey('high-${highMin}-${highMax}'),
              value: _currentHighThreshold,
              minValue: highMin,
              maxValue: highMax,
              step: 1,
              itemHeight: 48,
              itemWidth: 60,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
                border: Border.symmetric(
                  horizontal: BorderSide(color: AppColors.red, width: 3),
                ),
              ),
              textStyle: TextStyle(
                color: Colors.grey,
                fontSize: 15,
                fontFamily: 'Quicksand',
                fontWeight: FontWeight.w500,
              ),
              selectedTextStyle: TextStyle(
                color: AppColors.red,
                fontSize: 24,
                fontFamily: 'Quicksand',
                fontWeight: FontWeight.w900,
              ),
              onChanged: _onHighChanged,
              // onChanged: (value) {
              //   setState(() => _currentHighThreshold = value);
              // },
            ),
          ],
        ),
      ),
    );
  }

  Widget buildGripThreshold() {
    return Card(
      elevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(40)),
      color: AppColors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Grip',
              style: TextStyle(
                color: AppColors.orange,
                fontFamily: 'Quicksand',
                fontStyle: FontStyle.normal,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            NumberPicker(
              key: ValueKey('grip-${gripMin}-${gripMax}'),
              value: _currentGripThreshold,
              minValue: gripMin,
              maxValue: gripMax,
              step: 1,
              itemHeight: 48,
              itemWidth: 60,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
                border: Border.symmetric(
                  horizontal: BorderSide(color: AppColors.orange, width: 3),
                ),
              ),
              textStyle: TextStyle(
                color: Colors.grey,
                fontSize: 15,
                fontFamily: 'Quicksand',
                fontWeight: FontWeight.w500,
              ),
              selectedTextStyle: TextStyle(
                color: AppColors.orange,
                fontSize: 24,
                fontFamily: 'Quicksand',
                fontWeight: FontWeight.w900,
              ),
              onChanged: _onGripChanged,
              // onChanged: (value) {
              //   setState(() => _currentGripThreshold = value);
              // },
            ),
          ],
        ),
      ),
    );
  }

  Widget buildThreshold() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        buildLowThreshold(),
        buildHighThreshold(),
        buildGripThreshold(),
      ],
    );
  }

  Widget buildControl() {
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          InkWell(
            splashColor: AppColors.grey,
            borderRadius: BorderRadius.circular(10),
            onTap: () async {
              dev.log("Advance button pressed");
              await Future.delayed(Duration(milliseconds: 200));
              setState(() {
                isAdvanceChart = !isAdvanceChart; // toggle advance chart
              });
            },
            child: Container(
              padding: const EdgeInsets.all(5),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.red,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.black.withOpacity(0.5),
                      spreadRadius: 2,
                      blurRadius: 7,
                      offset: Offset(0, 3), // changes position of shadow
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(
                        left: 8.0,
                        right: 5.0,
                        top: 10.0,
                        bottom: 10.0,
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(5.0),
                          child: Icon(
                            Icons.signal_cellular_alt,
                            color: AppColors.red,
                            size: 25,
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(
                        left: 3.0,
                        right: 10.0,
                        top: 10.0,
                        bottom: 10.0,
                      ),
                      child: Text(
                        isAdvanceChart ? ' Advance' : ' Basic ',
                        style: TextStyle(
                          color: AppColors.white,
                          fontSize: 20,
                          fontFamily: 'Quicksand',
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          isAdvanceChart == true
              ? SizedBox()
              : InkWell(
                  splashColor: AppColors.grey,
                  borderRadius: BorderRadius.circular(10),
                  onTap: () async {
                    await setThresholdLine(
                      _currentLowThreshold,
                      _currentHighThreshold,
                      _currentGripThreshold,
                    );
                    dev.log("Save threshold line");
                  },
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.green,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.black.withOpacity(0.5),
                            spreadRadius: 2,
                            blurRadius: 7,
                            offset: Offset(0, 3), // changes position of shadow
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(
                              left: 8.0,
                              right: 5.0,
                              top: 10.0,
                              bottom: 10.0,
                            ),
                            child: Container(
                              decoration: BoxDecoration(
                                color: AppColors.white,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(5.0),
                                child: Icon(
                                  Icons.save_alt_rounded,
                                  color: AppColors.green,
                                  size: 25,
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(
                              left: 3.0,
                              right: 10.0,
                              top: 10.0,
                              bottom: 10.0,
                            ),
                            child: Text(
                              ' Save ',
                              style: TextStyle(
                                color: AppColors.white,
                                fontSize: 20,
                                fontFamily: 'Quicksand',
                                fontWeight: FontWeight.w900,
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

  Widget connectedMyoband() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          buildChart(),
          SizedBox(height: 10),
          buildThreshold(),
          buildControl(),
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
