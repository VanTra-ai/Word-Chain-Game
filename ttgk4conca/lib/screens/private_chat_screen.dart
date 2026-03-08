// lib/screens/private_chat_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:provider/provider.dart';

import '../main.dart';
import '../constants/app_colors.dart';
import '../widgets/sticker_keyboard.dart';
import '../widgets/chat_message_bubble.dart';
import '../widgets/user_profile_dialog.dart';

class PrivateChatScreen extends StatefulWidget {
  final String friendId;
  final String friendName;
  final String friendAvatar;

  const PrivateChatScreen({
    super.key,
    required this.friendId,
    required this.friendName,
    required this.friendAvatar,
  });

  @override
  State<PrivateChatScreen> createState() => _PrivateChatScreenState();
}

class _PrivateChatScreenState extends State<PrivateChatScreen> {
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  late DatabaseReference _chatRef;
  late String _roomId;

  bool _isShowSticker = false;
  bool _showScrollButton = false;

  @override
  void initState() {
    super.initState();
    final myId = Provider.of<AuthProvider>(context, listen: false).user!.uid;
    // Tạo RoomID duy nhất giữa 2 người
    if (myId.compareTo(widget.friendId) > 0) {
      _roomId = "${widget.friendId}_$myId";
    } else {
      _roomId = "${myId}_${widget.friendId}";
    }

    _chatRef = FirebaseDatabase.instance.ref('private_chats/$_roomId');

    _focusNode.addListener(() {
      if (_focusNode.hasFocus) setState(() => _isShowSticker = false);
    });

    _scrollController.addListener(() {
      if (_scrollController.offset > 300) {
        if (!_showScrollButton) setState(() => _showScrollButton = true);
      } else {
        if (_showScrollButton) setState(() => _showScrollButton = false);
      }
    });
  }

  @override
  void dispose() {
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
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    if (user == null) return;
    if ((text == null || text.trim().isEmpty) && stickerUrl == null) return;

    Map<String, dynamic> msgData = {
      'senderId': user.uid,
      'timestamp': ServerValue.timestamp,
    };
    if (stickerUrl != null) {
      msgData['type'] = 'stickers';
      msgData['text'] = stickerUrl;
    } else {
      msgData['type'] = 'text';
      msgData['text'] = text;
    }
    _chatRef.push().set(msgData);
    _msgController.clear();

    if (_scrollController.hasClients) {
      _scrollToBottom();
    }
  }

  // [ĐÃ THÊM] Hàm Helper hiển thị ảnh để fix lỗi ở AppBar
  ImageProvider _getAvatarProvider(String? url) {
    if (url != null && url.isNotEmpty) {
      if (url.startsWith('http')) return NetworkImage(url);
      return AssetImage(url);
    }
    return const AssetImage('assets/default_avatar.png');
  }

  String _getDateHeader(int timestamp) {
    DateTime date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    DateTime now = DateTime.now();

    if (date.year == now.year && date.month == now.month && date.day == now.day) {
      return "Hôm nay";
    }
    DateTime yesterday = now.subtract(const Duration(days: 1));
    if (date.year == yesterday.year && date.month == yesterday.month && date.day == yesterday.day) {
      return "Hôm qua";
    }
    return "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}";
  }

  Widget _buildDateHeader(String text) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(text, style: const TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.bold)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final myId = Provider.of<AuthProvider>(context).user?.uid;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            // Avatar trên AppBar (Bấm để xem Profile)
            GestureDetector(
              onTap: () {
                showDialog(
                    context: context,
                    builder: (_) => UserProfileDialog(targetUserId: widget.friendId)
                );
              },
              child: CircleAvatar(
                backgroundImage: _getAvatarProvider(widget.friendAvatar),
                radius: 16,
              ),
            ),
            const SizedBox(width: 10),
            Text(widget.friendName),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<DatabaseEvent>(
              stream: _chatRef.limitToLast(50).onValue,
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
                  return Center(child: Text("Hãy gửi lời chào tới ${widget.friendName}!", style: const TextStyle(color: Colors.grey)));
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
                      itemBuilder: (context, index) {
                        final msg = msgList[index].value;
                        final bool isMe = msg['senderId'] == myId;
                        int timestamp = msg['timestamp'] ?? DateTime.now().millisecondsSinceEpoch;

                        bool showDateHeader = false;
                        if (index == msgList.length - 1) {
                          showDateHeader = true;
                        } else {
                          final prevMsg = msgList[index + 1].value;
                          int prevTimestamp = prevMsg['timestamp'] ?? 0;
                          DateTime prevDate = DateTime.fromMillisecondsSinceEpoch(prevTimestamp);
                          DateTime currDate = DateTime.fromMillisecondsSinceEpoch(timestamp);
                          if (prevDate.day != currDate.day || prevDate.month != currDate.month || prevDate.year != currDate.year) {
                            showDateHeader = true;
                          }
                        }

                        String? type = msg['type'];
                        String? content = msg['text'];
                        String? stickerUrl;
                        String? textContent;

                        if (type == 'stickers') {
                          stickerUrl = content;
                        } else {
                          textContent = content;
                        }

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (showDateHeader) _buildDateHeader(_getDateHeader(timestamp)),

                            ChatMessageBubble(
                              isMe: isMe,
                              text: textContent,
                              stickerUrl: stickerUrl,
                              senderName: isMe ? null : widget.friendName,
                              avatarUrl: isMe ? null : widget.friendAvatar,
                              timestamp: timestamp,
                              // [ĐÃ THÊM] Truyền ID để bấm vào tin nhắn xem được Profile
                              senderId: msg['senderId'],
                            ),
                          ],
                        );
                      },
                    ),

                    if (_showScrollButton)
                      Positioned(
                        bottom: 10,
                        right: 10,
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

          // INPUT BAR
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
                    decoration: const InputDecoration(hintText: "Nhắn tin...", border: OutlineInputBorder()),
                    onSubmitted: (_) => _sendMessage(text: _msgController.text.trim()),
                  ),
                ),
                IconButton(
                  onPressed: () => _sendMessage(text: _msgController.text.trim()),
                  icon: const Icon(Icons.send, color: AppColors.primary),
                )
              ],
            ),
          ),
          if (_isShowSticker)
            StickerKeyboard(onStickerSelected: (url) => _sendMessage(stickerUrl: url)),
        ],
      ),
    );
  }
}