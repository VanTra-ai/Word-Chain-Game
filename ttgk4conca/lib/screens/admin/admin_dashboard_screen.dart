// lib/screens/admin/admin_dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:provider/provider.dart';

import '../../main.dart'; // AuthProvider
import '../../services/history_service.dart';
import '../history_screen.dart';

// Import các Tab đã tách
import 'gift_code_tab.dart';
import 'dictionary_tab.dart';
import 'user_list_tab.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  @override
  void initState() {
    super.initState();
    _checkPermission();
  }

  void _checkPermission() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.user == null) {
      if (mounted) Navigator.pop(context);
      return;
    }

    final doc = await FirebaseFirestore.instance.collection('users').doc(auth.user!.uid).get();
    final role = doc.data()?['role'];

    if (role != 'admin') {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Truy cập bị từ chối! Bạn không phải Admin."), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("ADMIN DASHBOARD", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.red[900],
        foregroundColor: Colors.white,
      ),
      body: DefaultTabController(
        length: 4,
        child: Column(
          children: [
            const TabBar(
              labelColor: Colors.red,
              indicatorColor: Colors.red,
              tabs: [
                Tab(icon: Icon(Icons.people), text: "Người chơi"),
                Tab(icon: Icon(Icons.menu_book), text: "Từ điển"),
                Tab(icon: Icon(Icons.card_giftcard), text: "Giftcode"),
                Tab(icon: Icon(Icons.analytics), text: "Thống kê"),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  const UserListTab(),
                  const DictionaryTab(),
                  const GiftCodeTab(),
                  const StatsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
// [ĐÃ XÓA] Các hàm _toggleBan và _editCoin thừa ở đây
}

// --- TAB 3: THỐNG KÊ (Giữ nguyên class StatsTab bên dưới) ---
class StatsTab extends StatelessWidget {
  // ... Code StatsTab giữ nguyên như bạn đã gửi ...
  const StatsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // 1. Tổng người chơi
          _buildFirestoreStatCard(
              "Tổng Người Chơi",
              FirebaseFirestore.instance.collection('users').count(),
              Icons.people,
              Colors.blue
          ),
          const SizedBox(height: 16),

          // 2. Phòng Đang Chơi
          _buildRealtimeDBStatCard(
              "Phòng Đang Chơi",
              FirebaseDatabase.instance.ref('rooms'),
              Icons.sports_esports,
              Colors.orange
          ),
          const SizedBox(height: 16),

          // 3. Từ điển
          _buildFirestoreStatCard(
              "Từ Điển Bổ Sung",
              FirebaseFirestore.instance.collection('new_words').count(),
              Icons.menu_book,
              Colors.green
          ),
        ],
      ),
    );
  }

  // Widget đếm cho Firestore
  Widget _buildFirestoreStatCard(String title, AggregateQuery query, IconData icon, Color color) {
    return FutureBuilder<AggregateQuerySnapshot>(
      future: query.get(),
      builder: (context, snapshot) {
        String count = snapshot.hasData ? "${snapshot.data!.count}" : "...";
        return _cardDesign(title, count, icon, color);
      },
    );
  }

  // Widget đếm cho Realtime Database
  Widget _buildRealtimeDBStatCard(String title, var query, IconData icon, Color color) {
    return StreamBuilder<DatabaseEvent>(
      stream: query.onValue,
      builder: (context, snapshot) {
        String count = "...";
        if (snapshot.hasData && snapshot.data!.snapshot.value != null) {
          final data = snapshot.data!.snapshot.value as Map;
          int playingCount = 0;
          data.forEach((key, value) {
            if (value['status'] == 'playing') {
              playingCount++;
            }
          });
          count = "$playingCount";
        } else if (snapshot.hasData && snapshot.data!.snapshot.value == null) {
          count = "0";
        }
        return _cardDesign(title, count, icon, color);
      },
    );
  }

  // Thiết kế thẻ chung
  Widget _cardDesign(String title, String count, IconData icon, Color color) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          gradient: LinearGradient(colors: [color.withOpacity(0.8), color], begin: Alignment.topLeft, end: Alignment.bottomRight),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(count, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 5),
                Text(title, style: const TextStyle(fontSize: 16, color: Colors.white70)),
              ],
            ),
            Icon(icon, size: 50, color: Colors.white24),
          ],
        ),
      ),
    );
  }
}