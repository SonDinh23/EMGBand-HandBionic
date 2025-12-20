import 'dart:typed_data';

class Convertnum {
  /// Chuyển 1 half-float 16-bit sang 1 float32.
  double halfToFloat(int half) {
    final sign = (half & 0x8000) >> 15;
    var exp = (half & 0x7C00) >> 10;
    var mant = half & 0x03FF;

    int bits;
    if (exp == 0) {
      if (mant == 0) {
        // ±0
        bits = sign << 31;
      } else {
        // subnormal
        // normalize mantissa
        exp = 1;
        while ((mant & 0x0400) == 0) {
          mant <<= 1;
          exp -= 1;
        }
        mant &= 0x03FF;
        exp += (127 - 15);
        mant <<= 13;
        bits = (sign << 31) | (exp << 23) | mant;
      }
    } else if (exp == 0x1F) {
      // Inf or NaN
      bits = (sign << 31) | (0xFF << 23) | (mant << 13);
    } else {
      // normalized
      exp = exp + (127 - 15);
      mant <<= 13;
      bits = (sign << 31) | (exp << 23) | mant;
    }

    // reinterpret bits thành float32
    final bd = ByteData(4)..setUint32(0, bits, Endian.little);
    return bd.getFloat32(0, Endian.little);
  }
}
