// lib/screens/friend_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/friend_service.dart';
import '../constants/app_colors.dart';
import 'private_chat_screen.dart';
import 'dart:math';
import 'package:firebase_database/firebase_database.dart';
import 'online_game_screen.dart';

class FriendScreen extends StatelessWidget {
  const FriendScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        // 1. Đổi nền sang màu xám nhạt cho sạch sẽ, dễ nhìn
        backgroundColor: Colors.grey[100],
        appBar: AppBar(
          title: const Text("Bạn Bè", style: TextStyle(fontWeight: FontWeight.bold)),
          centerTitle: true,
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          bottom: const TabBar(
            tabs: [
              Tab(text: "Danh sách bạn"),
              Tab(text: "Lời mời kết bạn"),
            ],
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
        body: const TabBarView(
          children: [
            MyFriendListTab(),
            FriendRequestTab(),
          ],
        ),
      ),
    );
  }
}

// --- WIDGET CHUNG: HIỂN THỊ KHI DANH SÁCH TRỐNG ---
Widget _buildEmptyState({required IconData icon, required String title, required String subTitle}) {
  return Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(25),
          decoration: BoxDecoration(
            color: Colors.grey[200], // Nền tròn màu xám nhạt
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 60, color: Colors.grey[400]), // Icon màu xám
        ),
        const SizedBox(height: 20),
        Text(
          title,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[700]),
        ),
        const SizedBox(height: 8),
        Text(
          subTitle,
          style: TextStyle(fontSize: 14, color: Colors.grey[500]),
        ),
      ],
    ),
  );
}

// --- TAB 1: DANH SÁCH BẠN BÈ ---
class MyFriendListTab extends StatelessWidget {
  const MyFriendListTab({super.key});

  void _inviteFriend(BuildContext context, String targetUserId, String targetName, String? targetAvatar) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    String roomId = (1000 + Random().nextInt(9000)).toString();

    FirebaseDatabase.instance.ref('invites/$targetUserId').set({
      'fromId': user.uid,
      'fromName': user.displayName,
      'roomId': roomId,
      'timestamp': ServerValue.timestamp,
    });

    FirebaseDatabase.instance.ref('rooms/$roomId').set({
      'status': 'waiting',
      'host': {'id': user.uid, 'name': user.displayName, 'avatar': user.photoURL},
      'currentTurn': user.uid,
      'words': [],
    });

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => OnlineGameScreen(roomId: roomId, currentUserId: user.uid)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('friends')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final friends = snapshot.data!.docs;

        // 2. Giao diện trống đẹp hơn
        if (friends.isEmpty) {
          return _buildEmptyState(
              icon: Icons.supervised_user_circle_outlined,
              title: "Chưa có bạn bè",
              subTitle: "Hãy vào 'Cộng đồng' để kết bạn nhé!"
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          itemCount: friends.length,
          itemBuilder: (context, index) {
            final friendData = friends[index].data() as Map<String, dynamic>;
            final friendId = friendData['id'];

            return StreamBuilder<DatabaseEvent>(
              stream: FirebaseDatabase.instance.ref('status/$friendId').onValue,
              builder: (context, statusSnapshot) {

                String status = 'offline';
                if (statusSnapshot.hasData && statusSnapshot.data!.snapshot.value != null) {
                  final val = Map<String, dynamic>.from(statusSnapshot.data!.snapshot.value as Map);
                  status = val['state'] ?? 'offline';
                }

                Color statusColor;
                String statusText;
                bool canInvite;

                switch (status) {
                  case 'online':
                    statusColor = Colors.green;
                    statusText = "Online";
                    canInvite = true;
                    break;
                  case 'playing':
                    statusColor = Colors.redAccent;
                    statusText = "Đang chơi";
                    canInvite = false;
                    break;
                  default:
                    statusColor = Colors.grey;
                    statusText = "Offline";
                    canInvite = false;
                }

                // 3. Card màu trắng, chữ đen, đổ bóng nhẹ
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: Stack(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: statusColor.withOpacity(0.5), width: 2),
                          ),
                          child: CircleAvatar(
                            radius: 26,
                            backgroundColor: Colors.grey[200],
                            backgroundImage: (friendData['avatar'] != null && friendData['avatar'] != "")
                                ? NetworkImage(friendData['avatar'])
                                : null,
                            child: (friendData['avatar'] == null || friendData['avatar'] == "")
                                ? const Icon(Icons.person, color: Colors.grey) : null,
                          ),
                        ),
                        Positioned(
                          right: 0, bottom: 0,
                          child: Container(
                            width: 14, height: 14,
                            decoration: BoxDecoration(
                              color: statusColor,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                          ),
                        )
                      ],
                    ),
                    title: Text(
                        friendData['name'] ?? "Unknown",
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)
                    ),
                    subtitle: Text(
                        statusText,
                        style: TextStyle(color: statusColor, fontSize: 13, fontWeight: FontWeight.w500)
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Nút Chat: Màu nhạt, icon đậm
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.chat_bubble_rounded, color: Colors.blue, size: 22),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => PrivateChatScreen(
                                  friendId: friendData['id'],
                                  friendName: friendData['name'] ?? "Unknown",
                                  friendAvatar: friendData['avatar'] ?? "",
                                )),
                              );
                            },
                          ),
                        ),

                        const SizedBox(width: 8),

                        // Nút Đấu
                        if (status != 'offline')
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: canInvite ? Colors.orange : Colors.grey[300],
                              foregroundColor: canInvite ? Colors.white : Colors.grey[600],
                              elevation: canInvite ? 2 : 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                            onPressed: canInvite
                                ? () => _inviteFriend(context, friendId, friendData['name'], friendData['avatar'])
                                : null,
                            child: Text(canInvite ? "Đấu" : "Bận", style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                          ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

// --- TAB 2: LỜI MỜI KẾT BẠN ---
class FriendRequestTab extends StatelessWidget {
  const FriendRequestTab({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('friend_requests')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final requests = snapshot.data!.docs;

        if (requests.isEmpty) {
          return _buildEmptyState(
              icon: Icons.mail_outline_rounded,
              title: "Không có lời mời",
              subTitle: "Hiện tại chưa có ai gửi lời mời kết bạn."
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: requests.length,
          itemBuilder: (context, index) {
            final data = requests[index].data() as Map<String, dynamic>;
            final reqId = data['fromId'];

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.all(12),
                leading: CircleAvatar(
                  radius: 28,
                  backgroundImage: (data['fromAvatar'] != null && data['fromAvatar'] != "")
                      ? NetworkImage(data['fromAvatar'])
                      : null,
                  child: (data['fromAvatar'] == null || data['fromAvatar'] == "")
                      ? const Icon(Icons.person) : null,
                ),
                title: Text(data['fromName'] ?? "Unknown", style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text("Muốn kết bạn với bạn", style: TextStyle(color: Colors.grey)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Nút Từ chối (Tròn đỏ nhạt)
                    CircleAvatar(
                      backgroundColor: Colors.red[50],
                      radius: 20,
                      child: IconButton(
                        icon: const Icon(Icons.close, color: Colors.red, size: 20),
                        onPressed: () => FriendService.declineFriendRequest(reqId),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Nút Đồng ý (Tròn xanh nhạt)
                    CircleAvatar(
                      backgroundColor: Colors.green[50],
                      radius: 20,
                      child: IconButton(
                        icon: const Icon(Icons.check, color: Colors.green, size: 20),
                        onPressed: () => FriendService.acceptFriendRequest(reqId, data['fromName'], data['fromAvatar']),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}