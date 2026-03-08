// lib/screens/group_lobby_screen.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../constants/app_colors.dart';
import 'group_game_screen.dart';
import '../utils/toast_helper.dart';

class GroupLobbyScreen extends StatefulWidget {
  const GroupLobbyScreen({super.key});

  @override
  State<GroupLobbyScreen> createState() => _GroupLobbyScreenState();
}

class _GroupLobbyScreenState extends State<GroupLobbyScreen> {
  final TextEditingController _roomController = TextEditingController();
  final DatabaseReference _roomRef = FirebaseDatabase.instance.ref('group_rooms');

  String? _currentRoomId;
  bool _isHost = false;
  bool _isJoinValid = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _roomController.addListener(() {
      final code = _roomController.text.trim();
      setState(() {
        _isJoinValid = code.length == 5;
      });
    });
  }

  @override
  void dispose() {
    _roomController.dispose();
    super.dispose();
  }

  // --- HÀM HELPER: LẤY THÔNG TIN USER CHUẨN (Ưu tiên currentAvatar) ---
  Future<Map<String, String>> _getUserInfo(String uid) async {
    final user = Provider.of<AuthProvider>(context, listen: false).user;

    // 1. Lấy dữ liệu từ Firestore mới nhất
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final userData = userDoc.data();

    // 2. Xử lý Tên (Ưu tiên Firestore -> Auth -> Unknown)
    String name = userData?['displayName'] ?? user?.displayName ?? "Unknown";

    // 3. [QUAN TRỌNG] Xử lý Avatar (Ưu tiên Custom Asset -> Google Photo -> Default)
    String avatar = "";
    if (userData != null && userData['currentAvatar'] != null && userData['currentAvatar'].toString().isNotEmpty) {
      avatar = userData['currentAvatar']; // Dùng ảnh Asset mới mua
    } else {
      avatar = userData?['photoURL'] ?? user?.photoURL ?? ""; // Dùng ảnh Google cũ
    }

    return {'name': name, 'avatar': avatar};
  }

  // --- [FIX] TÌM TRẬN NGẪU NHIÊN THÔNG MINH ---
  void _findRandomGroupMatch() async {
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    if (user == null) return;

    setState(() => _isLoading = true);

    try {
      // [FIX] Dùng hàm helper mới để lấy đúng Avatar
      final userInfo = await _getUserInfo(user.uid);
      String name = userInfo['name']!;
      String avatar = userInfo['avatar']!;

      // Tìm phòng đang waiting
      final snapshot = await _roomRef.orderByChild('status').equalTo('waiting').limitToFirst(10).get();
      String? foundRoomId;
      bool needHost = false;

      if (snapshot.exists) {
        for (final child in snapshot.children) {
          final roomData = child.value as Map;
          final players = roomData['players'] as Map? ?? {};

          final hostId = roomData['hostId'];
          final isHostActive = players.containsKey(hostId);

          if (players.length < 6) {
            foundRoomId = child.key;
            if (hostId == null || !isHostActive) {
              needHost = true;
            }
            break;
          }
        }
      }

      if (foundRoomId != null) {
        // Vào phòng tìm được
        Map<String, Object> updateData = {
          'players/${user.uid}': {
            'id': user.uid,
            'name': name,
            'avatar': avatar, // Đã là ảnh mới
            'score': 0,
            'status': 'ready'
          }
        };
        if (needHost) {
          updateData['hostId'] = user.uid;
        }

        // Thiết lập tự xóa khi mất kết nối
        await _roomRef.child('$foundRoomId/players/${user.uid}').onDisconnect().remove();
        if (needHost) {
          await _roomRef.child(foundRoomId).onDisconnect().remove();
        }

        await _roomRef.child(foundRoomId).update(updateData);

        setState(() {
          _currentRoomId = foundRoomId;
          _isHost = needHost;
          _isLoading = false;
        });

      } else {
        _createRoom();
      }

    } catch (e) {
      setState(() => _isLoading = false);
      ToastHelper.show(context, "Lỗi tìm trận: $e", isError: true);
    }
  }

  // 1. TẠO PHÒNG MỚI
  void _createRoom() async {
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    if (user == null) return;

    setState(() => _isLoading = true);
    String roomId = (10000 + Random().nextInt(90000)).toString();

    try {
      // [FIX] Dùng hàm helper để lấy Avatar chuẩn
      final userInfo = await _getUserInfo(user.uid);

      // Thiết lập tự hủy
      await _roomRef.child(roomId).onDisconnect().remove();

      await _roomRef.child(roomId).set({
        'status': 'waiting',
        'hostId': user.uid,
        'round': 1,
        'currentWord': 'bắt đầu',
        'players': {
          user.uid: {
            'id': user.uid,
            'name': userInfo['name'],
            'avatar': userInfo['avatar'], // Ảnh mới
            'score': 0,
            'status': 'ready'
          }
        },
        'createdAt': ServerValue.timestamp,
      });

      setState(() {
        _currentRoomId = roomId;
        _isHost = true;
        _isLoading = false;
      });

    } catch (e) {
      setState(() => _isLoading = false);
      ToastHelper.show(context, "Lỗi tạo phòng: $e", isError: true);
    }
  }

  // 2. VÀO PHÒNG BẰNG MÃ
  void _joinRoom() async {
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    String roomId = _roomController.text.trim();

    if (user == null) return;
    if (roomId.length != 5) {
      ToastHelper.show(context, "Mã phòng phải có 5 số!", isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final snapshot = await _roomRef.child(roomId).get();

      if (snapshot.exists) {
        final data = Map<String, dynamic>.from(snapshot.value as Map);

        if (data['status'] != 'waiting') {
          ToastHelper.show(context, "Trận đấu đang diễn ra/kết thúc!", isError: true);
          setState(() => _isLoading = false);
          return;
        }

        Map players = data['players'] ?? {};
        if (players.length >= 6) {
          ToastHelper.show(context, "Phòng đã đầy!", isError: true);
          setState(() => _isLoading = false);
          return;
        }

        // [FIX] Dùng hàm helper lấy Avatar chuẩn
        final userInfo = await _getUserInfo(user.uid);

        await _roomRef.child('$roomId/players/${user.uid}').onDisconnect().remove();

        await _roomRef.child('$roomId/players/${user.uid}').set({
          'id': user.uid,
          'name': userInfo['name'],
          'avatar': userInfo['avatar'], // Ảnh mới
          'score': 0,
          'status': 'ready'
        });

        setState(() {
          _currentRoomId = roomId;
          _isHost = false;
          _isLoading = false;
        });

      } else {
        ToastHelper.show(context, "Phòng không tồn tại!", isError: true);
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ToastHelper.show(context, "Lỗi vào phòng: $e", isError: true);
    }
  }

  void _startGame() {
    if (_currentRoomId != null && _isHost) {
      _roomRef.child(_currentRoomId!).update({
        'status': 'playing',
        'round': 1,
        'startTime': ServerValue.timestamp,
      });
    }
  }

  void _leaveRoom() async {
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    if (_currentRoomId != null && user != null) {

      if (_isHost) {
        await _roomRef.child(_currentRoomId!).remove();
      } else {
        await _roomRef.child('$_currentRoomId/players/${user.uid}').remove();
        await _roomRef.child('$_currentRoomId/players/${user.uid}').onDisconnect().cancel();
      }

      if (mounted) {
        setState(() {
          _currentRoomId = null;
          _isHost = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentRoomId != null) {
      return _buildWaitingRoom();
    }

    // Giao diện Lobby chính (Giữ nguyên, chỉ gọi hàm mới)
    return Scaffold(
      appBar: AppBar(title: const Text("Đấu Trường Nhóm"), backgroundColor: Colors.deepPurple, foregroundColor: Colors.white),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.groups, size: 80, color: Colors.deepPurple),
              const SizedBox(height: 20),
              const Text("Đấu Trường Từ Vựng", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const Text("Thi đấu cùng nhiều người chơi khác", style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 40),

              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange[700],
                    foregroundColor: Colors.white,
                    elevation: 5,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                  onPressed: _isLoading ? null : _findRandomGroupMatch,
                  icon: _isLoading ? const SizedBox.shrink() : const Icon(Icons.flash_on, size: 28),
                  label: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("TÌM TRẬN NHANH (NHÓM)", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),

              const SizedBox(height: 20),
              const Row(children: [Expanded(child: Divider()), Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Text("HOẶC TẠO PHÒNG")), Expanded(child: Divider())]),
              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white),
                  onPressed: _isLoading ? null : _createRoom,
                  icon: const Icon(Icons.add),
                  label: const Text("TẠO PHÒNG MỚI", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 20),

              TextField(
                controller: _roomController,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 20, letterSpacing: 5, fontWeight: FontWeight.bold),
                decoration: const InputDecoration(hintText: "VD: 12345", border: OutlineInputBorder(), prefixIcon: Icon(Icons.vpn_key)),
                keyboardType: TextInputType.number,
                maxLength: 5,
              ),
              const SizedBox(height: 10),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isJoinValid ? Colors.green : Colors.grey[400],
                    foregroundColor: Colors.white,
                  ),
                  onPressed: (_isJoinValid && !_isLoading) ? _joinRoom : null,
                  icon: const Icon(Icons.login),
                  label: const Text("VÀO PHÒNG NGAY", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWaitingRoom() {
    return WillPopScope(
      onWillPop: () async { _leaveRoom(); return false; },
      child: Scaffold(
        appBar: AppBar(
          title: Text("Phòng: $_currentRoomId"),
          backgroundColor: Colors.orange[800],
          foregroundColor: Colors.white,
          leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: _leaveRoom),
        ),
        body: StreamBuilder<DatabaseEvent>(
          stream: _roomRef.child(_currentRoomId!).onValue,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

            if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  setState(() { _currentRoomId = null; _isHost = false; });
                  ToastHelper.show(context, "Phòng đã bị giải tán!", isError: true);
                }
              });
              return const Center(child: Text("Đang rời phòng..."));
            }

            final data = Map<String, dynamic>.from(snapshot.data!.snapshot.value as Map);
            final playersMap = Map<String, dynamic>.from(data['players'] ?? {});
            final playersList = playersMap.values.toList();

            final currentUserId = Provider.of<AuthProvider>(context, listen: false).user?.uid;
            bool amIHost = data['hostId'] == currentUserId;

            if (_isHost != amIHost) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if(mounted) setState(() => _isHost = amIHost);
              });
            }

            if (data['status'] == 'playing') {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => GroupGameScreen(
                        roomId: _currentRoomId!,
                        currentUserId: currentUserId!,
                        isHost: amIHost,
                      ))
                  );
                }
              });
            }

            return Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  color: Colors.orange[50],
                  width: double.infinity,
                  child: Column(
                    children: [
                      const Text("Đang chờ người chơi...", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange)),
                      const SizedBox(height: 10),
                      Text("${playersList.length}/6 Người chơi", style: const TextStyle(fontSize: 16)),
                      const SizedBox(height: 5),
                      Text("Mã phòng: $_currentRoomId", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 2)),
                    ],
                  ),
                ),
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.all(20),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2, childAspectRatio: 3/2, crossAxisSpacing: 10, mainAxisSpacing: 10
                    ),
                    itemCount: playersList.length,
                    itemBuilder: (context, index) {
                      final p = playersList[index];
                      // Xử lý hiển thị Avatar: Nếu là asset (không có http) thì dùng AssetImage
                      ImageProvider avatarImg;
                      String avtStr = p['avatar'] ?? "";
                      if (avtStr.isNotEmpty && !avtStr.startsWith('http')) {
                        avatarImg = AssetImage(avtStr);
                      } else if (avtStr.startsWith('http')) {
                        avatarImg = NetworkImage(avtStr);
                      } else {
                        avatarImg = const AssetImage('assets/default_avatar.png');
                      }

                      return Card(
                        elevation: 3,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircleAvatar(
                              backgroundImage: avatarImg,
                              radius: 25,
                            ),
                            const SizedBox(height: 8),
                            Text(p['name'], style: const TextStyle(fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                            if (p['id'] == data['hostId']) const Text("(Chủ phòng)", style: TextStyle(color: Colors.red, fontSize: 10)),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                if (amIHost)
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: SizedBox(
                      width: double.infinity, height: 55,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: playersList.length >= 2 ? Colors.redAccent : Colors.grey, foregroundColor: Colors.white),
                        onPressed: playersList.length >= 2 ? _startGame : null,
                        child: Text(playersList.length < 2 ? "Cần tối thiểu 2 người" : "BẮT ĐẦU NGAY 🚀", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                if (!amIHost)
                  const Padding(padding: EdgeInsets.all(20), child: Text("Chờ chủ phòng bắt đầu...", style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey))),
              ],
            );
          },
        ),
      ),
    );
  }
}