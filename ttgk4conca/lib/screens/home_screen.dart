// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
// 1. Thêm Import Widget điểm danh
import '../widgets/daily_check_in_dialog.dart';
import '../main.dart';
import '../constants/app_colors.dart';
import 'game_play_screen.dart';
import 'lobby_screen.dart';
import 'group_lobby_screen.dart';
import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'online_game_screen.dart';
import '../services/presence_service.dart';
import '../utils/number_formatter.dart';
import '../utils/audio_manager.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  StreamSubscription? _inviteSub;

  @override
  void initState() {
    super.initState();
    PresenceService.configurePresence();
    _listenForInvites();
    AudioManager().playMainMenuMusic();
  }

  @override
  void dispose() {
    _inviteSub?.cancel();
    super.dispose();
  }

  void _listenForInvites() {
    // (Giữ nguyên logic cũ của bạn ở đây...)
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;
    if (user == null) return;
    final inviteRef = FirebaseDatabase.instance.ref('invites/${user.uid}');
    _inviteSub = inviteRef.onValue.listen((event) {
      final data = event.snapshot.value;
      if (data != null) {
        final invite = Map<String, dynamic>.from(data as Map);
        // ... (Code popup nhận lời mời giữ nguyên) ...
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Text("⚔️ LỜI THÁCH ĐẤU!", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            content: Text("${invite['fromName']} đang muốn so tài cao thấp với bạn!"),
            actions: [
              TextButton(
                onPressed: () {
                  // BÁO TỪ CHỐI CHO CHỦ PHÒNG
                  FirebaseDatabase.instance.ref('rooms/${invite['roomId']}').update({
                    'status': 'refused' // Đánh dấu là bị từ chối
                  });

                  inviteRef.remove();
                  Navigator.pop(ctx);
                },
                child: const Text("Sợ quá, thôi"),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                onPressed: () async {
                  inviteRef.remove();
                  Navigator.pop(ctx);
                  await FirebaseDatabase.instance.ref('rooms/${invite['roomId']}').update({
                    'status': 'playing',
                    'guest': {'id': user.uid, 'name': user.displayName, 'avatar': user.photoURL}
                  });
                  if (mounted) {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => OnlineGameScreen(roomId: invite['roomId'], currentUserId: user.uid)));
                  }
                },
                child: const Text("CHIẾN LUÔN 👊", style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Row(
          children: [
            Icon(Icons.extension, color: AppColors.primary),
            SizedBox(width: 10),
            Text("NỐI CHỮ", style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          // --- 1. NÚT ĐIỂM DANH (MỚI THÊM) ---
          Stack(
            alignment: Alignment.topRight,
            children: [
              IconButton(
                icon: const Icon(Icons.calendar_month_rounded, color: Colors.blueAccent, size: 28),
                tooltip: "Điểm danh",
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => const DailyCheckInDialog(),
                  );
                },
              ),
              // Dấu chấm đỏ báo hiệu chưa nhận quà
              if (authProvider.canCheckIn)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                )
            ],
          ),

          // --- 2. HIỂN THỊ COIN (CŨ) ---
          Container(
              margin: const EdgeInsets.only(right: 16, left: 5),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                  color: Colors.amber[100],
                  borderRadius: BorderRadius.circular(20)
              ),
              child: Row(
                  children: [
                    const Icon(Icons.monetization_on, color: Colors.orange, size: 20),
                    const SizedBox(width: 5),
                    Text(
                        NumberFormatter.format(authProvider.coin),
                        style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)
                    )
                  ]
              )
          )
        ],
      ),

      // ... PHẦN BODY GIỮ NGUYÊN ...
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 1. CHƠI VỚI MÁY
              _buildGameButton(
                context,
                label: "CHƠI VỚI MÁY",
                icon: Icons.smart_toy_rounded,
                color: Colors.blueAccent,
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const GamePlayScreen()));
                },
              ),
              const SizedBox(height: 16),

              // 2. ĐẤU 1 VS 1
              _buildGameButton(
                context,
                label: "ĐẤU 1 VS 1",
                icon: Icons.people_outline, // Đổi icon cho chiến (nếu có thư viện), ko thì dùng icon cũ
                color: Colors.deepPurple,
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const LobbyScreen()));
                },
              ),
              const SizedBox(height: 16),

              // 3. ĐẤU TRƯỜNG NHÓM
              _buildGameButton(
                context,
                label: "ĐẤU TRƯỜNG (2-6)",
                icon: Icons.groups_rounded,
                color: Colors.orange[800]!,
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const GroupLobbyScreen()));
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Widget tạo nút bấm (Giữ nguyên)
  Widget _buildGameButton(BuildContext context, {
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: 250,
      height: 55,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          elevation: 5,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        ),
        onPressed: onTap,
        icon: Icon(icon, size: 28),
        label: Text(label, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ),
    );
  }
}