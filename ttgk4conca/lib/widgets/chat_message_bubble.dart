// lib/widgets/chat_message_bubble.dart
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../constants/app_colors.dart';
import '../widgets/user_profile_dialog.dart'; // [MỚI] Import để hiển thị Dialog

class ChatMessageBubble extends StatelessWidget {
  final bool isMe;
  final String? text;
  final String? stickerUrl;
  final String? senderName;
  final String? avatarUrl;
  final int timestamp;
  final String? senderId; // [MỚI] Thêm ID người gửi để tra cứu thông tin

  const ChatMessageBubble({
    super.key,
    required this.isMe,
    this.text,
    this.stickerUrl,
    this.senderName,
    this.avatarUrl,
    required this.timestamp,
    this.senderId, // [MỚI] Nhận ID từ bên ngoài
  });

  String _formatTime(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return "$hour:$minute";
  }

  bool _isSticker(String? content) {
    if (content == null) return false;
    if (content.startsWith('http') &&
        (content.endsWith('.png') || content.endsWith('.jpg') || content.endsWith('.gif'))) {
      return true;
    }
    if (content.startsWith('assets/')) {
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final timeStr = _formatTime(timestamp);
    String displayContent = text ?? "";
    if (stickerUrl != null && stickerUrl!.isNotEmpty) {
      displayContent = stickerUrl!;
    }

    bool isContentSticker = _isSticker(displayContent);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. AVATAR (CHỈ HIỆN KHI KHÔNG PHẢI LÀ MÌNH)
          if (!isMe) ...[
            // [MỚI] Bọc Avatar bằng GestureDetector
            GestureDetector(
              onTap: () {
                if (senderId != null) {
                  showDialog(
                    context: context,
                    builder: (_) => UserProfileDialog(targetUserId: senderId!),
                  );
                }
              },
              child: CircleAvatar(
                radius: 18,
                backgroundImage: (avatarUrl != null && avatarUrl!.isNotEmpty)
                    ? NetworkImage(avatarUrl!)
                    : null,
                child: (avatarUrl == null || avatarUrl!.isEmpty)
                    ? const Icon(Icons.person, size: 18)
                    : null,
              ),
            ),
            const SizedBox(width: 8),
          ],

          // 2. NỘI DUNG CHAT
          Flexible(
            child: Column(
              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                // A. TÊN NGƯỜI GỬI (BẤM VÀO CŨNG HIỆN PROFILE LUÔN CHO TIỆN)
                if (!isMe && senderName != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4, left: 4),
                    child: GestureDetector( // [MỚI] Bọc cả tên người gửi
                      onTap: () {
                        if (senderId != null) {
                          showDialog(
                            context: context,
                            builder: (_) => UserProfileDialog(targetUserId: senderId!),
                          );
                        }
                      },
                      child: Text(
                        senderName!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.blueGrey,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                // B. HIỂN THỊ NỘI DUNG
                if (isContentSticker)
                  _buildStickerImage(context, displayContent)
                else
                  _buildTextBubble(displayContent),

                // C. THỜI GIAN
                Padding(
                  padding: const EdgeInsets.only(top: 2, right: 4, left: 4),
                  child: Text(
                    timeStr,
                    style: TextStyle(fontSize: 10, color: Colors.grey[600], fontStyle: FontStyle.italic),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextBubble(String content) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isMe ? Colors.blue[100] : Colors.grey[200],
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(12),
          topRight: const Radius.circular(12),
          bottomLeft: isMe ? const Radius.circular(12) : const Radius.circular(0),
          bottomRight: isMe ? const Radius.circular(0) : const Radius.circular(12),
        ),
      ),
      child: Text(
        content,
        style: const TextStyle(fontSize: 16, color: Colors.black87),
      ),
    );
  }

  Widget _buildStickerImage(BuildContext context, String url) {
    const double size = 120;
    if (url.startsWith('http')) {
      return Container(
        margin: const EdgeInsets.only(bottom: 2),
        height: size,
        width: size,
        child: CachedNetworkImage(
          imageUrl: url,
          fit: BoxFit.contain,
          placeholder: (context, url) => const Padding(
            padding: EdgeInsets.all(40.0),
            child: CircularProgressIndicator(),
          ),
          errorWidget: (context, url, error) => const Icon(Icons.broken_image, size: 50, color: Colors.grey),
        ),
      );
    } else {
      return Container(
        margin: const EdgeInsets.only(bottom: 2),
        height: size,
        width: size,
        child: Image.asset(
          url,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => const Icon(Icons.image_not_supported, size: 50, color: Colors.grey),
        ),
      );
    }
  }
}