// lib/screens/world_chat_screen.dart
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../main.dart'; // AuthProvider
import '../constants/app_colors.dart';
import 'online_game_screen.dart';
import 'private_chat_screen.dart';
import '../widgets/sticker_keyboard.dart';
import '../widgets/chat_message_bubble.dart';
import '../widgets/user_profile_dialog.dart';

// --- HÀM HELPER: XỬ LÝ HIỂN THỊ ẢNH (QUAN TRỌNG) ---
ImageProvider _getAvatarProvider(String? url) {
  if (url != null && url.isNotEmpty) {
    // Nếu là link mạng (http...)
    if (url.startsWith('http')) {
      return NetworkImage(url);
    }
    return AssetImage(url);
  }

  // Nếu không có ảnh -> Trả về ảnh mặc định vừa thêm
  return const AssetImage('assets/default_avatar.png');
}

class WorldChatScreen extends StatelessWidget {
  const WorldChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Cộng đồng"),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.amber,
            tabs: [
              Tab(text: "Thế giới", icon: Icon(Icons.public)),
              Tab(text: "Bạn bè", icon: Icon(Icons.people_alt)),
            ],
          ),
          actions: [
            Builder(builder: (context) => IconButton(
              icon: const Icon(Icons.list),
              tooltip: "Người online",
              onPressed: () => Scaffold.of(context).openEndDrawer(),
            ))
          ],
        ),
        endDrawer: const _OnlineUsersDrawer(),
        body: const TabBarView(
          children: [
            _WorldChatTab(),
            _FriendsTab(),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// TAB 1: CHAT THẾ GIỚI (LIVE UPDATE)
// ============================================================================
class _WorldChatTab extends StatefulWidget {
  const _WorldChatTab();

  @override
  State<_WorldChatTab> createState() => _WorldChatTabState();
}

class _WorldChatTabState extends State<_WorldChatTab> {
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  final DatabaseReference _chatRef = FirebaseDatabase.instance.ref('world_chat');

  bool _isShowSticker = false;
  bool _showScrollButton = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (_focusNode.hasFocus) setState(() => _isShowSticker = false);
    });

    _scrollController.addListener(() {
      if (_scrollController.hasClients) {
        if (_scrollController.offset > 300) {
          if (!_showScrollButton) setState(() => _showScrollButton = true);
        } else {
          if (_showScrollButton) setState(() => _showScrollButton = false);
        }
      }
    });
  }

  @override
  void dispose() {
    _msgController.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _sendMessage({String? text, String? stickerUrl}) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;

    if (user == null) return;
    if ((text == null || text.trim().isEmpty) && stickerUrl == null) return;

    String currentAvatar = authProvider.customAvatar.isNotEmpty
        ? authProvider.customAvatar
        : (user.photoURL ?? "");

    _chatRef.push().set({
      'text': text,
      'stickerUrl': stickerUrl,
      'type': stickerUrl != null ? 'stickers' : 'text',
      'senderId': user.uid,
      'senderName': user.displayName ?? "Người lạ",
      'senderAvatar': currentAvatar,
      'timestamp': ServerValue.timestamp,
    });
    _msgController.clear();
    _scrollToBottom();
  }

  String _getDateHeader(int timestamp) {
    DateTime date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    DateTime now = DateTime.now();
    if (date.year == now.year && date.month == now.month && date.day == now.day) return "Hôm nay";
    return "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}";
  }

  Widget _buildDateHeader(String text) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(20)),
        child: Text(text, style: const TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.bold)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthProvider>(context).user;

    return Column(
      children: [
        Expanded(
          child: StreamBuilder<DatabaseEvent>(
            stream: _chatRef.limitToLast(50).onValue,
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
                return const Center(child: Text("Hãy nói xin chào với thế giới!", style: TextStyle(color: Colors.grey)));
              }
              final data = Map<String, dynamic>.from(snapshot.data!.snapshot.value as Map);

              var msgList = data.entries.toList()
                ..sort((a, b) => (b.value['timestamp'] ?? 0).compareTo(a.value['timestamp'] ?? 0));

              return Stack(
                children: [
                  ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(10),
                    reverse: true,
                    itemCount: msgList.length,
                    itemBuilder: (ctx, index) {
                      final msg = msgList[index].value;
                      bool isMe = msg['senderId'] == user?.uid;
                      int timestamp = msg['timestamp'] ?? DateTime.now().millisecondsSinceEpoch;
                      String senderId = msg['senderId'] ?? "";

                      bool showDateHeader = false;
                      if (index == msgList.length - 1) {
                        showDateHeader = true;
                      } else {
                        final prevMsg = msgList[index + 1].value;
                        DateTime prevDate = DateTime.fromMillisecondsSinceEpoch(prevMsg['timestamp'] ?? 0);
                        DateTime currDate = DateTime.fromMillisecondsSinceEpoch(timestamp);
                        if (prevDate.day != currDate.day || prevDate.month != currDate.month || prevDate.year != currDate.year) {
                          showDateHeader = true;
                        }
                      }

                      String? type = msg['type'];
                      String? textContent = msg['text'];
                      String? stickerContent = msg['stickerUrl'];
                      if (type == 'stickers' && (stickerContent == null || stickerContent.isEmpty)) {
                        stickerContent = textContent;
                        textContent = null;
                      }

                      // [STREAM LỒNG] Live update thông tin người gửi
                      return StreamBuilder<DocumentSnapshot>(
                          stream: isMe
                              ? null // Tin nhắn của mình dùng local data cho nhanh
                              : FirebaseFirestore.instance.collection('users').doc(senderId).snapshots(),
                          builder: (context, userSnap) {
                            String displayName;
                            String avatarToUse;

                            if (isMe) {
                              final myAuth = Provider.of<AuthProvider>(context, listen: false);
                              displayName = user?.displayName ?? "Tôi";
                              avatarToUse = myAuth.customAvatar.isNotEmpty
                                  ? myAuth.customAvatar
                                  : (user?.photoURL ?? "");
                            } else {
                              if (userSnap.hasData && userSnap.data != null && userSnap.data!.exists) {
                                final userData = userSnap.data!.data() as Map<String, dynamic>;
                                displayName = userData['displayName'] ?? "Người lạ";
                                avatarToUse = userData['currentAvatar'] ?? userData['photoURL'] ?? "";
                              } else {
                                displayName = msg['senderName'] ?? "Đang tải...";
                                avatarToUse = msg['senderAvatar'] ?? msg['avatar'] ?? "";
                              }
                            }

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (showDateHeader) _buildDateHeader(_getDateHeader(timestamp)),
                                ChatMessageBubble(
                                  isMe: isMe,
                                  text: textContent,
                                  stickerUrl: stickerContent,
                                  senderName: displayName,
                                  avatarUrl: avatarStrFromRaw(avatarToUse),
                                  timestamp: timestamp,
                                  senderId: msg['senderId'],
                                ),
                              ],
                            );
                          }
                      );
                    },
                  ),

                  if (_showScrollButton)
                    Positioned(
                      bottom: 10, right: 10,
                      child: FloatingActionButton.small(
                        backgroundColor: Colors.white,
                        elevation: 4,
                        onPressed: _scrollToBottom,
                        child: const Icon(Icons.keyboard_arrow_down, color: AppColors.primary),
                      ),
                    ),
                ],
              );
            },
          ),
        ),

        // --- INPUT BAR ---
        Container(
          padding: const EdgeInsets.all(8),
          color: Colors.white,
          child: Row(
            children: [
              IconButton(
                icon: Icon(_isShowSticker ? Icons.keyboard : Icons.emoji_emotions, color: Colors.amber),
                onPressed: () {
                  setState(() {
                    _isShowSticker = !_isShowSticker;
                    if (_isShowSticker) _focusNode.unfocus();
                    else _focusNode.requestFocus();
                  });
                },
              ),
              Expanded(
                child: TextField(
                  controller: _msgController,
                  focusNode: _focusNode,
                  decoration: const InputDecoration(hintText: "Chat thế giới...", border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10)),
                  onSubmitted: (_) => _sendMessage(text: _msgController.text.trim()),
                ),
              ),
              IconButton(
                  onPressed: () => _sendMessage(text: _msgController.text.trim()),
                  icon: const Icon(Icons.send, color: AppColors.primary)
              )
            ],
          ),
        ),
        if (_isShowSticker)
          StickerKeyboard(onStickerSelected: (url) => _sendMessage(stickerUrl: url)),
      ],
    );
  }

  String avatarStrFromRaw(String raw) {
    return raw;
  }
}

