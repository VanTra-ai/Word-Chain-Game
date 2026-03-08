// lib/utils/toast_helper.dart
import 'package:flutter/material.dart';

class ToastHelper {
  static void show(BuildContext context, String message, {bool isError = false}) {
    // Xóa snackbar cũ để hiện cái mới ngay
    ScaffoldMessenger.of(context).clearSnackBars();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
            ),
          ],
        ),
        // Màu nền: Đỏ (lỗi) hoặc Xanh (thành công)
        backgroundColor: isError ? Colors.redAccent : Colors.green,

        // Thời gian hiển thị
        duration: const Duration(seconds: 1),

        // Kiểu hiển thị nổi
        behavior: SnackBarBehavior.floating,

        // Vị trí: Cách đáy màn hình một khoảng (để không bị che bởi bàn phím)
        // Nếu muốn hiện ở trên cùng thì cần dùng thư viện khác hoặc Overlay,
        // nhưng SnackBar mặc định chỉ hỗ trợ bottom/floating.
        // Để "giả lập" hiện trên cùng, ta có thể set margin bottom rất lớn, nhưng rủi ro trên các màn hình khác nhau.
        // Tốt nhất là để floating phía trên bàn phím.
        margin: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 30, // Cách bàn phím 20px
          left: 20,
          right: 20,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}