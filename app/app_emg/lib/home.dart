import 'dart:developer';

import 'package:app_emg/BLE/UI/Features/MyoBandFealture/Calib/calib.dart';
import 'package:app_emg/BLE/UI/deviceUser.dart';
import 'package:app_emg/Utils/theme.dart';
import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  int currentIndex = 0;
  static const _iconPaths = [
    'assets/images/icons/home.svg',
    'assets/images/icons/calib.svg',
  ];

  Widget _iconItem(String path) => Padding(
    padding: const EdgeInsets.all(8),
    child: SvgPicture.asset(path, width: 25, height: 25),
  );

  @override
  Widget build(BuildContext context) {
    final itemIndex = _iconPaths.map(_iconItem).toList(growable: false);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: IndexedStack(
        index: currentIndex,
        children: [DeviceUser(), Calib()],
      ),
      bottomNavigationBar: CurvedNavigationBar(
        animationCurve: Curves.easeInOutCubic,
        animationDuration: const Duration(milliseconds: 400),
        backgroundColor: AppColors.background,
        color: AppColors.primary,
        buttonBackgroundColor: AppColors.primary,
        items: itemIndex,
        onTap: (value) {
          setState(() {
            currentIndex = value;
            // log("Current index: $currentIndex");
          });
        },
      ),
    );
  }
}
