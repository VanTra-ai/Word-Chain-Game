// lib/screens/history_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // Cần thêm package intl vào pubspec.yaml hoặc dùng cách format thủ công bên dưới
import '../services/history_service.dart';
import '../constants/app_colors.dart';

class HistoryScreen extends StatelessWidget {
  // [QUAN TRỌNG] Thêm biến userId để Admin có thể xem lịch sử người khác
  final String? userId;

  const HistoryScreen({super.key, this.userId});

  @override
  Widget build(BuildContext context) {
    // Nếu userId là null -> Xem của chính mình
    // Nếu userId có giá trị -> Xem của người đó (Admin)
    final stream = userId == null
        ? HistoryService.getUserHistory()
        : HistoryService.getHistoryByUserId(userId!);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(userId == null ? "Lịch Sử Đấu" : "Lịch Sử Người Chơi"),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: StreamBuilder<List<MatchRecord>>(
        stream: stream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text("Lỗi: ${snapshot.error}"));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text("Chưa có lịch sử đấu nào!", style: TextStyle(color: Colors.grey)));
          }

          final matches = snapshot.data!;

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: matches.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final match = matches[index];
              return _buildHistoryCard(context, match);
            },
          );
        },
      ),
    );
  }

  Widget _buildHistoryCard(BuildContext context, MatchRecord match) {
    // Cấu hình hiển thị theo chế độ
    String title = "";
    String subtitle = "";
    Color statusColor = Colors.grey;
    IconData icon = Icons.gamepad;

    // Format ngày giờ an toàn
    String dateStr = "";
    try {
      dateStr = DateFormat('dd/MM HH:mm').format(match.timestamp);
    } catch (e) {
      dateStr = "${match.timestamp.day}/${match.timestamp.month} ${match.timestamp.hour}:${match.timestamp.minute}";
    }

    if (match.mode == 'bot') {
      title = "Luyện tập (Máy)";
      subtitle = "${match.score} điểm";
      statusColor = match.result == 'win' ? Colors.green : Colors.orange;
      icon = Icons.android;
    } else if (match.mode == 'pvp') {
      title = "Đối kháng vs ${match.opponentName ?? 'Ẩn danh'}";
      subtitle = match.result == 'win' ? "THẮNG" : "THUA";
      statusColor = match.result == 'win' ? Colors.green : Colors.red;
      icon = Icons.people_outline;
    } else if (match.mode == 'arena') {
      title = "Đấu Trường";
      subtitle = "${match.result} - ${match.score} điểm";
      // Check rank an toàn
      bool isTop = (match.rank != null && match.rank! <= 3) || match.result.contains("Top 1");
      statusColor = isTop ? Colors.amber : Colors.blue;
      icon = Icons.emoji_events;
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => MatchDetailScreen(match: match)));
        },
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: statusColor.withOpacity(0.1),
                    child: Icon(icon, color: statusColor),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 4),
                        Text("$dateStr • $subtitle", style: const TextStyle(color: Colors.grey, fontSize: 13)),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                ],
              ),

              // [MỚI] HIỂN THỊ PHẦN THƯỞNG (VÀNG/EXP)
              if (match.goldChange > 0 || match.expChange > 0) ...[
                const Divider(),
                Row(
                  children: [
                    const Spacer(),
                    if (match.goldChange > 0)
                      _buildRewardChip(Icons.monetization_on, Colors.amber, "+${match.goldChange}"),
                    if (match.expChange > 0)
                      _buildRewardChip(Icons.star, Colors.blue, "+${match.expChange} Exp"),
                  ],
                )
              ]
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRewardChip(IconData icon, Color color, String text) {
    return Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
        ],
      ),
    );
  }
}

// --- MÀN HÌNH CHI TIẾT TRẬN ĐẤU ---
class MatchDetailScreen extends StatelessWidget {
  final MatchRecord match;
  const MatchDetailScreen({super.key, required this.match});

  @override
  Widget build(BuildContext context) {
    String formattedDate = "";
    try {
      formattedDate = DateFormat('dd/MM/yyyy HH:mm').format(match.timestamp);
    } catch(e) {
      formattedDate = match.timestamp.toString();
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Chi tiết trận đấu"), backgroundColor: Colors.white, foregroundColor: Colors.black, elevation: 1),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thẻ thông tin tổng quan
            Container(
              padding: const EdgeInsets.all(16),
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.2), blurRadius: 10)],
                border: Border.all(color: Colors.grey.withOpacity(0.1)),
              ),
              child: Column(
                children: [
                  Text(match.result.toUpperCase(),
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold,
                          color: match.result.contains('win') || match.result.contains('Top 1') ? Colors.green : Colors.red)),
                  const SizedBox(height: 10),
                  Text("Chế độ: ${match.mode.toUpperCase()}", style: const TextStyle(fontWeight: FontWeight.bold)),
                  if (match.opponentName != null) Text("Đối thủ: ${match.opponentName}"),
                  const SizedBox(height: 5),
                  Text("Thời gian: $formattedDate", style: const TextStyle(color: Colors.grey)),

                  const SizedBox(height: 15),
                  // Hiển thị phần thưởng chi tiết
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Column(children: [
                        const Icon(Icons.monetization_on, color: Colors.amber),
                        Text("+${match.goldChange} Gold", style: const TextStyle(fontWeight: FontWeight.bold))
                      ]),
                      const SizedBox(width: 30),
                      Column(children: [
                        const Icon(Icons.star, color: Colors.blue),
                        Text("+${match.expChange} Exp", style: const TextStyle(fontWeight: FontWeight.bold))
                      ]),
                    ],
                  )
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Các từ đã nối:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                Text("${match.words.length} từ", style: const TextStyle(color: Colors.grey)),
              ],
            ),
            const SizedBox(height: 10),

            // Danh sách từ
            Expanded(
              child: match.words.isEmpty
                  ? const Center(child: Text("Không có dữ liệu từ vựng."))
                  : ListView.builder(
                itemCount: match.words.length,
                itemBuilder: (ctx, index) {
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.grey[200],
                        child: Text("${index + 1}", style: const TextStyle(fontSize: 12, color: Colors.black)),
                      ),
                      title: Text(match.words[index], style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}