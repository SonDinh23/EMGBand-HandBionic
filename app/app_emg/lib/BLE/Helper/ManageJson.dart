import 'dart:convert';
import 'dart:developer' as dev;

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class ManageJson {
  static Future<void> writeJson(
    BluetoothCharacteristic char,
    Map<String, dynamic> jsonMap, {
    Duration delay = const Duration(milliseconds: 100),
    int maxRetries = 3,
  }) async {
    final bytes = utf8.encode(jsonEncode(jsonMap));

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        // Delay trước khi ghi để tránh ghi quá nhanh
        if (attempt > 1) {
          await Future.delayed(Duration(milliseconds: 300 * attempt));
        }

        await char.write(bytes, timeout: 15);
        await Future.delayed(delay);
        dev.log('Wrote to ${char.characteristicUuid}: ${jsonEncode(jsonMap)}');
        return; // Thành công, thoát
      } catch (e) {
        final errorStr = e.toString();
        dev.log('Write attempt $attempt failed: $e');

        // Nếu thiết bị đã disconnect, không retry nữa
        if (errorStr.contains('not connected') ||
            errorStr.contains('disconnected') ||
            errorStr.contains('fbp-code: 6')) {
          dev.log('Device disconnected, stopping retry');
          rethrow;
        }

        if (attempt == maxRetries) {
          dev.log('All $maxRetries attempts failed, throwing error');
          rethrow;
        }

        // Chờ trước khi thử lại (chỉ cho lỗi GATT tạm thời)
        await Future.delayed(Duration(milliseconds: 500 * attempt));
      }
    }
  }
}
