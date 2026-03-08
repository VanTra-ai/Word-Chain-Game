// lib/screens/admin/user_list_tab.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../screens/history_screen.dart'; // Đảm bảo import đúng đường dẫn
import '../../utils/number_formatter.dart';

class UserListTab extends StatefulWidget {
  const UserListTab({super.key});

  @override
  State<UserListTab> createState() => _UserListTabState();
}

class _UserListTabState extends State<UserListTab> {
  final TextEditingController _searchController = TextEditingController();
  String _searchKeyword = "";

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // --- CÁC HÀM XỬ LÝ (BAN, COIN) ---
  void _toggleBan(String uid, bool currentStatus) {
    FirebaseFirestore.instance.collection('users').doc(uid).update({'isBanned': !currentStatus});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(currentStatus ? "Đã mở khóa!" : "Đã khóa tài khoản!")),
    );
  }

  void _editCoin(String uid, int currentCoin) {
    TextEditingController coinController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Điều chỉnh Vàng"),
        content: TextField(
          controller: coinController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: "Nhập số lượng (+ hoặc -)", border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Hủy")),
          ElevatedButton(
            onPressed: () {
              int? amount = int.tryParse(coinController.text);
              if (amount != null) {
                FirebaseFirestore.instance.collection('users').doc(uid).update({'coin': FieldValue.increment(amount)});
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Đã cập nhật số dư!")));
              }
            },
            child: const Text("Xác nhận"),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 1. THANH TÌM KIẾM
        Container(
          padding: const EdgeInsets.all(12),
          color: Colors.blue[50],
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: "🔍 Tìm tên, email hoặc UID...",
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              suffixIcon: _searchKeyword.isNotEmpty
                  ? IconButton(
                icon: const Icon(Icons.clear, color: Colors.grey),
                onPressed: () {
                  _searchController.clear();
                  setState(() => _searchKeyword = "");
                },
              )
                  : null,
            ),
            onChanged: (val) {
              setState(() => _searchKeyword = val.trim().toLowerCase());
            },
          ),
        ),

        // 2. DANH SÁCH USER
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            // [LƯU Ý] Nếu data quá lớn (>2000 user), nên bỏ limit hoặc dùng logic search phía server.
            // Ở đây mình bỏ limit(50) để Search client-side tìm được toàn bộ user.
            stream: FirebaseFirestore.instance.collection('users').orderBy('coin', descending: true).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) return Center(child: Text("Lỗi: ${snapshot.error}"));
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

              final allDocs = snapshot.data!.docs;

              // --- LOGIC LỌC TÌM KIẾM ---
              final filteredDocs = allDocs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                String name = (data['displayName'] ?? "").toLowerCase();
                String email = (data['email'] ?? "").toLowerCase();
                String uid = doc.id.toLowerCase();

                // Lọc theo 3 tiêu chí
                return _searchKeyword.isEmpty ||
                    name.contains(_searchKeyword) ||
                    email.contains(_searchKeyword) ||
                    uid.contains(_searchKeyword);
              }).toList();

              if (filteredDocs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.search_off, size: 50, color: Colors.grey),
                      const SizedBox(height: 10),
                      Text("Không tìm thấy user nào khớp với '$_searchKeyword'", style: const TextStyle(color: Colors.grey)),
                    ],
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.only(bottom: 80),
                itemCount: filteredDocs.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final userDoc = filteredDocs[index];
                  final userData = userDoc.data() as Map<String, dynamic>;
                  final userId = userDoc.id;

                  String name = userData['displayName'] ?? 'Unknown';
                  String email = userData['email'] ?? 'No Email';
                  String photoURL = userData['photoURL'] ?? '';
                  int coin = userData['coin'] ?? 0;
                  bool isBanned = userData['isBanned'] == true;
                  String role = userData['role'] ?? 'user';

                  return ListTile(
                    tileColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),

                    // Avatar
                    leading: CircleAvatar(
                      backgroundColor: role == 'admin' ? Colors.red[100] : Colors.blue[100],
                      backgroundImage: photoURL.isNotEmpty ? NetworkImage(photoURL) : null,
                      child: photoURL.isEmpty
                          ? Text(name.isNotEmpty ? name[0].toUpperCase() : "?",
                          style: TextStyle(color: role == 'admin' ? Colors.red : Colors.blue, fontWeight: FontWeight.bold))
                          : null,
                    ),

                    // Tên & Role
                    title: Row(
                      children: [
                        Flexible(
                          child: Text(
                            name,
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isBanned ? Colors.grey : Colors.black,
                                decoration: isBanned ? TextDecoration.lineThrough : null
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (role == 'admin')
                          Container(
                            margin: const EdgeInsets.only(left: 5),
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(4)),
                            child: const Text("ADMIN", style: TextStyle(color: Colors.white, fontSize: 10)),
                          )
                      ],
                    ),

                    // Email & Vàng & UID
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(email, maxLines: 1, overflow: TextOverflow.ellipsis),
                        Row(
                          children: [
                            Text("💰 ${NumberFormatter.format(coin)}", style: TextStyle(color: Colors.amber[800], fontWeight: FontWeight.bold)),
                            const SizedBox(width: 10),
                            Text("ID: ${userId.substring(0, 5)}...", style: const TextStyle(fontSize: 10, color: Colors.grey)),
                          ],
                        )
                      ],
                    ),

                    isThreeLine: true,

                    // Menu thao tác
                    trailing: role == 'admin'
                        ? const Icon(Icons.shield, color: Colors.red)
                        : PopupMenuButton(
                      onSelected: (value) {
                        if (value == 'history') {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => HistoryScreen(userId: userId)));
                        }
                        if (value == 'ban') _toggleBan(userId, isBanned);
                        if (value == 'coin') _editCoin(userId, coin);
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'history',
                          child: Row(children: [Icon(Icons.history, color: Colors.purple), SizedBox(width: 8), Text("Xem lịch sử")]),
                        ),
                        PopupMenuItem(
                          value: 'ban',
                          child: Row(children: [
                            Icon(isBanned ? Icons.lock_open : Icons.block, color: isBanned ? Colors.green : Colors.red),
                            const SizedBox(width: 8),
                            Text(isBanned ? "Mở khóa nick" : "Khóa nick")
                          ]),
                        ),
                        const PopupMenuItem(
                          value: 'coin',
                          child: Row(children: [Icon(Icons.monetization_on, color: Colors.amber), SizedBox(width: 8), Text("Cộng/Trừ tiền")]),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}