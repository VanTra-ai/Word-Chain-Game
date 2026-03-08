// lib/screens/lobby_screen.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // [MỚI] Cần import cái này để lấy info user
import 'package:provider/provider.dart';
import '../main.dart';
import '../constants/app_colors.dart';
import 'online_game_screen.dart';
import '../utils/toast_helper.dart'; // [MỚI] Import ToastHelper

class LobbyScreen extends StatefulWidget {
  const LobbyScreen({super.key});

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  final TextEditingController _roomController = TextEditingController();
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref('rooms');
  bool _isLoading = false;

  // --- [MỚI] LOGIC TÌM TRẬN NGẪU NHIÊN ---
  void _findRandomMatch() async {
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    if (user == null) return;

    // Hiển thị loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // 1. Lấy thông tin chi tiết user từ Firestore (Avatar, Tên...)
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final userData = userDoc.data();
      String userName = userData?['displayName'] ?? user.displayName ?? 'Người chơi';
      String userAvatar = userData?['photoURL'] ?? user.photoURL ?? '';

      // 2. Tìm phòng đang 'waiting'
      final snapshot = await _dbRef.orderByChild('status').equalTo('waiting').limitToFirst(1).get();

      String roomId;

      if (snapshot.exists && snapshot.children.isNotEmpty) {
        // === TRƯỜNG HỢP A: TÌM THẤY PHÒNG ===
        final room = snapshot.children.first;
        roomId = room.key!;

        // [MỚI] Lấy ID của chủ phòng từ dữ liệu Firebase tải về
        String hostId = room.child('host/id').value.toString();

        if (room.child('host/id').value == user.uid) {
          // Là phòng mình -> Vào lại làm host (Giữ nguyên)
        } else {
          // Vào làm GUEST
          await _dbRef.child(roomId).update({
            'guest': {
              'id': user.uid,
              'name': userName,
              'avatar': userAvatar,
              'score': 0
            },
            'status': 'playing',
            'currentTurn': hostId,
          });
        }
      } else {
        // === TRƯỜNG HỢP B: KHÔNG CÓ PHÒNG -> TẠO MỚI ===
        // Dùng push() để tạo ID dài ngẫu nhiên (tránh trùng lặp tốt hơn 4 số)
        final newRoomRef = _dbRef.push();
        roomId = newRoomRef.key!;

        await newRoomRef.set({
          'roomId': roomId,
          'status': 'waiting',
          'createdAt': ServerValue.timestamp,
          'host': {
            'id': user.uid,
            'name': userName,
            'avatar': userAvatar,
            'score': 0
          },
          'words': [],
          'currentTurn': user.uid,
        });
      }

      // Tắt loading
      if (mounted) Navigator.pop(context);

      // Chuyển sang màn hình Game
      if (mounted) {
        _goToGameScreen(roomId, user.uid);
      }

    } catch (e) {
      if (mounted) Navigator.pop(context); // Tắt loading nếu lỗi
      _showError("Lỗi tìm trận: $e");
    }
  }
  // ----------------------------------------

  // 1. Logic Tạo Phòng Mới (Thủ công)
  void _createRoom(BuildContext context) async {
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    if (user == null) return;

    setState(() => _isLoading = true);

    // Tạo mã phòng ngẫu nhiên 4 số (Ví dụ: 1234)
    String roomId = (1000 + Random().nextInt(9000)).toString();

    try {
      // [SỬA] Lấy thêm avatar từ Firestore cho đồng bộ
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final userData = userDoc.data();

      await _dbRef.child(roomId).set({
        'status': 'waiting',
        'host': {
          'id': user.uid,
          'name': userData?['displayName'] ?? user.displayName,
          'avatar': userData?['photoURL'] ?? user.photoURL,
        },
        'guest': null,
        'currentTurn': user.uid,
        'words': [],
        'createdAt': ServerValue.timestamp,
      });

      if (mounted) {
        _goToGameScreen(roomId, user.uid);
      }
    } catch (e) {
      _showError("Lỗi tạo phòng: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // 2. Logic Vào Phòng Có Sẵn
  void _joinRoom(BuildContext context) async {
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    if (user == null) return;

    String roomId = _roomController.text.trim();
    if (roomId.isEmpty || roomId.length != 4) {
      _showError("Vui lòng nhập mã phòng 4 số!");
      return;
    }

    setState(() => _isLoading = true);

    try {
      final snapshot = await _dbRef.child(roomId).get();

      if (snapshot.exists) {
        // [SỬA] Lấy thêm avatar từ Firestore
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        final userData = userDoc.data();

        // Kiểm tra xem phòng có đang chơi không
        if (snapshot.child('status').value == 'playing') {
          _showError("Phòng này đang chơi rồi!");
          return;
        }

        await _dbRef.child(roomId).update({
          'status': 'playing',
          'guest': {
            'id': user.uid,
            'name': userData?['displayName'] ?? user.displayName,
            'avatar': userData?['photoURL'] ?? user.photoURL,
          }
        });

        if (mounted) {
          _goToGameScreen(roomId, user.uid);
        }
      } else {
        _showError("Phòng không tồn tại!");
      }
    } catch (e) {
      _showError("Lỗi vào phòng: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _goToGameScreen(String roomId, String userId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OnlineGameScreen(roomId: roomId, currentUserId: userId),
      ),
    );
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Sảnh Chờ Online"), backgroundColor: AppColors.primary, foregroundColor: Colors.white),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: SingleChildScrollView( // Thêm Scroll tránh lỗi bàn phím che
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.public, size: 80, color: AppColors.primary),
              const SizedBox(height: 10),
              const Text("Thách đấu Online", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const Text("Chơi cùng bạn bè thời gian thực", style: TextStyle(color: Colors.grey)),

              const SizedBox(height: 40),

              // --- [MỚI] NÚT TÌM TRẬN NHANH ---
              SizedBox(
                width: double.infinity,
                height: 50, // To hơn chút cho nổi bật
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple, // Màu khác biệt
                    foregroundColor: Colors.white,
                    elevation: 5,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                  icon: const Icon(Icons.flash_on, size: 28),
                  label: const Text("TÌM TRẬN NHANH", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  onPressed: _isLoading ? null : _findRandomMatch, // Gọi hàm mới
                ),
              ),
              // --------------------------------

              const SizedBox(height: 20),
              const Row(children: [Expanded(child: Divider()), Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Text("HOẶC TẠO PHÒNG")), Expanded(child: Divider())]),
              const SizedBox(height: 20),

              // Nút Tạo Phòng
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                  icon: _isLoading ? const SizedBox.shrink() : const Icon(Icons.add),
                  label: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text("TẠO PHÒNG RIÊNG", style: TextStyle(fontSize: 16)),
                  onPressed: _isLoading ? null : () => _createRoom(context),
                ),
              ),

              const SizedBox(height: 20),
              const Text("Nhập mã phòng để vào:", style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 10),

              // Ô nhập mã phòng
              TextField(
                controller: _roomController,
                keyboardType: TextInputType.number,
                maxLength: 4,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 20, letterSpacing: 5, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  hintText: "VD: 1234",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  counterText: "",
                  contentPadding: const EdgeInsets.symmetric(vertical: 15),
                ),
              ),
              const SizedBox(height: 15),

              // Nút Vào Phòng
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.primary, width: 2)),
                  icon: const Icon(Icons.login),
                  label: const Text("VÀO PHÒNG NGAY", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  onPressed: _isLoading ? null : () => _joinRoom(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}