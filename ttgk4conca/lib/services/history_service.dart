// lib/services/history_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// 1. CLASS MÔ HÌNH DỮ LIỆU (MatchRecord)
class MatchRecord {
  final String id;
  final String mode; // 'bot', 'pvp', 'arena'
  final String result; // 'win', 'lose', 'draw', 'Top 1', etc.
  final int score;
  final String? opponentName;
  final String? opponentAvatar;
  final int? rank;
  final DateTime timestamp;
  final List<String> words;
  final int goldChange; // [MỚI] Vàng nhận được
  final int expChange;  // [MỚI] Exp nhận được

  MatchRecord({
    required this.id,
    required this.mode,
    required this.result,
    required this.score,
    required this.timestamp,
    this.opponentName,
    this.opponentAvatar,
    this.rank,
    this.words = const [],
    this.goldChange = 0,
    this.expChange = 0,
  });

  // Hàm chuyển đổi từ Firestore Document sang Object
  factory MatchRecord.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MatchRecord(
      id: doc.id,
      mode: data['mode'] ?? 'unknown',
      result: data['result'] ?? 'unknown',
      score: data['score'] ?? 0,
      opponentName: data['opponentName'],
      opponentAvatar: data['opponentAvatar'],
      rank: data['rank'],
      // Xử lý an toàn cho timestamp (tránh lỗi null)
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      words: List<String>.from(data['words'] ?? []),
      goldChange: data['goldChange'] ?? 0,
      expChange: data['expChange'] ?? 0,
    );
  }
}

// 2. CLASS DỊCH VỤ (HistoryService)
class HistoryService {
  // Hàm lưu lịch sử đấu
  static Future<void> saveMatch({
    required String mode,
    required String result,
    required int score,
    String? opponentName,
    String? opponentAvatar,
    int? rank,
    List<String>? words,
    int goldChange = 0, // [MỚI]
    int expChange = 0,  // [MỚI]
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // Chỉ lưu tối đa 50 từ để nhẹ database
      List<String> finalWords = words ?? [];
      if (finalWords.length > 50) {
        finalWords = finalWords.sublist(0, 50);
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('match_history')
          .add({
        'mode': mode,
        'result': result,
        'score': score,
        'opponentName': opponentName,
        'opponentAvatar': opponentAvatar,
        'rank': rank,
        'timestamp': FieldValue.serverTimestamp(),
        'words': finalWords,
        'goldChange': goldChange,
        'expChange': expChange,
      });
      print("Đã lưu lịch sử đấu!");
    } catch (e) {
      print("Lỗi lưu lịch sử: $e");
    }
  }

  // Stream lấy lịch sử của chính mình (để dùng trong HistoryScreen)
  static Stream<List<MatchRecord>> getUserHistory() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Stream.empty();
    return getHistoryByUserId(user.uid);
  }

  // Stream lấy lịch sử theo UserID (để Admin xem)
  static Stream<List<MatchRecord>> getHistoryByUserId(String uid) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('match_history')
        .orderBy('timestamp', descending: true)
        .limit(50) // Lấy 50 trận mới nhất
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => MatchRecord.fromDoc(doc)).toList());
  }
}