// ============================================================================
// TAB 2: DANH SÁCH BẠN BÈ (LIVE UPDATE)
// ============================================================================
class _FriendsTab extends StatefulWidget {
  const _FriendsTab();

  @override
  State<_FriendsTab> createState() => _FriendsTabState();
}

class _FriendsTabState extends State<_FriendsTab> {
  void _showAddFriendDialog() {
    final emailController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Thêm bạn bè"),
        content: TextField(
          controller: emailController,
          decoration: const InputDecoration(labelText: "Nhập Email bạn bè"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Hủy")),
          ElevatedButton(
            onPressed: () async {
              String email = emailController.text.trim();
              if (email.isEmpty) return;
              Navigator.pop(ctx);
              await _sendFriendRequest(email);
            },
            child: const Text("Gửi lời mời"),
          )
        ],
      ),
    );
  }

  Future<void> _sendFriendRequest(String email) async {
    final myAuth = Provider.of<AuthProvider>(context, listen: false);
    final myUser = myAuth.user;
    if (myUser == null) return;
    try {
      final query = await FirebaseFirestore.instance.collection('users').where('email', isEqualTo: email).limit(1).get();
      if (query.docs.isEmpty) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Không tìm thấy!")));
        return;
      }
      final friendDoc = query.docs.first;

      String myAvatar = myAuth.customAvatar.isNotEmpty ? myAuth.customAvatar : (myUser.photoURL ?? "");

      await FirebaseFirestore.instance.collection('users').doc(friendDoc.id).collection('friend_requests').doc(myUser.uid).set({
        'name': myUser.displayName ?? "Unknown",
        'avatar': myAvatar,
        'timestamp': FieldValue.serverTimestamp(),
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Đã gửi lời mời!"), backgroundColor: Colors.green));
    } catch(e) { print(e); }
  }

  Future<void> _acceptRequest(String friendId, String friendName, String friendAvatar) async {
    final myAuth = Provider.of<AuthProvider>(context, listen: false);
    final myUser = myAuth.user;
    if (myUser == null) return;

    String myAvatar = myAuth.customAvatar.isNotEmpty ? myAuth.customAvatar : (myUser.photoURL ?? "");

    try {
      // Lưu bạn bè vào danh sách của mình (với tên/ảnh mới nhất nhận được từ _LiveRequestTile)
      await FirebaseFirestore.instance.collection('users').doc(myUser.uid).collection('friends').doc(friendId).set({
        'name': friendName,
        'avatar': friendAvatar,
        'addedAt': FieldValue.serverTimestamp(),
      });

      // Lưu mình vào danh sách của họ
      await FirebaseFirestore.instance.collection('users').doc(friendId).collection('friends').doc(myUser.uid).set({
        'name': myUser.displayName,
        'avatar': myAvatar,
        'addedAt': FieldValue.serverTimestamp(),
      });

      // Xóa lời mời
      await FirebaseFirestore.instance.collection('users').doc(myUser.uid).collection('friend_requests').doc(friendId).delete();
    } catch (e) { print("Lỗi accept: $e"); }
  }

  Future<void> _declineRequest(String friendId) async {
    final myUser = Provider.of<AuthProvider>(context, listen: false).user;
    if (myUser != null) {
      await FirebaseFirestore.instance.collection('users').doc(myUser.uid).collection('friend_requests').doc(friendId).delete();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthProvider>(context).user;
    if (user == null) return const SizedBox.shrink();

    return Scaffold(
      backgroundColor: Colors.white,
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddFriendDialog,
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.person_add, color: Colors.white),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- PHẦN 1: DANH SÁCH LỜI MỜI (LIVE UPDATE) ---
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('users').doc(user.uid).collection('friend_requests').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const SizedBox.shrink();

                return Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      color: Colors.orange[50],
                      width: double.infinity,
                      child: const Text("📩 Lời mời kết bạn", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrange)),
                    ),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: snapshot.data!.docs.length,
                      itemBuilder: (ctx, index) {
                        final req = snapshot.data!.docs[index];
                        // Thay vì hiển thị trực tiếp, ta dùng Widget Live để fetch data mới nhất
                        return _LiveRequestTile(
                          requestId: req.id, // ID người gửi
                          onAccept: (name, avatar) => _acceptRequest(req.id, name, avatar),
                          onDecline: () => _declineRequest(req.id),
                        );
                      },
                    ),
                    const Divider(thickness: 5, color: Colors.grey),
                  ],
                );
              },
            ),

            // --- PHẦN 2: DANH SÁCH BẠN BÈ (ĐÃ LIVE UPDATE) ---
            Padding(padding: const EdgeInsets.all(16), child: const Text("Danh sách bạn bè", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('users').doc(user.uid).collection('friends').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final friends = snapshot.data!.docs;
                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: friends.length,
                  itemBuilder: (context, index) {
                    final friendId = friends[index].id;
                    return _LiveFriendTile(friendId: friendId); // Widget này đã có ở bài trước
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// [MỚI] WIDGET LỜI MỜI KẾT BẠN LIVE (CẬP NHẬT TÊN/ẢNH MỚI NHẤT)
// ============================================================================
class _LiveRequestTile extends StatelessWidget {
  final String requestId;
  final Function(String name, String avatar) onAccept;
  final VoidCallback onDecline;

  const _LiveRequestTile({
    required this.requestId,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    // Lắng nghe trực tiếp User gửi lời mời để lấy thông tin mới nhất
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(requestId).snapshots(),
      builder: (context, snapshot) {
        // Dữ liệu mặc định nếu chưa load xong hoặc lỗi
        String name = "Đang tải...";
        String avatarStr = "";

        if (snapshot.hasData && snapshot.data != null && snapshot.data!.exists) {
          final userData = snapshot.data!.data() as Map<String, dynamic>;
          name = userData['displayName'] ?? "Unknown";
          avatarStr = userData['currentAvatar'] ?? userData['photoURL'] ?? "";
        }

        return ListTile(
          leading: GestureDetector(
            onTap: () {
              showDialog(
                  context: context,
                  builder: (_) => UserProfileDialog(targetUserId: requestId)
              );
            },
            child: CircleAvatar(backgroundImage: _getAvatarProvider(avatarStr)),
          ),
          title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: const Text("Muốn kết bạn với bạn"),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.check_circle, color: Colors.green, size: 30),
                onPressed: () => onAccept(name, avatarStr), // Truyền info mới nhất để lưu vào friends
              ),
              IconButton(
                icon: const Icon(Icons.cancel, color: Colors.red, size: 30),
                onPressed: onDecline,
              ),
            ],
          ),
        );
      },
    );
  }
}

