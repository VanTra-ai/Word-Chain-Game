// lib/constants/game_items.dart
import 'package:flutter/material.dart';

class GameItem {
  final String id;
  final String name;
  final IconData icon;
  final Color color;
  final int price;
  final String description;
  final int limitPerMatch; // Giới hạn số lần dùng

  const GameItem({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    required this.price,
    required this.description,
    this.limitPerMatch = 99,
  });
}

class AppItems {
  static const List<GameItem> list = [
    // ================= NHÓM HỖ TRỢ (BUFF) =================
    GameItem(
      id: 'hint',
      name: 'Gợi Ý',
      icon: Icons.lightbulb,
      color: Colors.amber,
      price: 50, // Đã chỉnh giá mẫu, bạn có thể sửa lại
      limitPerMatch: 2,
      description: "Tự động điền 1 từ hợp lệ vào ô nhập liệu. Giúp bạn qua lượt nhanh chóng mà không cần suy nghĩ.",
    ),
    GameItem(
      id: 'peek',
      name: 'Soi Chữ',
      icon: Icons.visibility,
      color: Colors.blue,
      price: 30,
      limitPerMatch: 99,
      description: "Hé lộ các chữ cái có thể nối tiếp ở vế sau. Giúp bạn nhìn thấy trước đường đi nước bước để gài bẫy đối thủ.",
    ),
    GameItem(
      id: 'time_plus',
      name: 'Gia Hạn',
      icon: Icons.more_time, // Đổi icon cho hợp lý hơn
      color: Colors.green,
      price: 80,
      limitPerMatch: 3,
      description: "Cộng ngay 5 giây vào đồng hồ đếm ngược của lượt hiện tại. Cứu cánh kịp thời khi sắp hết giờ.",
    ),
    GameItem(
      id: 'golden_memory',
      name: 'Trí Nhớ Vàng',
      icon: Icons.psychology,
      color: Colors.orangeAccent,
      price: 150,
      limitPerMatch: 1,
      description: "Kích hoạt khả năng đặc biệt: Cho phép bạn sử dụng lại 1 từ đã xuất hiện trước đó trong trận đấu này.",
    ),
    GameItem(
      id: 'shield',
      name: 'Khiên',
      icon: Icons.shield,
      color: Colors.indigo,
      price: 200,
      limitPerMatch: 1,
      description: "Bỏ qua lượt khó này một cách an toàn. Quyền nối từ sẽ được đẩy ngược lại cho đối thủ.",
    ),
    GameItem(
      id: 'swap_word',
      name: 'Hoán Đổi',
      icon: Icons.change_circle, // Đổi icon
      color: Colors.purple,
      price: 120,
      limitPerMatch: 1,
      description: "Thay thế từ khóa hiện tại bằng một từ khác. Sử dụng khi gặp từ quá khó hoặc từ điển không nhận diện được.",
    ),

    // ================= NHÓM TẤN CÔNG (DEBUFF) =================
    GameItem(
      id: 'freeze',
      name: 'Đóng Băng',
      icon: Icons.ac_unit,
      color: Colors.cyan,
      price: 150,
      limitPerMatch: 1,
      description: "Tấn công đối thủ! Khiến họ bị đóng băng, không thể nhập liệu hay gửi từ trong vòng 5 giây ở lượt kế tiếp.",
    ),
    GameItem(
      id: 'attack_time',
      name: 'Ép Giờ',
      icon: Icons.hourglass_bottom,
      color: Colors.red,
      price: 120,
      limitPerMatch: 2,
      description: "Ám hại đối thủ! Trừ ngay 30% thời gian suy nghĩ của họ ngay khi họ bắt đầu lượt kế tiếp.",
    ),

    // ================= NHÓM PHÒNG THỦ & CỨU TRỢ =================
    GameItem(
      id: 'defense',
      name: 'Chống Bom',
      icon: Icons.gpp_good,
      color: Colors.teal,
      price: 150,
      limitPerMatch: 2,
      description: "Tạo lớp giáp bảo vệ bản thân. Tự động chặn đứng 1 đòn tấn công (Đóng băng hoặc Ép giờ) từ đối thủ.",
    ),
    GameItem(
      id: 'revive',
      name: 'Hồi Sinh',
      icon: Icons.favorite,
      color: Colors.pink,
      price: 400,
      limitPerMatch: 1,
      description: "Vật phẩm tối thượng. Tự động kích hoạt khi bạn hết giờ, giúp hồi sinh ngay lập tức với 15 giây để lật kèo.",
    ),
  ];

  static GameItem getById(String id) {
    return list.firstWhere((e) => e.id == id, orElse: () => list[0]);
  }
}