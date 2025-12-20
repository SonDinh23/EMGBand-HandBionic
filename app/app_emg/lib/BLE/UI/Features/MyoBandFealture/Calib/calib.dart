import 'dart:developer';

import 'package:app_emg/BLE/Service/bleController.dart';
import 'package:app_emg/BLE/UI/Features/MyoBandFealture/Calib/LineThreshold/lineThreshold.dart';
import 'package:app_emg/BLE/UI/Features/MyoBandFealture/Calib/RadarThreshold/radarThreshold.dart';
import 'package:app_emg/Utils/theme.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class Calib extends StatefulWidget {
  const Calib({super.key});

  @override
  State<Calib> createState() => _CalibState();
}

class _CalibState extends State<Calib> {
  List<Widget> listFeatureCalib = [];

  void initData() {
    setState(() {
      listFeatureCalib.add(itemCalibLine());
      listFeatureCalib.add(itemCalibRadar());
      listFeatureCalib.add(itemCalibHealthy());
    });
  }

  @override
  void initState() {
    initData();
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Widget itemCalibLine() {
    return Card(
      elevation: 3,
      shadowColor: Colors.black,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(35),
        side: BorderSide(color: AppColors.outline, width: 2),
      ),
      child: Container(
        color: Colors.transparent,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Line",
                      style: const TextStyle(
                        color: AppColors.onSurface,
                        fontFamily: 'Quicksand',
                        fontWeight: FontWeight.w900,
                        fontStyle: FontStyle.normal,
                        fontSize: 38,
                      ),
                    ),
                    Text(
                      "Grap",
                      style: const TextStyle(
                        color: AppColors.onSurface,
                        fontFamily: 'Quicksand',
                        fontWeight: FontWeight.w700,
                        fontStyle: FontStyle.normal,
                        fontSize: 20,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              child: Image.asset('assets/images/calibrate/line.png'),
            ),
            InkWell(
              splashColor: AppColors.outline,
              borderRadius: BorderRadius.circular(20),
              onTap: () async {
                log("Calibrate Line Tapped");
                await Future.delayed(Duration(milliseconds: 200));
                if (BLEController.connectionStates['MyoBand'] ==
                    BluetoothConnectionState.disconnected) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: AppColors.red,
                      content: Text(
                        "Not connected to myoBand",
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
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => LineThreshold()),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(10),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: AppColors.onSurface,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.outline,
                        blurRadius: 14,
                        offset: Offset(0, 5),
                      ),
                    ],
                  ),
                  child: SizedBox(
                    width: 220,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(10.0),
                          child: Text(
                            "Calibration",
                            style: const TextStyle(
                              color: AppColors.onPrimary,
                              fontFamily: 'Livvic',
                              fontWeight: FontWeight.w600,
                              fontStyle: FontStyle.normal,
                              fontSize: 21,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: Icon(
                            Icons.arrow_forward_ios_rounded,
                            color: AppColors.onPrimary,
                            size: 18,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget itemCalibRadar() {
    return Card(
      elevation: 3,
      shadowColor: Colors.black,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(35),
        side: BorderSide(color: AppColors.outline, width: 2),
      ),
      child: Container(
        color: Colors.transparent,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Radar",
                      style: const TextStyle(
                        color: AppColors.onSurface,
                        fontFamily: 'Quicksand',
                        fontWeight: FontWeight.w900,
                        fontStyle: FontStyle.normal,
                        fontSize: 38,
                      ),
                    ),
                    Text(
                      "Grap",
                      style: const TextStyle(
                        color: AppColors.onSurface,
                        fontFamily: 'Quicksand',
                        fontWeight: FontWeight.w700,
                        fontStyle: FontStyle.normal,
                        fontSize: 20,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              child: Image.asset(
                'assets/images/calibrate/radar.png',
                scale: 1.4,
              ),
            ),
            InkWell(
              splashColor: AppColors.outline,
              borderRadius: BorderRadius.circular(20),
              onTap: () async {
                log("Calibrate Line Tapped");
                await Future.delayed(Duration(milliseconds: 200));
                if (BLEController.connectionStates['MyoBand'] ==
                    BluetoothConnectionState.disconnected) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: AppColors.red,
                      content: Text(
                        "Not connected to myoBand",
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
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => RadarThreshold()),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(10),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: AppColors.onSurface,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.outline,
                        blurRadius: 14,
                        offset: Offset(0, 5),
                      ),
                    ],
                  ),
                  child: SizedBox(
                    width: 220,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(10.0),
                          child: Text(
                            "Calibration",
                            style: const TextStyle(
                              color: AppColors.onPrimary,
                              fontFamily: 'Livvic',
                              fontWeight: FontWeight.w600,
                              fontStyle: FontStyle.normal,
                              fontSize: 21,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: Icon(
                            Icons.arrow_forward_ios_rounded,
                            color: AppColors.onPrimary,
                            size: 18,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget itemCalibHealthy() {
    return Card(
      elevation: 3,
      shadowColor: Colors.black,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(35),
        side: BorderSide(color: AppColors.outline, width: 2),
      ),
      child: Container(
        color: Colors.transparent,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Healthy",
                      style: const TextStyle(
                        color: AppColors.onSurface,
                        fontFamily: 'Quicksand',
                        fontWeight: FontWeight.w900,
                        fontStyle: FontStyle.normal,
                        fontSize: 38,
                      ),
                    ),
                    Text(
                      "Grap",
                      style: const TextStyle(
                        color: AppColors.onSurface,
                        fontFamily: 'Quicksand',
                        fontWeight: FontWeight.w700,
                        fontStyle: FontStyle.normal,
                        fontSize: 20,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              child: Image.asset('assets/images/calibrate/healthy.png'),
            ),
            InkWell(
              splashColor: AppColors.outline,
              borderRadius: BorderRadius.circular(20),
              onTap: () async {
                log("Calibrate Line Tapped");
                await Future.delayed(Duration(milliseconds: 200));
                // if (myobandConnectionState ==
                //     BluetoothConnectionState.disconnected) {
                //   ScaffoldMessenger.of(context).showSnackBar(
                //     SnackBar(
                //       backgroundColor: AppColors.red,
                //       content: Text(
                //         "Not connected to myoBand",
                //         style: const TextStyle(
                //           color: AppColors.white,
                //           fontFamily: 'Quicksand',
                //           fontWeight: FontWeight.w900,
                //           fontStyle: FontStyle.normal,
                //           fontSize: 18,
                //         ),
                //       ),
                //       duration: Duration(seconds: 1),
                //     ),
                //   );
                //   return;
                // }
                // Navigator.of(
                //   context,
                // ).push(MaterialPageRoute(builder: (context) => Line()));
              },
              child: Container(
                padding: const EdgeInsets.all(10),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: AppColors.onSurface,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.outline,
                        blurRadius: 14,
                        offset: Offset(0, 5),
                      ),
                    ],
                  ),
                  child: SizedBox(
                    width: 220,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(10.0),
                          child: Text(
                            "Calibration",
                            style: const TextStyle(
                              color: AppColors.onPrimary,
                              fontFamily: 'Livvic',
                              fontWeight: FontWeight.w600,
                              fontStyle: FontStyle.normal,
                              fontSize: 21,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: Icon(
                            Icons.arrow_forward_ios_rounded,
                            color: AppColors.onPrimary,
                            size: 18,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget appBar() {
    return AppBar(
      backgroundColor: AppColors.primary,
      foregroundColor: AppColors.onPrimary,
      title: Text(
        "Calibration",
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

  Widget titleCalibrate() {
    return Padding(
      padding: const EdgeInsets.only(left: 15, top: 20, bottom: 10),
      child: Align(
        alignment: Alignment.topLeft,
        child: Text(
          'Find your Calibration',
          style: const TextStyle(
            color: AppColors.onSurface,
            fontFamily: 'Quicksand',
            fontWeight: FontWeight.w900,
            fontStyle: FontStyle.normal,
            fontSize: 25,
          ),
        ),
      ),
    );
  }

  Widget contentCalibrate() {
    return Container(
      width: double.infinity,
      child: CarouselSlider(
        items: listFeatureCalib,
        options: CarouselOptions(
          aspectRatio: 0.75,
          viewportFraction: 0.80,
          initialPage: 0,
          enableInfiniteScroll: false,
          autoPlayInterval: Duration(seconds: 1),
          autoPlayAnimationDuration: Duration(milliseconds: 800),
          autoPlayCurve: Curves.fastOutSlowIn,
          enlargeCenterPage: true,
          enlargeFactor: 0.3,
          scrollDirection: Axis.horizontal,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: appBar(),
      body: Column(children: [titleCalibrate(), contentCalibrate()]),
    );
  }
}