// ============================================================================
// WIDGET BẠN BÈ (LIVE STREAM)
// ============================================================================
class _LiveFriendTile extends StatelessWidget {
  final String friendId;

  const _LiveFriendTile({required this.friendId});

  void _inviteFriendToGame(BuildContext context, String friendId, String friendName) {
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    if (user == null) return;
    String roomId = (1000 + Random().nextInt(9000)).toString();
    FirebaseDatabase.instance.ref('invites/$friendId').set({
      'fromId': user.uid, 'fromName': user.displayName, 'roomId': roomId, 'timestamp': ServerValue.timestamp,
    });
    FirebaseDatabase.instance.ref('rooms/$roomId').set({
      'status': 'waiting', 'host': {'id': user.uid}, 'currentTurn': user.uid, 'words': [],
    });
    Navigator.push(context, MaterialPageRoute(builder: (_) => OnlineGameScreen(roomId: roomId, currentUserId: user.uid)));
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(friendId).snapshots(),
      builder: (context, userSnap) {
        if (!userSnap.hasData) return const SizedBox.shrink();

        final userData = userSnap.data!.data() as Map<String, dynamic>?;
        if (userData == null) return const SizedBox.shrink();

        String name = userData['displayName'] ?? "Unknown";
        String currentAvatar = userData['currentAvatar'] ?? "";
        String photoUrl = userData['photoURL'] ?? "";

        ImageProvider avatarImg;
        if (currentAvatar.isNotEmpty) {
          avatarImg = currentAvatar.startsWith('http') ? NetworkImage(currentAvatar) : AssetImage(currentAvatar);
        } else if (photoUrl.isNotEmpty) {
          avatarImg = NetworkImage(photoUrl);
        } else {
          avatarImg = const AssetImage('assets/default_avatar.png');
        }

        return StreamBuilder<DatabaseEvent>(
          stream: FirebaseDatabase.instance.ref('status/$friendId').onValue,
          builder: (context, statusSnap) {
            String status = 'offline';
            if (statusSnap.hasData && statusSnap.data!.snapshot.value != null) {
              final val = Map<String, dynamic>.from(statusSnap.data!.snapshot.value as Map);
              status = val['state'] ?? 'offline';
            }
            Color statusColor = status == 'online' ? Colors.green : (status == 'playing' ? Colors.orange : Colors.grey);

            return ListTile(
              leading: GestureDetector(
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (_) => UserProfileDialog(targetUserId: friendId),
                  );
                },
                child: Stack(
                  children: [
                    CircleAvatar(backgroundImage: avatarImg),
                    Positioned(
                      right: 0, bottom: 0,
                      child: Container(width: 12, height: 12, decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2))),
                    )
                  ],
                ),
              ),
              title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(status == 'online' ? "Online" : "Offline", style: TextStyle(color: statusColor, fontSize: 12)),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (status == 'online')
                    IconButton(icon: const Icon(Icons.sports_esports, color: Colors.red), onPressed: () => _inviteFriendToGame(context, friendId, name)),
                  IconButton(
                    icon: const Icon(Icons.chat_bubble_outline, color: AppColors.primary),
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => PrivateChatScreen(
                          friendId: friendId,
                          friendName: name,
                          friendAvatar: currentAvatar.isNotEmpty ? currentAvatar : photoUrl
                      )));
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// ============================================================================
// DRAWER ONLINE (LIVE STREAM)
// ============================================================================
class _OnlineUsersDrawer extends StatelessWidget {
  const _OnlineUsersDrawer();

