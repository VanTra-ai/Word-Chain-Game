// lib/widgets/game_controls.dart
import 'package:flutter/material.dart';
import '../utils/audio_manager.dart';

// 1. Nút bấm dạng khối (Thay thế ElevatedButton)
class GameButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final ButtonStyle? style;

  const GameButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      style: style,
      // Logic: Nếu onPressed là null (nút bị vô hiệu) thì giữ nguyên null
      // Nếu không, chèn thêm hàm phát nhạc trước khi thực hiện hành động
      onPressed: onPressed == null
          ? null
          : () {
        AudioManager().playSFX('button.mp3'); // Phát tiếng
        onPressed!(); // Chạy hành động chính
      },
      child: child,
    );
  }
}

// 2. Nút bấm dạng Icon (Thay thế IconButton)
class GameIconButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Icon icon;
  final Color? color;
  final String? tooltip;

  const GameIconButton({
    super.key,
    required this.onPressed,
    required this.icon,
    this.color,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: icon,
      color: color,
      tooltip: tooltip,
      onPressed: onPressed == null
          ? null
          : () {
        AudioManager().playSFX('button.mp3');
        onPressed!();
      },
    );
  }
}

// 3. Vùng chạm tùy chỉnh (Thay thế GestureDetector/InkWell cho Shop, Item...)
class GameTap extends StatelessWidget {
  final VoidCallback? onTap;
  final Widget child;
  final BorderRadius? borderRadius;

  const GameTap({
    super.key,
    required this.onTap,
    required this.child,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: borderRadius,
      onTap: onTap == null
          ? null
          : () {
        AudioManager().playSFX('button.mp3');
        onTap!();
      },
      child: child,
    );
  }
}