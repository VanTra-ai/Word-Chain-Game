// lib/screens/leaderboard_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../constants/app_colors.dart';
import '../widgets/user_profile_dialog.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  // 0: Điểm số, 1: Level, 2: Chuỗi thắng
  int _selectedIndex = 0;

  // Cấu hình cho từng loại bảng xếp hạng
  final List<Map<String, dynamic>> _tabs = [
    {'label': 'Điểm Số', 'field': 'leaderboardScore', 'icon': Icons.emoji_events},
    {'label': 'Level', 'field': 'level', 'icon': Icons.stars},
    {'label': 'Chuỗi Thắng', 'field': 'winStreak', 'icon': Icons.local_fire_department},
  ];

  @override
  Widget build(BuildContext context) {
    final currentUser = Provider.of<AuthProvider>(context).user;
    if (currentUser == null) return const SizedBox.shrink();

    final currentTab = _tabs[_selectedIndex];
    final String orderByField = currentTab['field'];

    return Scaffold(
      backgroundColor: AppColors.primary,
      appBar: AppBar(
        title: const Text("BẢNG VÀNG 🏆", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // 1. THANH CHUYỂN TAB (HEADER)
          Container(
            margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(25),
            ),
            child: Row(
              children: List.generate(_tabs.length, (index) {
                bool isActive = _selectedIndex == index;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedIndex = index),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: isActive ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            _tabs[index]['icon'],
                            size: 18,
                            color: isActive ? AppColors.primary : Colors.white70,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _tabs[index]['label'],
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: isActive ? AppColors.primary : Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),

          // 2. DANH SÁCH TOP 50 (BODY)
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(topLeft: Radius.circular(30), topRight: Radius.circular(30)),
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(30), topRight: Radius.circular(30)),
                child: StreamBuilder<QuerySnapshot>(
                  // [QUAN TRỌNG] Sắp xếp theo field đang chọn, giới hạn 50
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .orderBy(orderByField, descending: true)
                      .limit(50)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Center(child: Text("Chưa có dữ liệu xếp hạng!"));
                    }

                    final docs = snapshot.data!.docs;

                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                      itemCount: docs.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final data = docs[index].data() as Map<String, dynamic>;
                        final userId = docs[index].id; // [MỚI] Lấy ID người chơi
                        final isMe = userId == currentUser.uid;

                        return _buildRankItem(
                          rank: index + 1,
                          data: data,
                          valueField: orderByField,
                          isMe: isMe,
                          userId: userId, // [MỚI] Truyền ID vào hàm này
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),

      // 3. HẠNG CỦA TÔI (STICKY BOTTOM BAR)
      bottomSheet: _buildMyRankBar(currentUser.uid, orderByField),
    );
  }

  // Widget hiển thị 1 dòng xếp hạng
  Widget _buildRankItem({
    required int rank,
    required Map<String, dynamic> data,
    required String valueField,
    required String userId,
    bool isMe = false,
  }) {
    // Xử lý hiển thị Avatar (Ưu tiên Asset -> Network)
    ImageProvider avatarImg;
    String? customAvatar = data['currentAvatar'];
    String? photoUrl = data['photoURL'];
    if (customAvatar != null && customAvatar.isNotEmpty) {
      if (customAvatar.startsWith('http')) {
        avatarImg = NetworkImage(customAvatar);
      } else {
        avatarImg = AssetImage(customAvatar);
      }
    } else if (photoUrl != null && photoUrl.isNotEmpty) {
      avatarImg = NetworkImage(photoUrl);
    } else {
      avatarImg = const AssetImage('assets/default_avatar.png');
    }

    // Màu sắc top
    Color rankColor = Colors.black;
    IconData? rankIcon;
    if (rank == 1) { rankColor = Colors.amber; rankIcon = Icons.emoji_events; }
    else if (rank == 2) { rankColor = Colors.grey; rankIcon = Icons.emoji_events; }
    else if (rank == 3) { rankColor = Colors.brown; rankIcon = Icons.emoji_events; }

    // Giá trị hiển thị (Score, Level, hoặc WinStreak)
    String displayValue = "${data[valueField] ?? 0}";
    if (valueField == 'level') displayValue = "Lv.$displayValue";
    if (valueField == 'winStreak') displayValue = "$displayValue trận";

    return InkWell(
      onTap: () {
        // Gọi Widget xem thông tin mà bạn đã tạo ở bước trước
        showDialog(
          context: context,
          builder: (_) => UserProfileDialog(targetUserId: userId),
        );
      },
      child: Container(
        color: isMe ? Colors.blue.withOpacity(0.1) : Colors.transparent,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Row(
          children: [
            SizedBox(
              width: 40,
              child: rank <= 3
                  ? Icon(rankIcon, color: rankColor, size: 28)
                  : Center(child: Text("$rank", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.grey[700]))),
            ),
            const SizedBox(width: 10),
            CircleAvatar(radius: 22, backgroundImage: avatarImg),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                data['displayName'] ?? "Unknown",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isMe ? Colors.blue[800] : Colors.black87),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isMe ? Colors.blue : AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Text(
                displayValue,
                style: TextStyle(fontWeight: FontWeight.bold, color: isMe ? Colors.white : AppColors.primary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Widget Thanh Hạng Của Tôi (Fixed Bottom)
  Widget _buildMyRankBar(String myUid, String orderByField) {
    return Container(
      height: 90,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: const Offset(0, -5))],
      ),
      child: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(myUid).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const SizedBox.shrink();
          final myData = snapshot.data!.data() as Map<String, dynamic>;
          final myValue = myData[orderByField] ?? 0;

          return FutureBuilder<int>(
            // Tính toán hạng của mình (kể cả khi ngoài top 50)
            future: _calculateMyRank(orderByField, myValue),
            builder: (context, rankSnapshot) {
              int myRank = rankSnapshot.data ?? 0;
              String rankStr = myRank == 0 ? "..." : (myRank > 999 ? "999+" : "$myRank");

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    const Text("Bạn:", style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
                    const SizedBox(width: 10),
                    // Hạng
                    Container(
                      width: 40, height: 40,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                      child: Text(rankStr, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 10),
                    // Tên & Giá trị
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(myData['displayName'] ?? "Tôi", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          Text(
                              _getDisplayLabel(orderByField, myValue),
                              style: TextStyle(color: Colors.grey[600], fontSize: 13)
                          ),
                        ],
                      ),
                    ),
                    // Nút xem chi tiết (nếu cần)
                    Icon(Icons.arrow_upward, color: Colors.green[400]),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _getDisplayLabel(String field, dynamic value) {
    if (field == 'level') return "Level $value";
    if (field == 'winStreak') return "Chuỗi thắng: $value";
    return "Điểm: $value";
  }

  // Hàm tính hạng (Sử dụng Count Aggregation để tối ưu chi phí)
  Future<int> _calculateMyRank(String field, int myValue) async {
    // Đếm số người có điểm cao hơn mình
    final countQuery = await FirebaseFirestore.instance
        .collection('users')
        .where(field, isGreaterThan: myValue)
        .count()
        .get();

    // Hạng = số người cao hơn + 1
    return countQuery.count! + 1;
  }
}