// lib/widgets/message_bubble.dart
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class MessageBubble extends StatelessWidget {
  final String word;
  final bool isPlayer; // true là người chơi, false là máy

  const MessageBubble({
    super.key,
    required this.word,
    required this.isPlayer,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isPlayer ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isPlayer ? AppColors.playerBubble : AppColors.botBubble,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(12),
            topRight: const Radius.circular(12),
            bottomLeft: isPlayer ? const Radius.circular(12) : const Radius.circular(0),
            bottomRight: isPlayer ? const Radius.circular(0) : const Radius.circular(12),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 5,
              offset: const Offset(0, 2),
            )
          ],
        ),
        child: Text(
          word,
          style: TextStyle(
            color: isPlayer ? AppColors.textLight : AppColors.textDark,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}