// lib/widgets/daily_check_in_dialog.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart'; // Import AuthProvider
import '../constants/app_colors.dart';

class DailyCheckInDialog extends StatelessWidget {
  const DailyCheckInDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    // Lấy dữ liệu từ Provider
    int currentStreak = authProvider.checkInStreak;
    List<int> rewards = authProvider.dailyRewards;
    bool canClaim = authProvider.canCheckIn;

    // Giới hạn streak trong 7 ngày để tránh lỗi index
    int displayStreak = currentStreak >= 7 ? 6 : currentStreak;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20), // Tránh dính sát lề màn hình
      child: Stack(
        alignment: Alignment.topRight,
        children: [
          // 1. NỘI DUNG CHÍNH (Có Scroll để không bị lỗi màn hình nhỏ)
          Container(
            padding: const EdgeInsets.fromLTRB(20, 50, 20, 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.white, Colors.blue.shade50],
              ),
            ),
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.8, // Giới hạn chiều cao
            ),
            child: SingleChildScrollView( // Cho phép cuộn
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("📅 ĐIỂM DANH", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                  const SizedBox(height: 5),
                  const Text("Nhận vàng miễn phí mỗi ngày!", style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 20),

                  // Grid 7 ngày (Dùng Wrap thay vì GridView để không lỗi layout)
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    alignment: WrapAlignment.center,
                    children: List.generate(7, (index) {
                      int day = index + 1;
                      // An toàn mảng: Nếu index vượt quá rewards, lấy phần tử cuối
                      int reward = (index < rewards.length) ? rewards[index] : rewards.last;

                      bool isPast = index < displayStreak;
                      bool isToday = index == displayStreak;

                      // Màu sắc
                      Color bgColor = Colors.white;
                      Color borderColor = Colors.grey.shade300;
                      if (isPast) bgColor = Colors.grey.shade200;
                      if (isToday && canClaim) {
                        bgColor = Colors.orange.shade50;
                        borderColor = Colors.orange;
                      }

                      return Container(
                        width: 80,
                        height: 90,
                        decoration: BoxDecoration(
                          color: bgColor,
                          border: Border.all(color: borderColor, width: (isToday && canClaim) ? 2 : 1),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: (isToday && canClaim) ? [BoxShadow(color: Colors.orange.withOpacity(0.3), blurRadius: 5)] : [],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text("Ngày $day", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black54)),
                            const SizedBox(height: 5),
                            isPast
                                ? const Icon(Icons.check_circle, color: Colors.green, size: 28)
                                : Icon(Icons.monetization_on, color: (isToday && canClaim) ? Colors.orange : Colors.amberAccent, size: 28),
                            const SizedBox(height: 5),
                            Text("+$reward", style: TextStyle(color: isPast ? Colors.grey : Colors.orange[800], fontWeight: FontWeight.bold)),
                          ],
                        ),
                      );
                    }),
                  ),

                  const SizedBox(height: 30),

                  // Nút Nhận Quà
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: canClaim ? Colors.orange : Colors.grey,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        elevation: canClaim ? 5 : 0,
                      ),
                      onPressed: canClaim ? () async {
                        // 1. Gọi hàm claimDailyReward (Logic tính streak)
                        await authProvider.claimDailyReward();

                        // 2. Gọi hàm addReward (Logic cộng tiền)
                        // Lưu ý: Trong claimDailyReward bạn nên gọi addReward rồi,
                        // nhưng nếu chưa thì gọi ở đây cũng được.
                        // int rewardReceived = rewards[displayStreak];
                        await authProvider.addReward(goldReward: 100);

                        if (context.mounted) Navigator.pop(context);

                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Điểm danh thành công!"), backgroundColor: Colors.green)
                        );
                      } : null,
                      child: Text(
                        canClaim ? "NHẬN THƯỞNG NGAY" : "ĐÃ NHẬN HÔM NAY",
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                      ),
                    ),
                  )
                ],
              ),
            ),
          ),

          // 2. NÚT THOÁT (X)
          Positioned(
            top: 10,
            right: 10,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.grey, size: 28),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }
}