// lib/widgets/sticker_keyboard.dart
import 'package:flutter/material.dart';
import '../constants/app_stickers.dart';

class StickerKeyboard extends StatelessWidget {
  final Function(String) onStickerSelected;

  const StickerKeyboard({super.key, required this.onStickerSelected});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 250,
      color: Colors.grey[200],
      padding: const EdgeInsets.all(10),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        ),
        itemCount: AppStickers.list.length,
        itemBuilder: (context, index) {
          final String path = AppStickers.list[index];

          // [QUAN TRỌNG] Kiểm tra xem đường dẫn là Online hay Offline
          bool isNetworkImage = path.startsWith('http');

          return GestureDetector(
            onTap: () => onStickerSelected(path),
            child: isNetworkImage
                ? Image.network( // Nếu là link online
              path,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, color: Colors.grey),
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return const Center(child: CircularProgressIndicator(strokeWidth: 2));
              },
            )
                : Image.asset( // Nếu là file asset
              path,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => const Icon(Icons.image_not_supported, color: Colors.grey),
            ),
          );
        },
      ),
    );
  }
}