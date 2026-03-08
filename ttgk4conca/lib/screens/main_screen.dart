// lib/screens/main_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../constants/app_colors.dart';
import 'home_screen.dart';
import 'world_chat_screen.dart';
import 'leaderboard_screen.dart';
import 'profile_screen.dart';
import 'shop_screen.dart';
import 'online_game_screen.dart';
import '../widgets/daily_check_in_dialog.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  StreamSubscription? _inviteSubscription; // [MỚI] Biến quản lý lắng nghe

  @override
  void initState() {
    super.initState();
    // Chạy các hàm khởi tạo sau khi giao diện load xong
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkDailyReward();
      _listenToGameInvites(); // [MỚI] Bắt đầu lắng nghe lời mời
    });
  }

  @override
  void dispose() {
    _inviteSubscription?.cancel(); // [MỚI] Hủy lắng nghe khi thoát app
    super.dispose();
  }

  // --- 1. LOGIC ĐIỂM DANH (CŨ) ---
  void _checkDailyReward() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.user != null && authProvider.canCheckIn) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const DailyCheckInDialog(),
      );
    }
  }

  // --- 2. [MỚI] LOGIC LẮNG NGHE LỜI MỜI ---
  void _listenToGameInvites() {
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    if (user == null) return;

    // Lắng nghe node: invites/{userId}
    final inviteRef = FirebaseDatabase.instance.ref('invites/${user.uid}');

    _inviteSubscription = inviteRef.onChildAdded.listen((event) {
      if (event.snapshot.value == null) return;

      final data = Map<String, dynamic>.from(event.snapshot.value as Map);
      final String inviteKey = event.snapshot.key!; // Lấy ID của lời mời để xóa sau này

      // Hiển thị Dialog Mời đấu
      _showInviteDialog(inviteKey, data);
    });
  }

  // --- 3. [MỚI] HIỆN DIALOG MỜI ---
  void _showInviteDialog(String inviteKey, Map<String, dynamic> data) {
    String hostName = data['fromName'] ?? "Người lạ";
    String roomId = data['roomId'];

    showDialog(
      context: context,
      barrierDismissible: false, // Bắt buộc chọn
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Row(
          children: [
            const Icon(Icons.sports_esports, color: Colors.deepOrange),
            const SizedBox(width: 10),
            const Text("Lời Thách Đấu!", style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          "$hostName đang mời bạn solo 1vs1.\nBạn có dám chấp nhận không?",
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () {
              final user = Provider.of<AuthProvider>(context, listen: false).user;
              if (user != null) {
                // 1. Xóa lời mời
                FirebaseDatabase.instance.ref('invites/${user.uid}/$inviteKey').remove();

                // 2. Báo cho đối thủ biết là mình từ chối
                FirebaseDatabase.instance.ref('rooms/$roomId').update({
                  'status': 'refused'
                });
              }
              Navigator.pop(ctx);
            },
            child: const Text("Từ chối", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx); // Đóng dialog
              _acceptInvite(inviteKey, roomId, hostName); // Xử lý chấp nhận
            },
            child: const Text("CHIẾN LUÔN!"),
          ),
        ],
      ),
    );
  }

  // --- 4. [MỚI] XỬ LÝ CHẤP NHẬN ---
  void _acceptInvite(String inviteKey, String roomId, String hostName) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;
    if (user == null) return;

    // A. Cập nhật thông tin Guest (mình) vào phòng
    DatabaseReference roomRef = FirebaseDatabase.instance.ref('rooms/$roomId');

    String myAvatar = authProvider.customAvatar.isNotEmpty ? authProvider.customAvatar : (user.photoURL ?? "");

    await roomRef.update({
      'status': 'playing', // Chuyển trạng thái để bên Host biết và vào game
      'guest': {
        'id': user.uid,
        'name': user.displayName ?? "Đối thủ",
        'avatar': myAvatar,
        'score': 0
      }
    });

    // B. Xóa lời mời sau khi đã nhận
    await FirebaseDatabase.instance.ref('invites/${user.uid}/$inviteKey').remove();

    // C. Chuyển sang màn hình game
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OnlineGameScreen(
            roomId: roomId,
            currentUserId: user.uid,
          ),
        ),
      );
    }
  }

  // Danh sách các trang
  final List<Widget> _pages = [
    const HomeScreen(),
    const WorldChatScreen(),
    const ShopScreen(),
    const LeaderboardScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(blurRadius: 20, color: Colors.black.withOpacity(.1))
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8),
            child: BottomNavigationBar(
              elevation: 0,
              backgroundColor: Colors.white,
              selectedItemColor: AppColors.primary,
              unselectedItemColor: Colors.grey,
              type: BottomNavigationBarType.fixed,
              selectedFontSize: 12,
              unselectedFontSize: 10,
              currentIndex: _selectedIndex,
              onTap: (index) {
                setState(() {
                  _selectedIndex = index;
                });
              },
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.gamepad_rounded),
                  label: 'Trang chủ',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.public),
                  label: 'Cộng đồng',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.storefront_rounded),
                  activeIcon: Icon(Icons.storefront_rounded, color: Colors.orange),
                  label: 'Cửa hàng',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.emoji_events),
                  label: 'Xếp hạng',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.person),
                  label: 'Cá nhân',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}