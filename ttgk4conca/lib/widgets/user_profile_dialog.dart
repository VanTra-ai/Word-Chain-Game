// lib/widgets/user_profile_dialog.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../main.dart'; // AuthProvider
import '../constants/app_colors.dart';
import '../screens/private_chat_screen.dart';

class UserProfileDialog extends StatelessWidget {
  final String targetUserId;

  const UserProfileDialog({super.key, required this.targetUserId});

  // Helper hiển thị ảnh (Copy từ world_chat_screen sang hoặc để vào utils dùng chung)
  ImageProvider _getAvatarProvider(String? url) {
    if (url != null && url.isNotEmpty) {
      if (url.startsWith('http')) return NetworkImage(url);
      return AssetImage(url);
    }
    return const AssetImage('assets/default_avatar.png');
  }

  @override
  Widget build(BuildContext context) {
    final myAuth = Provider.of<AuthProvider>(context, listen: false);
    final myUid = myAuth.user?.uid;

    if (myUid == null) return const SizedBox();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.transparent,
      child: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(targetUserId).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final data = snapshot.data!.data() as Map<String, dynamic>?;
          if (data == null) return const Center(child: Text("Không tìm thấy người chơi"));

          // Lấy thông tin
          String name = data['displayName'] ?? "Unknown";
          String avatar = data['currentAvatar'] ?? data['photoURL'] ?? "";
          int level = data['level'] ?? 1;
          int totalGames = data['totalGames'] ?? 0;
          int totalWins = data['totalWins'] ?? 0;

          // Tính tỷ lệ thắng
          double winRate = (totalGames > 0) ? (totalWins / totalGames * 100) : 0.0;

          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // --- HEADER BACKGROUND ---
                Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      height: 100,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [Colors.blue.shade300, Colors.purple.shade300]),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                      ),
                    ),
                    Positioned(
                      bottom: -40,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                        child: CircleAvatar(
                          radius: 40,
                          backgroundImage: _getAvatarProvider(avatar),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 10, right: 10,
                      child: IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    )
                  ],
                ),
                const SizedBox(height: 50),

                // --- TÊN & LEVEL ---
                Text(name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                Container(
                  margin: const EdgeInsets.only(top: 5),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(15)),
                  child: Text("Level $level", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                ),

                const SizedBox(height: 20),

                // --- THỐNG KÊ (GRID) ---
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatItem("Số trận", "$totalGames", Icons.videogame_asset),
                      _buildStatItem("Thắng", "$totalWins", Icons.emoji_events, color: Colors.orange),
                      _buildStatItem("Tỷ lệ", "${winRate.toStringAsFixed(1)}%", Icons.pie_chart, color: Colors.green),
                    ],
                  ),
                ),

                const SizedBox(height: 25),

                // --- NÚT CHỨC NĂNG (LOGIC QUAN TRỌNG) ---
                if (targetUserId != myUid) // Không hiện nút nếu xem profile chính mình
                  StreamBuilder<DocumentSnapshot>(
                    // Kiểm tra xem đã là bạn bè chưa
                    stream: FirebaseFirestore.instance.collection('users').doc(myUid).collection('friends').doc(targetUserId).snapshots(),
                    builder: (context, friendSnap) {
                      bool isFriend = friendSnap.hasData && friendSnap.data!.exists;

                      if (isFriend) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 20),
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12)),
                            icon: const Icon(Icons.message),
                            label: const Text("Nhắn Tin"),
                            onPressed: () {
                              Navigator.pop(context); // Đóng Dialog trước
                              Navigator.push(context, MaterialPageRoute(builder: (_) => PrivateChatScreen(friendId: targetUserId, friendName: name, friendAvatar: avatar)));
                            },
                          ),
                        );
                      } else {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 20),
                          child: StreamBuilder<DocumentSnapshot>(
                            // Kiểm tra xem đã gửi lời mời chưa
                              stream: FirebaseFirestore.instance.collection('users').doc(targetUserId).collection('friend_requests').doc(myUid).snapshots(),
                              builder: (context, reqSnap) {
                                bool isSent = reqSnap.hasData && reqSnap.data!.exists;

                                if (isSent) {
                                  return OutlinedButton.icon(
                                    onPressed: null, // Disable nút
                                    icon: const Icon(Icons.check),
                                    label: const Text("Đã gửi lời mời"),
                                  );
                                }

                                return ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12)),
                                  icon: const Icon(Icons.person_add),
                                  label: const Text("Kết Bạn"),
                                  onPressed: () async {
                                    // Logic gửi kết bạn
                                    String myAvatar = myAuth.customAvatar.isNotEmpty ? myAuth.customAvatar : (myAuth.user?.photoURL ?? "");
                                    await FirebaseFirestore.instance.collection('users').doc(targetUserId).collection('friend_requests').doc(myUid).set({
                                      'name': myAuth.user?.displayName ?? "Unknown",
                                      'avatar': myAvatar,
                                      'timestamp': FieldValue.serverTimestamp(),
                                    });
                                  },
                                );
                              }
                          ),
                        );
                      }
                    },
                  ),
                if (targetUserId == myUid)
                  const Padding(padding: EdgeInsets.only(bottom: 20), child: Text("Đây là hồ sơ của bạn", style: TextStyle(color: Colors.grey))),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, {Color color = Colors.blue}) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 5),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    );
  }
}