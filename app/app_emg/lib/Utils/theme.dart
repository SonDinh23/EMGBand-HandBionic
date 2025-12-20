import 'package:flutter/material.dart';

class AppSizes {
  static int splashScreenTitleFontSize = 48;
  static int titleFontSize = 34;
  static double sidePadding = 15;
  static double padding = 20;
  static double buttonRadius = 25;
  static double imageRadius = 8;
  static double linePadding = 4;
  static double widgetBorderRadius = 34;

  static double fullScreen_w = 500;
  static double halfScreen_w = fullScreen_w / 2;
  static double screen1_3_w = fullScreen_w / 3;
  static double screen1_4_w = fullScreen_w / 4;
  static double screen1_5_w = fullScreen_w / 5;
  static double screen2_3_w = fullScreen_w / 3 * 2;
  static double screen3_4_w = fullScreen_w / 4 * 3;
  static double screen4_5_w = fullScreen_w / 5 * 4;
  static double screen3_5_w = fullScreen_w / 5 * 3;
  static double screen2_5_w = fullScreen_w / 5 * 2;

  static double fullScreen_h = 500;
  static double halfScreen_h = fullScreen_h / 2;
  static double screen1_3_h = fullScreen_h / 3;
  static double screen1_4_h = fullScreen_h / 4;
  static double screen1_5_h = fullScreen_h / 5;
  static double screen2_3_h = fullScreen_h / 3 * 2;
  static double screen3_4_h = fullScreen_h / 4 * 3;
  static double screen4_5_h = fullScreen_h / 5 * 4;
  static double screen3_5_h = fullScreen_h / 5 * 3;
  static double screen2_5_h = fullScreen_h / 5 * 2;

  void setScreenSize(double width, double height) {
    print("setScreenSize");
    print("width: $width");
    print("height: $height");
    fullScreen_w = width;
    halfScreen_w = fullScreen_w / 2;
    screen1_3_w = fullScreen_w / 3;
    screen1_4_w = fullScreen_w / 4;
    screen1_5_w = fullScreen_w / 5;
    screen2_3_w = fullScreen_w / 3 * 2;
    screen3_4_w = fullScreen_w / 4 * 3;
    screen4_5_w = fullScreen_w / 5 * 4;
    screen3_5_w = fullScreen_w / 5 * 3;
    screen2_5_w = fullScreen_w / 5 * 2;

    fullScreen_h = height;
    halfScreen_h = fullScreen_h / 2;
    screen1_3_h = fullScreen_h / 3;
    screen1_4_h = fullScreen_h / 4;
    screen1_5_h = fullScreen_h / 5;
    screen2_3_h = fullScreen_h / 3 * 2;
    screen3_4_h = fullScreen_h / 4 * 3;
    screen4_5_h = fullScreen_h / 5 * 4;
    screen3_5_h = fullScreen_h / 5 * 3;
    screen2_5_h = fullScreen_h / 5 * 2;

    buttonRadius = screen1_5_w / 5;
    padding = screen1_5_w / 5;
    linePadding = padding / 2;
  }
}

// class AppColors {
//   static const blue = Color(0xFF9BE1DD);
//   static const black = Color(0xFF120F10);
//   static const orange = Color(0xFFFF9248);
//   static const amber = Color(0xFFFFECC2);
//   static const grey = Color(0xFFEBEBEB);
//   static const white = Colors.white;
//   static const red = Colors.redAccent;
//   static const green = Color.fromARGB(255, 111, 204, 114);
//   static const chartLine = Color(0xFF0A1F44);
// }

class AppColors {
  static const blue = Color(0xFF9BE1DD);
  static const black = Color(0xFF120F10);
  static const orange = Color(0xFFFF9248);
  static const amber = Color(0xFFFFECC2);
  static const grey = Color(0xFFEBEBEB);
  static const white = Colors.white;
  static const red = Colors.redAccent;
  static const green = Color.fromARGB(255, 111, 204, 114);
  static const chartLine = Color(0xFF0A1F44);

  static const success = Color(0xFF10B981);
  static const warning = Color(0xFFF59E0B);
  static const error = Color(0xFFEF4444);
  static const info = Color(0xFF3B82F6);
  static const brightness = Brightness.light;
  static const primary = Color(0xFF2BAFA9); // CTA / accent chính
  static const onPrimary = Colors.white;
  static const primaryContainer = Color(0xFF9BE1DD); // header/chip nhẹ
  static const onPrimaryContainer = Color(0xFF0F172A);
  static const secondary = Color(0xFFFFB47B);
  static const onSecondary = Color(0xFF1F2937);
  static const secondaryContainer = Color(0xFFFFE6D2);
  static const onSecondaryContainer = Color(0xFF1F2937);
  static const tertiary = Color(0xFF9BE1DD);
  static const onTertiary = Color(0xFF0F172A);
  static const tertiaryContainer = Color(0xFFE5F7F6);
  static const onTertiaryContainer = Color(0xFF0F172A);
  static const errorr = Color(0xFFEF4444);
  static const onError = Colors.white;
  static const background = Color(0xFFF5FAFA);
  static const onBackground = Color(0xFF0F172A);
  static const surface = Colors.white;
  static const onSurface = Color(0xFF0F172A);
  static const surfaceVariant = Color(0xFFF0F4F5);
  static const onSurfaceVariant = Color(0xFF475569);
  static const outline = Color(0xFFE6EEF0);
  static const shadow = Colors.black54;
  static const inverseSurface = Color(0xFF0B1220);
  static const onInverseSurface = Color(0xFFE5E7EB);
  static const inversePrimary = Color(0xFF36CFC9);
  static const scrim = Colors.black54;
}