  // Hàm mời chơi
  void _invitePlayer(BuildContext context, String targetUserId, String targetName) {
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    if (user == null) return;

    Navigator.of(context).pop(); // Đóng Drawer

    String roomId = (1000 + Random().nextInt(9000)).toString();

    // [QUAN TRỌNG] Dùng .push() để tạo ID mới cho lời mời
    FirebaseDatabase.instance.ref('invites/$targetUserId').push().set({
      'fromId': user.uid,
      'fromName': user.displayName ?? "Người lạ",
      'roomId': roomId,
      'timestamp': ServerValue.timestamp,
    });

    // Tạo phòng
    FirebaseDatabase.instance.ref('rooms/$roomId').set({
      'status': 'waiting',
      'host': {'id': user.uid, 'name': user.displayName, 'avatar': user.photoURL},
      'currentTurn': user.uid,
      'words': [],
    });

    Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => OnlineGameScreen(roomId: roomId, currentUserId: user.uid))
    );
  }

  // Hàm gửi kết bạn
  Future<void> _sendFriendRequest(BuildContext context, String targetUid) async {
    final myAuth = Provider.of<AuthProvider>(context, listen: false);
    final myUser = myAuth.user;
    if (myUser == null) return;

    // Check xem đã gửi chưa (để tránh spam, dù UI đã chặn)
    final existingReq = await FirebaseFirestore.instance.collection('users').doc(targetUid).collection('friend_requests').doc(myUser.uid).get();
    if (existingReq.exists) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Đã gửi lời mời rồi, hãy chờ họ đồng ý!")));
      return;
    }

    String myAvatar = myAuth.customAvatar.isNotEmpty ? myAuth.customAvatar : (myUser.photoURL ?? "");

    await FirebaseFirestore.instance.collection('users').doc(targetUid).collection('friend_requests').doc(myUser.uid).set({
      'name': myUser.displayName ?? "Unknown",
      'avatar': myAvatar,
      'timestamp': FieldValue.serverTimestamp(),
    });

    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Đã gửi lời mời!"), backgroundColor: Colors.green));
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthProvider>(context).user;
    final statusRef = FirebaseDatabase.instance.ref('status');

    return Drawer(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.only(top: 50, bottom: 20),
            color: AppColors.primary,
            width: double.infinity,
            child: const Text("Người chơi Online", textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: user == null ? const SizedBox() :
            StreamBuilder<DatabaseEvent>(
              stream: statusRef.orderByChild('last_changed').limitToLast(20).onValue,
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data!.snapshot.value == null) return const Center(child: Text("Vắng vẻ quá..."));

                final data = Map<String, dynamic>.from(snapshot.data!.snapshot.value as Map);
                // Lọc bỏ bản thân và người offline
                final activeUserIds = data.entries
                    .where((e) => e.key != user.uid && (e.value as Map)['state'] != 'offline')
                    .map((e) => e.key)
                    .toList();

                if (activeUserIds.isEmpty) return const Center(child: Text("Không có ai online :("));

                return ListView.builder(
                  itemCount: activeUserIds.length,
                  itemBuilder: (context, index) {
                    final uid = activeUserIds[index];

                    // Truyền các hàm callback xuống widget con
                    return _LiveDrawerItem(
                      uid: uid,
                      myUid: user.uid,
                      onInvite: (targetId, name) => _invitePlayer(context, targetId, name),
                      onAddFriend: (targetId) => _sendFriendRequest(context, targetId),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveDrawerItem extends StatelessWidget {
  final String uid;
  final String myUid;
  final Function(String, String) onInvite;
  final Function(String) onAddFriend;

  const _LiveDrawerItem({
    required this.uid,
    required this.myUid,
    required this.onInvite,
    required this.onAddFriend,
  });

  @override
  Widget build(BuildContext context) {
    // 1. Lấy thông tin User
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        final userData = snapshot.data!.data() as Map<String, dynamic>?;
        if (userData == null) return const SizedBox.shrink();

        String name = userData['displayName'] ?? "Unknown";
        String currentAvatar = userData['currentAvatar'] ?? "";
        String photoUrl = userData['photoURL'] ?? "";

        ImageProvider avatarImg;
        if (currentAvatar.isNotEmpty) {
          avatarImg = currentAvatar.startsWith('http') ? NetworkImage(currentAvatar) : AssetImage(currentAvatar);
        } else if (photoUrl.isNotEmpty) {
          avatarImg = NetworkImage(photoUrl);
        } else {
          avatarImg = const AssetImage('assets/default_avatar.png');
        }

        // 2. Check xem đã là bạn chưa
        return StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('users').doc(myUid).collection('friends').doc(uid).snapshots(),
            builder: (context, friendSnap) {
              bool isFriend = friendSnap.hasData && friendSnap.data!.exists;

              // 3. [MỚI] Check xem mình đã gửi lời mời chưa (để hiện trạng thái "Đã gửi")
              return StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance.collection('users').doc(uid).collection('friend_requests').doc(myUid).snapshots(),
                  builder: (context, reqSnap) {
                    bool isRequestSent = reqSnap.hasData && reqSnap.data!.exists;

                    return ListTile(
                      leading: GestureDetector(
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (_) => UserProfileDialog(targetUserId: uid),
                          );
                        },
                        child: Stack(
                          children: [
                            CircleAvatar(backgroundImage: avatarImg),
                            const Positioned(right: 0, bottom: 0, child: Icon(Icons.circle, color: Colors.green, size: 12))
                          ],
                        ),
                      ),
                      title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Nút Kết bạn (Xử lý 3 trạng thái)
                          if (isFriend)
                            const Padding(padding: EdgeInsets.all(8.0), child: Icon(Icons.people, color: Colors.green)) // Đã là bạn
                          else if (isRequestSent)
                            const Padding(padding: EdgeInsets.all(8.0), child: Icon(Icons.hourglass_empty, color: Colors.grey)) // Đã gửi, chờ duyệt
                          else
                            IconButton(
                              icon: const Icon(Icons.person_add, color: Colors.blue),
                              tooltip: "Kết bạn",
                              onPressed: () => onAddFriend(uid),
                            ),

                          // Nút Thách đấu (Luôn hiện)
                          IconButton(
                            icon: const Icon(Icons.sports_esports, color: Colors.red),
                            tooltip: "Thách đấu",
                            onPressed: () => onInvite(uid, name),
                          ),
                        ],
                      ),
                    );
                  }
              );
            }
        );
      },
    );
  }
}