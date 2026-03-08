// lib/utils/number_formatter.dart
import 'package:intl/intl.dart';

class NumberFormatter {

  // Hàm format số thông minh (Ví dụ: 1200 -> 1.2K, 1500000 -> 1.5M)
  static String format(int number) {
    if (number < 1000) {
      return number.toString();
    }
    else if (number < 1000000) {
      // Dưới 1 triệu: Hiển thị dạng K (VD: 1.5K, 230K)
      double result = number / 1000.0;
      return "${_removeTrailingZero(result)}K";
    }
    else if (number < 1000000000) {
      // Dưới 1 tỷ: Hiển thị dạng M (VD: 1.5M, 20M)
      double result = number / 1000000.0;
      return "${_removeTrailingZero(result)}M";
    }
    else {
      // Trên 1 tỷ: Hiển thị dạng B (VD: 1.2B)
      double result = number / 1000000000.0;
      return "${_removeTrailingZero(result)}B";
    }
  }

  // Hàm format đầy đủ có dấu phẩy (Ví dụ: 1,234,567)
  // Dùng khi muốn hiển thị chi tiết (VD: trong Admin hoặc Tooltip)
  static String formatFull(int number) {
    final formatter = NumberFormat("#,###");
    return formatter.format(number).replaceAll(',', '.'); // Đổi phẩy thành chấm cho giống VN
  }

  // Helper: Xóa số 0 thừa sau dấu phẩy (VD: 1.0 -> 1, 1.50 -> 1.5)
  static String _removeTrailingZero(double n) {
    String s = n.toStringAsFixed(1); // Lấy 1 số thập phân
    if (s.endsWith('.0')) {
      return s.substring(0, s.length - 2);
    }
    return s;
  }
}