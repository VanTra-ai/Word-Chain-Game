// lib/screens/profile_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:cloud_firestore/cloud_firestore.dart';

import '../main.dart'; // Import AuthProvider
import '../constants/app_colors.dart';
import '../utils/number_formatter.dart';
import 'history_screen.dart';
import 'admin/admin_dashboard_screen.dart';
import 'edit_profile_screen.dart';
import '../utils/audio_manager.dart';
import 'about_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  // --- 1. HÀM HIỂN THỊ DIALOG NHẬP MÃ ---
  void _showRedeemDialog(BuildContext context) {
    final codeController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Row(
          children: const [
            Icon(Icons.card_giftcard, color: Colors.deepOrange),
            SizedBox(width: 10),
            Text("Mã quà tặng"),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Nhập mã Giftcode để nhận Vàng và EXP miễn phí!"),
            const SizedBox(height: 15),
            TextField(
              controller: codeController,
              decoration: const InputDecoration(
                hintText: "VD: TET2026",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.vpn_key),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Hủy")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange),
            onPressed: () async {
              Navigator.pop(ctx);
              await _redeemCode(context, codeController.text.trim().toUpperCase());
            },
            child: const Text("Nhận Quà"),
          )
        ],
      ),
    );
  }

  // --- 2. LOGIC XỬ LÝ NHẬN QUÀ ---
  Future<void> _redeemCode(BuildContext context, String code) async {
    if (code.isEmpty) return;
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    if (user == null) return;

    showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));

    try {
      final firestore = FirebaseFirestore.instance;
      final codeRef = firestore.collection('gift_codes').doc(code);
      final userRef = firestore.collection('users').doc(user.uid); // Reference tới User

      await firestore.runTransaction((transaction) async {
        // 1. Đọc dữ liệu Code
        final codeSnapshot = await transaction.get(codeRef);
        if (!codeSnapshot.exists) throw "Mã không tồn tại!";

        // 2. Đọc dữ liệu User hiện tại (Để lấy Level và Exp cũ)
        final userSnapshot = await transaction.get(userRef);
        if (!userSnapshot.exists) throw "Tài khoản lỗi!";

        final data = codeSnapshot.data() as Map<String, dynamic>;
        final userData = userSnapshot.data() as Map<String, dynamic>;

        // --- Kiểm tra điều kiện Code ---
        if (data['isActive'] == false) throw "Mã đang bị khóa!";
        if (data['expiryDate'] != null) {
          Timestamp expiryTs = data['expiryDate'];
          if (DateTime.now().isAfter(expiryTs.toDate())) throw "Mã đã hết hạn!";
        }
        int limit = data['limit'] ?? 0;
        int usedCount = data['usedCount'] ?? 0;
        if (usedCount >= limit) throw "Mã đã hết lượt nhập!";

        // Kiểm tra lịch sử nhập
        final userHistoryRef = userRef.collection('redeemed_codes').doc(code);
        final userHistorySnapshot = await transaction.get(userHistoryRef);
        if (userHistorySnapshot.exists) throw "Bạn đã sử dụng mã này rồi!";

        // --- TÍNH TOÁN PHẦN THƯỞNG & LEVEL UP ---
        final rewards = data['rewards'] as Map<String, dynamic>;
        int coinReward = rewards['coin'] ?? 0;
        int expReward = rewards['exp'] ?? 0;

        // Lấy thông số hiện tại của User
        int currentCoin = userData['coin'] ?? 0;
        int currentExp = userData['exp'] ?? 0;
        int currentLevel = userData['level'] ?? 1;

        // Cộng thưởng
        currentCoin += coinReward;
        currentExp += expReward;

        // >>> LOGIC VÒNG LẶP LEVEL UP (MỚI THÊM) <<<
        // Giả sử công thức Max Exp = Level * 100
        int maxExp = currentLevel * 100;

        while (currentExp >= maxExp) {
          currentExp -= maxExp;      // Trừ đi Exp thăng cấp
          currentLevel++;            // Tăng Level
          maxExp = currentLevel * 100; // Tính Max Exp cho cấp mới
        }

        // --- Cập nhật Firebase ---
        // Thay vì dùng FieldValue.increment, ta ghi đè giá trị mới đã tính toán
        transaction.update(userRef, {
          'coin': currentCoin,
          'exp': currentExp,   // Exp dư ra sau khi thăng cấp (ví dụ: 15)
          'level': currentLevel // Level mới (ví dụ: 2, 3, 4...)
        });

        // Cập nhật Code
        transaction.update(codeRef, {'usedCount': FieldValue.increment(1)});

        // Lưu lịch sử
        transaction.set(userHistoryRef, {
          'usedAt': FieldValue.serverTimestamp(),
          'rewards': rewards
        });
      });

      if (context.mounted) {
        await Provider.of<AuthProvider>(context, listen: false).refreshUser();
      }

      if (context.mounted) {
        Navigator.pop(context); // Tắt loading
        showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text("🎉 CHÚC MỪNG 🎉", textAlign: TextAlign.center, style: TextStyle(color: Colors.green)),
              content: const Text("Bạn đã nhận quà và cập nhật cấp độ thành công!"),
              actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("Tuyệt vời"))],
            )
        );
      }

    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;

    if (user == null) return const Center(child: CircularProgressIndicator());

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text("Hồ sơ cá nhân", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.settings, color: Colors.black),
            tooltip: "Cài đặt",
            onSelected: (value) {
              // Phát nhạc cho các mục (trừ mục sound đã xử lý riêng trong onTap)
              if (value != 'sound') {
                AudioManager().playSFX('button.mp3');
              }

              if (value == 'giftcode') {
                _showRedeemDialog(context);
              } else if (value == 'about') {
                // [SỬA] Thêm Navigator ở đây để nút trong Settings hoạt động
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AboutScreen()),
                );
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              // Mục 1: Âm thanh
              PopupMenuItem<String>(
                value: 'sound',
                child: StatefulBuilder(
                    builder: (context, setStateItem) {
                      bool isMuted = AudioManager().isMuted;
                      return ListTile(
                        leading: Icon(
                            isMuted ? Icons.volume_off : Icons.volume_up,
                            color: isMuted ? Colors.grey : Colors.blue
                        ),
                        title: Text(isMuted ? 'Bật âm thanh' : 'Tắt âm thanh'),
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        onTap: () {
                          // [SỬA TẠI ĐÂY] Phát nhạc TRƯỚC khi logic tắt tiếng chạy
                          // Để người dùng nghe thấy tiếng "bíp" xác nhận đã bấm
                          AudioManager().playSFX('button.mp3');

                          // Sau đó mới đảo ngược trạng thái
                          AudioManager().toggleMute();

                          setStateItem(() {});
                          Navigator.pop(context);
                        },
                      );
                    }
                ),
              ),
              const PopupMenuDivider(),
              // Mục 2: Nhập Giftcode
              const PopupMenuItem<String>(
                value: 'giftcode',
                // ListTile này không có onTap riêng, nên nó sẽ truyền sự kiện lên onSelected -> Có tiếng
                child: ListTile(
                  leading: Icon(Icons.card_giftcard, color: Colors.deepOrange),
                  title: Text('Nhập Giftcode'),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
              ),
              const PopupMenuDivider(),
              // Mục 3: Về ứng dụng (Trong Settings)
              const PopupMenuItem<String>(
                value: 'about',
                child: ListTile(
                  leading: Icon(Icons.info_outline, color: Colors.blue),
                  title: Text('Về ứng dụng'),
                  trailing: Icon(Icons.chevron_right, size: 16),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
              ),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 20),

            // --- 1. AVATAR ---
            Center(
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppColors.primary, width: 3), boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 10)]),
                    child: Consumer<AuthProvider>(
                        builder: (context, auth, _) {
                          ImageProvider avatarImg;
                          if (auth.customAvatar.isNotEmpty) avatarImg = AssetImage(auth.customAvatar);
                          else if (auth.user?.photoURL != null) avatarImg = NetworkImage(auth.user!.photoURL!);
                          else avatarImg = const AssetImage('assets/default_avatar.png');

                          return GestureDetector(
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfileScreen())),
                            child: CircleAvatar(radius: 60, backgroundImage: avatarImg),
                          );
                        }
                    ),
                  ),
                  Positioned(
                    bottom: 0, right: 0,
                    child: GestureDetector(
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfileScreen())),
                      child: Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: Colors.grey[300]!), boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)]), child: const Icon(Icons.edit, size: 18, color: AppColors.primary)),
                    ),
                  ),
                  Positioned(
                    top: 0, right: 0,
                    child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white, width: 2), boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)]), child: Text("Lv.${authProvider.level}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 12))),
                  )
                ],
              ),
            ),
            const SizedBox(height: 15),
            Text(user.displayName ?? "Người chơi mới", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            Text(user.email ?? "", style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 20),

            // --- 2. THANH EXP ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: Column(
                children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("Kinh nghiệm (exp)", style: TextStyle(fontWeight: FontWeight.bold)), Text("${authProvider.currentExp} / ${authProvider.maxExp}", style: const TextStyle(color: Colors.grey))]),
                  const SizedBox(height: 8),
                  ClipRRect(borderRadius: BorderRadius.circular(10), child: LinearProgressIndicator(value: authProvider.levelProgress, minHeight: 10, backgroundColor: Colors.grey[300], color: Colors.blueAccent)),
                ],
              ),
            ),
            const SizedBox(height: 30),

            // --- 3. THỐNG KÊ ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  _buildStatCard("Trận đấu", "${authProvider.totalGames}", Icons.videogame_asset, Colors.blue),
                  const SizedBox(width: 15),
                  _buildStatCard("Thắng", "${authProvider.totalWins}", Icons.emoji_events, Colors.orange),
                  const SizedBox(width: 15),
                  _buildStatCard("Tỉ lệ thắng", authProvider.totalGames > 0 ? "${((authProvider.totalWins / authProvider.totalGames) * 100).toStringAsFixed(1)}%" : "0.0%", Icons.pie_chart, Colors.green),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // --- NÚT ADMIN (Chỉ hiện nếu là Admin) ---
            StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasData && snapshot.data!.exists) {
                  final userData = snapshot.data!.data() as Map<String, dynamic>;
                  if (userData['role'] == 'admin') {
                    return Container(
                      margin: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
                      decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.red.withOpacity(0.5))),
                      child: ListTile(
                        leading: const Icon(Icons.admin_panel_settings, color: Colors.red),
                        title: const Text("Trang quản trị (Admin)", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.red),
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminDashboardScreen())),
                      ),
                    );
                  }
                }
                return const SizedBox.shrink();
              },
            ),

            // --- 4. TÀI SẢN ---
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(color: Colors.amber[50], borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.amber.withOpacity(0.5))),
              child: Row(
                children: [
                  const CircleAvatar(backgroundColor: Colors.amber, child: Icon(Icons.monetization_on, color: Colors.white)),
                  const SizedBox(width: 15),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text("Tài sản hiện có", style: TextStyle(color: Colors.grey)), Text("${NumberFormatter.format(authProvider.coin)} Vàng", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange[800]))]),
                  const Spacer(),
                  ElevatedButton(onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Sắp ra mắt!"))), style: ElevatedButton.styleFrom(backgroundColor: Colors.orange), child: const Text("Nạp thêm"))
                ],
              ),
            ),
            const SizedBox(height: 20),

            // --- 5. MENU CHỨC NĂNG ---
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 5)]),
              child: Column(
                children: [
                  // Nút Giftcode cũng để ở đây cho tiện bấm (Option nhanh)
                  ListTile(
                    leading: const Icon(Icons.card_giftcard, color: Colors.deepOrange),
                    title: const Text("Nhập Mã Quà Tặng"),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                    onTap: () => _showRedeemDialog(context),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.history, color: Colors.purple),
                    title: const Text("Lịch sử đấu"),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HistoryScreen())),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.info_outline, color: Colors.blue),
                    title: const Text("Về ứng dụng"),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                    onTap: () {
                      AudioManager().playSFX('button.mp3');
                      Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const AboutScreen())
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),

            // --- 6. NÚT ĐĂNG XUẤT ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: () async => await authProvider.signOut(),
                  icon: const Icon(Icons.logout, color: Colors.red),
                  label: const Text("Đăng xuất", style: TextStyle(color: Colors.red, fontSize: 16)),
                  style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                ),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))]),
        child: Column(
          children: [
            Icon(icon, color: color, size: 30),
            const SizedBox(height: 10),
            Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 5),
            Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}