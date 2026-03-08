// lib/screens/online_game_screen.dart
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../constants/app_colors.dart';
import '../widgets/message_bubble.dart';
import '../services/presence_service.dart';
import '../constants/game_items.dart';
import '../services/history_service.dart';
import '../utils/toast_helper.dart';
import '../utils/audio_manager.dart';

class OnlineGameScreen extends StatefulWidget {
  final String roomId;
  final String currentUserId;

  const OnlineGameScreen({
    super.key,
    required this.roomId,
    required this.currentUserId,
  });

  @override
  State<OnlineGameScreen> createState() => _OnlineGameScreenState();
}

class _OnlineGameScreenState extends State<OnlineGameScreen> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref('rooms');
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<Map<String, dynamic>> _displayWords = [];
  List<String> _dictionary = [];
  Map<String, dynamic>? _roomData;

  bool _isMyTurn = false;
  bool _isLoading = true;
  String _statusText = "Đang kết nối...";

  // Trạng thái hiệu ứng
  bool _isGoldenMemoryActive = false;
  bool _isDefenseActive = false;
  bool _isFrozen = false;

  Timer? _gameTimer;
  static const int _maxTime = 30;
  int _timeLeft = _maxTime;

  bool _statsSaved = false;
  final Map<String, int> _itemUsageCount = {};

  // Biến lưu hiệu ứng chờ (Pending Debuff)
  int _pendingTimePenalty = 0; // Thời gian sẽ bị trừ
  bool _pendingFreeze = false; // Có bị đóng băng không

  // Biến hiệu ứng hình ảnh (Visual Effects)
  bool _showFreezeEffect = false;  // Hiệu ứng băng
  bool _showFireEffect = false;    // Hiệu ứng bị tấn công (trừ giờ)
  bool _showShieldEffect = false;  // Hiệu ứng khiên
  bool _showHealEffect = false;    // Hiệu ứng hồi máu/hồi sinh
  bool _showTimeEffect = false;   // Gia hạn
  bool _showSwapEffect = false;   // Hoán đổi
  bool _showGoldEffect = false;   // Trí nhớ vàng
  bool _showIdeaEffect = false;   // Gợi ý/Soi chữ

  @override
  void initState() {
    super.initState();
    PresenceService.setPlayingStatus(true);
    _loadDictionary();
    _listenToRoomData();
    AudioManager().playGameMusic();
  }

  @override
  void dispose() {
    PresenceService.setPlayingStatus(false);
    _gameTimer?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // --- LOGIC XỬ LÝ VẬT PHẨM ---
  void _useItem(String itemId) async {
    // 1. Kiểm tra lượt và trạng thái
    if (!_isMyTurn && itemId != 'revive') {
      ToastHelper.show(context, "Chưa đến lượt bạn!", isError: true);
      return;
    }
    if (_isFrozen && itemId != 'revive') {
      ToastHelper.show(context, "Bạn đang bị đóng băng!", isError: true);
      return;
    }

    // 2. Kiểm tra giới hạn sử dụng
    final itemConfig = AppItems.getById(itemId);
    int usedCount = _itemUsageCount[itemId] ?? 0;

    if (itemConfig.limitPerMatch > 0 && usedCount >= itemConfig.limitPerMatch) {
      ToastHelper.show(context, "Đã hết lượt dùng vật phẩm này!", isError: true);
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    // Revive xử lý riêng
    if (itemId == 'revive') {
      ToastHelper.show(context, "Vật phẩm này tự kích hoạt khi hết giờ!", isError: true);
      return;
    }

    // 3. Trừ item
    bool success = await authProvider.consumeItem(itemId);
    if (!success) {
      ToastHelper.show(context, "Bạn không có vật phẩm này!", isError: true);
      return;
    }

    setState(() {
      _itemUsageCount[itemId] = usedCount + 1;
    });

    // 4. Thực thi hiệu ứng
    switch (itemId) {
      case 'hint':
        _applyHint();
        _triggerVisualEffect('idea');
        break;
      case 'peek':
        _applyPeek();
        _triggerVisualEffect('idea');
        break;
      case 'shield': // Khiên: Bỏ qua lượt
        _skipTurn();
        _triggerVisualEffect('shield');
        break;
      case 'freeze': // Đóng Băng
        _attackOpponent('freeze');
        ToastHelper.show(context, "Đã đóng băng đối thủ 5s!");
        break;
      case 'time_plus':
        setState(() => _timeLeft += 5);
        _triggerVisualEffect('time'); // [MỚI]
        ToastHelper.show(context, "Đã cộng thêm 5s!");
        break;
      case 'attack_time': // Ép Giờ
        _attackOpponent('time_minus');
        ToastHelper.show(context, "Đã tấn công ép giờ đối thủ!");
        break;
      case 'defense': // Chống Bom
        setState(() => _isDefenseActive = true);
        _triggerVisualEffect('shield');
        ToastHelper.show(context, "Đã bật Khiên Chống Đòn!");
        break;
      case 'swap_word':
        _swapCurrentWord();
        _triggerVisualEffect('swap');
        break;
      case 'golden_memory':
        setState(() => _isGoldenMemoryActive = true);
        _triggerVisualEffect('gold'); // [MỚI]
        ToastHelper.show(context, "Trí nhớ vàng kích hoạt!");
        break;
    }
  }

  void _attackOpponent(String type) {
    if (_roomData == null) return;
    String target = (widget.currentUserId == _roomData!['host']['id']) ? 'guest' : 'host';
    _dbRef.child(widget.roomId).update({
      'attack': {
        'target': target,
        'type': type,
        'timestamp': ServerValue.timestamp,
      }
    });
  }

  void _applyHint() {
    String lastWord = _displayWords.isNotEmpty ? _displayWords.last['word'] : "";
    String lastChar = lastWord.isNotEmpty ? lastWord.split(" ").last : "";

    String? hintWord;
    List<String> candidates;
    if (lastChar.isEmpty) {
      candidates = _dictionary;
    } else {
      candidates = _dictionary.where((w) => w.startsWith("$lastChar ")).toList();
    }

    if (!_isGoldenMemoryActive) {
      candidates = candidates.where((w) => !_displayWords.any((dw) => dw['word'] == w)).toList();
    }

    if (candidates.isNotEmpty) {
      hintWord = candidates[Random().nextInt(candidates.length)];
      setState(() {
        _controller.text = hintWord!;
        _controller.selection = TextSelection.fromPosition(TextPosition(offset: _controller.text.length));
      });
    } else {
      ToastHelper.show(context, "Bó tay, không tìm thấy từ!", isError: true);
    }
  }

  void _applyPeek() {
    String lastWord = _displayWords.isNotEmpty ? _displayWords.last['word'] : "";
    String lastChar = lastWord.isNotEmpty ? lastWord.split(" ").last : "";

    if (lastChar.isEmpty) {
      ToastHelper.show(context, "Chưa có từ nào để soi!", isError: true);
      return;
    }

    List<String> validWords = _dictionary.where((w) => w.startsWith("$lastChar ")).toList();
    if (!_isGoldenMemoryActive) {
      validWords = validWords.where((w) => !_displayWords.any((dw) => dw['word'] == w)).toList();
    }

    if (validWords.isEmpty) {
      ToastHelper.show(context, "Không còn từ nào nối được!", isError: true);
      return;
    }

    Set<String> nextChars = {};
    for (var word in validWords) {
      List<String> parts = word.split(" ");
      if (parts.length > 1 && parts[1].isNotEmpty) {
        nextChars.add(parts[1][0].toUpperCase());
      }
    }
    List<String> sortedChars = nextChars.toList()..sort();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(children: [Icon(Icons.visibility, color: Colors.cyan), SizedBox(width: 10), Text("Soi Chữ")]),
        content: Text("Các từ nối tiếp theo có thể bắt đầu bằng:\n\n${sortedChars.join(", ")}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.indigo)),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("Đã hiểu"))],
      ),
    );
  }

  void _swapCurrentWord() async {
    if (_displayWords.isEmpty) {
      ToastHelper.show(context, "Chưa có từ nào để đổi!", isError: true);
      return;
    }
    Map<String, dynamic> lastEntry = _displayWords.last;
    String currentWord = lastEntry['word'];
    String previousChar = "";
    if (_displayWords.length >= 2) {
      String prevWord = _displayWords[_displayWords.length - 2]['word'];
      previousChar = prevWord.split(" ").last;
    }

    List<String> candidates;
    if (previousChar.isEmpty) {
      candidates = _dictionary;
    } else {
      candidates = _dictionary.where((w) => w.startsWith("$previousChar ")).toList();
    }
    candidates = candidates.where((w) => w != currentWord && !_displayWords.any((dw) => dw['word'] == w)).toList();

    if (candidates.isEmpty) {
      ToastHelper.show(context, "Không có từ nào khác để thay thế!", isError: true);
      return;
    }
    String newWord = candidates[Random().nextInt(candidates.length)];

    List<Map<String, dynamic>> newWordsList = List.from(_displayWords);
    newWordsList.last['word'] = newWord;

    await _dbRef.child(widget.roomId).update({'words': newWordsList});
    ToastHelper.show(context, "Đã hoán đổi: '$currentWord' -> '$newWord'");
  }

  void _skipTurn() async {
    if (_roomData == null) return;
    String hostId = _roomData!['host']['id'];
    String guestId = _roomData!['guest']['id'];
    String nextTurnId = (widget.currentUserId == hostId) ? guestId : hostId;

    try {
      await _dbRef.child(widget.roomId).update({'currentTurn': nextTurnId});
      setState(() {
        _itemUsageCount['shield'] = (_itemUsageCount['shield'] ?? 0);
        _stopTimer();
      });
      ToastHelper.show(context, "Đã dùng Khiên! Đẩy lượt về cho đối thủ.");
    } catch (e) { print("Lỗi skip turn: $e"); }
  }

  // Logic tự động đánh khi dùng autoWin (Hiện tại Shield dùng skip turn nên hàm này ít dùng, giữ lại dự phòng)
  void _submitAnswer({bool autoWin = false}) {
    if (autoWin) {
      _applyHint();
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) _submitWord();
      });
      return;
    }
    _submitWord();
  }

  Future<void> _loadDictionary() async {
    try {
      final String response = await rootBundle.loadString('assets/vietnamese_dictionary.txt');
      if (mounted) {
        setState(() {
          _dictionary = const LineSplitter().convert(response)
              .map((line) => line.trim().toLowerCase())
              .where((line) => line.isNotEmpty)
              .toSet().toList();
        });
      }
    } catch (e) { print("Lỗi từ điển: $e"); }
  }

  void _startTimer() {
    _gameTimer?.cancel();

    setState(() {
      _timeLeft = _maxTime; // Reset về 30s

      // [PENDING DEBUFF] Áp dụng án phạt đầu lượt
      if (_pendingTimePenalty > 0) {
        int reduction = _pendingTimePenalty;
        _timeLeft = (_timeLeft > reduction) ? _timeLeft - reduction : 1;
        _pendingTimePenalty = 0; // Xóa án phạt

        _triggerVisualEffect('damage'); // Hiệu ứng chớp đỏ
        ToastHelper.show(context, "Án phạt: Bị trừ giờ!", isError: true);
      }

      if (_pendingFreeze) {
        _isFrozen = true;
        _pendingFreeze = false;

        _triggerVisualEffect('freeze'); // Hiệu ứng đóng băng
        ToastHelper.show(context, "Án phạt: Bạn bị ĐÓNG BĂNG!", isError: true);

        Future.delayed(const Duration(seconds: 5), () {
          if (mounted) {
            setState(() => _isFrozen = false);
            ToastHelper.show(context, "Đã hết đóng băng!");
          }
        });
      }
    });

    _gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timeLeft > 0) {
        if (mounted) setState(() => _timeLeft--);
      } else {
        timer.cancel();
        _checkRevive();
      }
    });
  }

  void _stopTimer() {
    _gameTimer?.cancel();
  }

  void _checkRevive() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    int reviveCount = authProvider.inventory['revive'] ?? 0;
    int usedCount = _itemUsageCount['revive'] ?? 0;
    bool canRevive = reviveCount > 0 && usedCount < 1;

    if (canRevive) {
      bool? confirm = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => _ReviveDialog(count: reviveCount),
      );

      if (confirm == true) {
        await authProvider.consumeItem('revive');
        setState(() {
          _itemUsageCount['revive'] = usedCount + 1;
          _timeLeft = 15;
        });
        _triggerVisualEffect('heal'); // Hiệu ứng hồi sinh
        _startTimer();
        ToastHelper.show(context, "Đã hồi sinh thành công!");
        return;
      }
    }
    _handleTimeout();
  }

  void _handleTimeout() {
    if (_isMyTurn && _roomData != null && _roomData!['status'] == 'playing') {
      String hostId = _roomData!['host']['id'];
      String guestId = _roomData!['guest']['id'];
      String winnerId = (widget.currentUserId == hostId) ? guestId : hostId;

      _dbRef.child(widget.roomId).update({
        'status': 'finished',
        'winner': winnerId,
      });
    }
  }

  void _listenToRoomData() {
    _dbRef.child(widget.roomId).onValue.listen((event) {
      if (!mounted || event.snapshot.value == null) return;

      final data = Map<String, dynamic>.from(event.snapshot.value as Map);

      // Xử lý tấn công
      if (data['attack'] != null) {
        final attack = data['attack'];
        String myRole = (widget.currentUserId == data['host']['id']) ? 'host' : 'guest';

        if (attack['target'] == myRole) {
          if (_isDefenseActive) {
            _triggerVisualEffect('shield');
            ToastHelper.show(context, "Khiên đã chặn đòn tấn công!");
            setState(() => _isDefenseActive = false);
          } else {
            // Lưu vào Pending Debuff thay vì trừ ngay
            if (attack['type'] == 'time_minus') {
              setState(() => _pendingTimePenalty = 10);
              ToastHelper.show(context, "Cảnh báo: Lượt tới bạn sẽ bị TRỪ GIỜ!", isError: true);
            } else if (attack['type'] == 'freeze') {
              setState(() => _pendingFreeze = true);
              ToastHelper.show(context, "Cảnh báo: Lượt tới bạn sẽ bị ĐÓNG BĂNG!", isError: true);
            }
          }
          _dbRef.child('${widget.roomId}/attack').remove();
        }
      }

      if (data['status'] == 'refused') {
        if (mounted) {
          ToastHelper.show(context, "Đối thủ đã từ chối lời mời!", isError: true);
          _dbRef.child(widget.roomId).remove();
          Navigator.of(context).pop();
        }
        return;
      }

      setState(() {
        _roomData = data;
        _isLoading = false;

        if (data['words'] != null) {
          final List<dynamic> rawWords = data['words'];
          _displayWords = rawWords.map((e) => Map<String, dynamic>.from(e)).toList();
          _scrollToBottom();
        }

        if (data['status'] == 'playing') {
          String currentTurnId = data['currentTurn'];
          bool wasMyTurn = _isMyTurn;
          _isMyTurn = (currentTurnId == widget.currentUserId);

          if (_isMyTurn && !wasMyTurn && _displayWords.isNotEmpty) {
            String lastWord = _displayWords.last['word'];
            String lastChar = lastWord.split(" ").last;
            _controller.text = "$lastChar ";
            _controller.selection = TextSelection.fromPosition(TextPosition(offset: _controller.text.length));
          }

          if (_isMyTurn != wasMyTurn) _startTimer();
          if (_gameTimer == null) _startTimer();

          _statusText = _isMyTurn ? "Đến lượt BẠN!" : "Đối thủ đang nghĩ...";
        } else if (data['status'] == 'waiting') {
          _statusText = "Đang tìm đối thủ...";
        } else if (data['status'] == 'finished') {
          _stopTimer();
          _statusText = "Kết thúc.";
          if (!_statsSaved) _showGameOverDialog(data['winner']);
        }
      });
    });
  }

  void _submitWord() async {
    if (!_isMyTurn) return;
    if (_isFrozen) {
      ToastHelper.show(context, "Bạn đang bị đóng băng!", isError: true);
      return;
    }

    String userWord = _controller.text.trim();
    if (userWord.isEmpty) return;

    String? error = _checkValidWord(userWord);
    if (error != null) {
      ToastHelper.show(context, error, isError: true);
      return;
    }

    try {
      List<Map<String, dynamic>> newWordsList = List.from(_displayWords);
      newWordsList.add({'word': userWord, 'userId': widget.currentUserId});

      String hostId = _roomData!['host']['id'];
      String guestId = _roomData!['guest']['id'];
      String nextTurnId = (widget.currentUserId == hostId) ? guestId : hostId;

      await _dbRef.child(widget.roomId).update({
        'words': newWordsList,
        'currentTurn': nextTurnId,
      });

      if (_isGoldenMemoryActive) setState(() => _isGoldenMemoryActive = false);
      setState(() { _controller.clear(); });
      _stopTimer();

    } catch (e) { print("Lỗi gửi từ: $e"); }
  }

  String? _checkValidWord(String userWord) {
    userWord = userWord.toLowerCase().trim();
    if (!_dictionary.contains(userWord)) return "Từ này không có trong từ điển!";

    if (_displayWords.any((e) => e['word'] == userWord)) {
      if (!_isGoldenMemoryActive) return "Từ này đã dùng rồi!";
    }

    if (_displayWords.isNotEmpty) {
      String lastWord = _displayWords.last['word'];
      String lastChar = lastWord.split(" ").last;
      String firstChar = userWord.split(" ").first;
      if (lastChar != firstChar) return "Sai rồi! Phải bắt đầu bằng '$lastChar'";
    }
    return null;
  }

  Future<bool> _onWillPop() async {
    if (_roomData == null) return true;
    String status = _roomData!['status'];
    if (status == 'waiting') {
      if (widget.currentUserId == _roomData!['host']['id']) {
        _dbRef.child(widget.roomId).remove();
      }
      return true;
    }
    if (status == 'finished') return true;

    return (await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cảnh báo', style: TextStyle(color: Colors.red)),
        content: const Text('Nếu thoát bây giờ bạn sẽ bị xử THUA. Bạn chắc chứ?'),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Ở lại')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.of(context).pop(true);
              _surrender();
            },
            child: const Text('Thoát & Chịu thua', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    )) ?? false;
  }

  // --- HÀM HIỆU ỨNG HÌNH ẢNH ---
  void _triggerVisualEffect(String type) {
    setState(() {
      // Reset tất cả về false trước để tránh chồng chéo
      _showFreezeEffect = false; _showFireEffect = false; _showShieldEffect = false;
      _showHealEffect = false; _showTimeEffect = false; _showSwapEffect = false;
      _showGoldEffect = false; _showIdeaEffect = false;

      // Bật hiệu ứng tương ứng
      switch (type) {
        case 'freeze': _showFreezeEffect = true; break;
        case 'damage': _showFireEffect = true; break;
        case 'shield': _showShieldEffect = true; break;
        case 'heal': _showHealEffect = true; break;
        case 'time': _showTimeEffect = true; break;      // [MỚI]
        case 'swap': _showSwapEffect = true; break;      // [MỚI]
        case 'gold': _showGoldEffect = true; break;      // [MỚI]
        case 'idea': _showIdeaEffect = true; break;      // [MỚI]
      }
    });

    // Tự tắt sau 1s (nhanh hơn chút cho các item phụ)
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted) {
        setState(() {
          _showFreezeEffect = false; _showFireEffect = false; _showShieldEffect = false;
          _showHealEffect = false; _showTimeEffect = false; _showSwapEffect = false;
          _showGoldEffect = false; _showIdeaEffect = false;
        });
      }
    });
  }

  // --- LOGIC MỚI: CẬP NHẬT CHUỖI THẮNG & ĐIỂM (SỬ DỤNG TRANSACTION) ---
  Future<void> _updateWinStreak(bool isWin) async {
    final userRef = FirebaseFirestore.instance.collection('users').doc(widget.currentUserId);
    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final snapshot = await transaction.get(userRef);
        if (!snapshot.exists) return;

        int currentStreak = snapshot.data()?['currentStreak'] ?? 0; // Đổi tên biến cũ
        int maxStreak = snapshot.data()?['maxWinStreak'] ?? 0; // Biến mới
        int currentScore = snapshot.data()?['leaderboardScore'] ?? 0;

        // Tính chuỗi hiện tại
        int newCurrentStreak = isWin ? currentStreak + 1 : 0;

        // Tính kỷ lục cao nhất (chỉ cập nhật nếu phá kỷ lục)
        int newMaxStreak = maxStreak;
        if (newCurrentStreak > maxStreak) {
          newMaxStreak = newCurrentStreak;
        }

        transaction.update(userRef, {
          'currentStreak': newCurrentStreak, // Dùng để tính tiếp ván sau
          'maxWinStreak': newMaxStreak,      // Dùng để Xếp Hạng
          'winStreak': newMaxStreak,         // (MẸO) Ghi đè vào trường cũ để đỡ phải sửa file Leaderboard
          'leaderboardScore': currentScore + (isWin ? 50 : 0),
        });
      });
    } catch (e) {
      print("Lỗi cập nhật chuỗi thắng: $e");
    }
  }

  void _surrender() async {
    if (_roomData != null) {
      String hostId = _roomData!['host']['id'];
      String guestId = _roomData!['guest']['id'];
      String winnerId = (widget.currentUserId == hostId) ? guestId : hostId;

      // Cập nhật trạng thái thua cho mình
      await _updateWinStreak(false);

      // Chỉ cập nhật trạng thái finished, KHÔNG XOÁ PHÒNG Ở ĐÂY
      await _dbRef.child(widget.roomId).update({
        'status': 'finished',
        'winner': winnerId,
      });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showGameOverDialog(String? winnerId) {
    _statsSaved = true;
    bool isWin = (winnerId == widget.currentUserId);

    String opponentName = "Unknown";
    String? opponentAvatar;
    if (_roomData != null) {
      var guest = _roomData!['guest'];
      var host = _roomData!['host'];
      var opponent = (widget.currentUserId == host['id']) ? guest : host;
      if (opponent != null) {
        opponentName = opponent['name'];
        opponentAvatar = opponent['avatar'];
      }
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    if (isWin) {
      authProvider.updatePvPScore(50, isWin: true); // Cập nhật local/coin
      _updateWinStreak(true); // [FIX] Cập nhật Firestore Streak & Rank
    } else {
      authProvider.updatePvPScore(-50, isWin: false); // Cập nhật local/coin
      _updateWinStreak(false); // [FIX] Cập nhật Firestore Streak & Rank
    }

    int goldReceived = isWin ? 100 : 10;
    int expReceived = isWin ? 50 : 10;
    authProvider.addReward(goldReward: goldReceived, expReward: expReceived);

    HistoryService.saveMatch(
      mode: 'pvp',
      result: isWin ? 'win' : 'lose',
      score: 0,
      opponentName: opponentName,
      opponentAvatar: opponentAvatar,
      words: _displayWords.map((e) => e['word'] as String).toList(),
      goldChange: goldReceived,
      expChange: expReceived,
    );

    String title = isWin ? "CHIẾN THẮNG! 🏆" : "THẤT BẠI 😢";
    String scoreMsg = isWin ? "(+50 điểm)" : "(-50 điểm)";

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(title, style: TextStyle(color: isWin ? Colors.orange : Colors.grey, fontWeight: FontWeight.bold)),
        content: Text(isWin ? "Bạn đã đánh bại đối thủ! $scoreMsg" : "Đừng buồn, hãy phục thù nhé! $scoreMsg"),
        actions: [
          TextButton(
              onPressed: () async {
                try {
                  await _dbRef.child(widget.roomId).remove();
                } catch(e) {}

                Navigator.pop(ctx);
                Navigator.pop(context);
              },
              child: const Text("Về Sảnh Chờ")
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isWaiting = _roomData != null && _roomData!['status'] == 'waiting';

    Map<String, dynamic>? opponent;
    if (_roomData != null && _roomData!['guest'] != null) {
      if (widget.currentUserId == _roomData!['host']['id']) {
        opponent = Map<String, dynamic>.from(_roomData!['guest']);
      } else {
        opponent = Map<String, dynamic>.from(_roomData!['host']);
      }
    }

    Color timerColor = _timeLeft > 10 ? Colors.green : (_timeLeft > 5 ? Colors.orange : Colors.red);

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text(isWaiting
              ? "Đang tìm trận..."
              : "Phòng: ${widget.roomId.length > 5 ? "${widget.roomId.substring(0, 5)}..." : widget.roomId}"
          ),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () async {
              if (await _onWillPop()) {
                if (mounted) Navigator.of(context).pop();
              }
            },
          ),
        ),
        body: isWaiting
            ? _buildWaitingView()
            : Stack( // Sử dụng Stack để đè hiệu ứng lên trên
          children: [
            // === LỚP 1: GIAO DIỆN GAME CHÍNH ===
            Column(
              children: [
                // Thanh Đối Thủ
                Container(
                  padding: const EdgeInsets.all(12),
                  color: Colors.white,
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundImage: opponent != null && opponent['avatar'] != null
                            ? NetworkImage(opponent['avatar'])
                            : null,
                        child: opponent == null ? const Icon(Icons.person) : null,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(opponent?['name'] ?? "Đang chờ...", style: const TextStyle(fontWeight: FontWeight.bold)),
                            Text(_statusText, style: TextStyle(color: _isMyTurn ? Colors.green : Colors.grey, fontSize: 13)),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          border: Border.all(color: timerColor, width: 2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.timer, color: timerColor, size: 20),
                            const SizedBox(width: 4),
                            Text(
                              "00:${_timeLeft.toString().padLeft(2, '0')}",
                              style: TextStyle(color: timerColor, fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ],
                        ),
                      )
                    ],
                  ),
                ),

                // Danh sách từ
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                    itemCount: _displayWords.length,
                    itemBuilder: (context, index) {
                      final item = _displayWords[index];
                      bool isMe = item['userId'] == widget.currentUserId;
                      return MessageBubble(word: item['word'], isPlayer: isMe);
                    },
                  ),
                ),

                // Thanh vật phẩm
                Container(
                  height: 60,
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  color: Colors.grey[100],
                  child: Consumer<AuthProvider>(
                    builder: (context, auth, child) {
                      final equippedList = AppItems.list
                          .where((item) => auth.equippedItems.contains(item.id))
                          .toList();

                      if (equippedList.isEmpty) return const Center(child: Text("Chưa trang bị vật phẩm", style: TextStyle(fontSize: 12)));

                      return ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: equippedList.length,
                        itemBuilder: (ctx, index) {
                          final item = equippedList[index];
                          int owned = auth.inventory[item.id] ?? 0;
                          int used = _itemUsageCount[item.id] ?? 0;

                          bool isLocked = item.id != 'revive' && item.limitPerMatch > 0 && used >= item.limitPerMatch;

                          return GestureDetector(
                            onTap: (owned > 0 && !isLocked) ? () => _useItem(item.id) : null,
                            child: Container(
                              width: 50,
                              margin: const EdgeInsets.only(right: 10),
                              decoration: BoxDecoration(
                                color: (owned > 0 && !isLocked) ? Colors.white : Colors.grey[300],
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: (owned > 0 && !isLocked) ? item.color : Colors.grey),
                              ),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  Icon(item.icon, color: (owned > 0 && !isLocked) ? item.color : Colors.grey, size: 24),
                                  Positioned(right: 2, bottom: 2, child: Text("$owned", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
                                  if (isLocked) const Positioned(child: Icon(Icons.lock, size: 16, color: Colors.black45))
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),

                // Thanh nhập liệu
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.white,
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          enabled: _isMyTurn && opponent != null && !_isFrozen,
                          decoration: InputDecoration(
                            hintText: _isFrozen ? "Đang bị đóng băng..." : (_isMyTurn ? "Nhập từ tiếp theo..." : "Đợi đối thủ..."),
                            filled: true,
                            fillColor: AppColors.background,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                          ),
                          onSubmitted: (_) => _submitWord(),
                        ),
                      ),
                      const SizedBox(width: 10),
                      FloatingActionButton(
                        onPressed: (_isMyTurn && !_isFrozen) ? _submitWord : null,
                        backgroundColor: (_isMyTurn && !_isFrozen) ? AppColors.primary : Colors.grey,
                        elevation: 2,
                        mini: true,
                        child: const Icon(Icons.send, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // === LỚP 2: HIỆU ỨNG HÌNH ẢNH (VFX) ===
            _buildEffectOverlays(),
          ],
        ),
      ),
    );
  }

  Widget _buildWaitingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(width: 80, height: 80, child: CircularProgressIndicator(strokeWidth: 6, color: AppColors.primary)),
          const SizedBox(height: 30),
          const Text("ĐANG TÌM ĐỐI THỦ...", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 10),
          const Text("Vui lòng đợi giây lát", style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 40),
          OutlinedButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: widget.roomId));
              ToastHelper.show(context, "Đã sao chép mã phòng!");
            },
            icon: const Icon(Icons.copy),
            label: Text("Mã phòng: ${widget.roomId}"),
          )
        ],
      ),
    );
  }

  Widget _buildEffectOverlays() {
    return IgnorePointer(
      child: Stack(
        children: [
          // 1. HIỆU ỨNG ĐÓNG BĂNG
          AnimatedOpacity(
            duration: const Duration(milliseconds: 500),
            opacity: _showFreezeEffect || _isFrozen ? 1.0 : 0.0,
            child: Container(
              color: Colors.lightBlueAccent.withOpacity(0.3),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.ac_unit, size: 100, color: Colors.white),
                    Text("ĐÓNG BĂNG!", style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.bold, shadows: [Shadow(blurRadius: 10, color: Colors.blue)])),
                  ],
                ),
              ),
            ),
          ),

          // 2. HIỆU ỨNG BỊ TRỪ GIỜ
          AnimatedOpacity(
            duration: const Duration(milliseconds: 300),
            opacity: _showFireEffect ? 1.0 : 0.0,
            child: Container(
              color: Colors.red.withOpacity(0.4),
              child: const Center(
                child: Icon(Icons.warning_amber_rounded, size: 120, color: Colors.yellow),
              ),
            ),
          ),

          // 3. HIỆU ỨNG KHIÊN
          AnimatedOpacity(
            duration: const Duration(milliseconds: 500),
            opacity: _showShieldEffect || _isDefenseActive ? 1.0 : 0.0,
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.amber, width: 8),
                color: Colors.amber.withOpacity(0.1),
              ),
              child: const Center(
                child: Icon(Icons.shield, size: 100, color: Colors.amber),
              ),
            ),
          ),

          // 4. HIỆU ỨNG HỒI SINH
          AnimatedOpacity(
            duration: const Duration(milliseconds: 500),
            opacity: _showHealEffect ? 1.0 : 0.0,
            child: Container(
              color: Colors.green.withOpacity(0.3),
              child: const Center(
                child: Icon(Icons.favorite, size: 100, color: Colors.pink),
              ),
            ),
          ),
          // 5. HIỆU ỨNG GIA HẠN (Xanh lá nhạt + Đồng hồ)
          AnimatedOpacity(
            duration: const Duration(milliseconds: 500),
            opacity: _showTimeEffect ? 1.0 : 0.0,
            child: Container(
              color: Colors.greenAccent.withOpacity(0.2),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.more_time, size: 100, color: Colors.green),
                    Text("+TIME", style: TextStyle(color: Colors.green, fontSize: 30, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
          ),

          // 6. HIỆU ỨNG HOÁN ĐỔI (Tím mộng mơ)
          AnimatedOpacity(
            duration: const Duration(milliseconds: 500),
            opacity: _showSwapEffect ? 1.0 : 0.0,
            child: Container(
              color: Colors.purpleAccent.withOpacity(0.2),
              child: const Center(
                child: Icon(Icons.change_circle, size: 120, color: Colors.purple),
              ),
            ),
          ),

          // 7. HIỆU ỨNG TRÍ NHỚ VÀNG (Vàng kim rực rỡ)
          AnimatedOpacity(
            duration: const Duration(milliseconds: 500),
            opacity: _showGoldEffect || _isGoldenMemoryActive ? 1.0 : 0.0,
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [Colors.yellow.withOpacity(0.4), Colors.transparent],
                  radius: 0.8,
                ),
              ),
              child: const Center(
                child: Icon(Icons.psychology, size: 100, color: Colors.yellow), // Icon bộ não
              ),
            ),
          ),

          // 8. HIỆU ỨNG GỢI Ý/SOI (Sáng trắng)
          AnimatedOpacity(
            duration: const Duration(milliseconds: 300),
            opacity: _showIdeaEffect ? 1.0 : 0.0,
            child: Container(
              color: Colors.white.withOpacity(0.3),
              child: const Center(
                child: Icon(Icons.lightbulb, size: 100, color: Colors.yellowAccent),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Dialog Hồi Sinh
class _ReviveDialog extends StatelessWidget {
  final int count;
  const _ReviveDialog({required this.count});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
        stream: Stream.periodic(const Duration(seconds: 1), (i) => 3 - i).take(4),
        initialData: 3,
        builder: (context, snapshot) {
          int countdown = snapshot.data ?? 3;
          if (countdown <= 0) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (Navigator.canPop(context)) Navigator.pop(context, false);
            });
          }
          return AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.timer, color: Colors.red),
                const SizedBox(width: 10),
                Text("CÒN $countdown GIÂY!", style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              ],
            ),
            content: Text("Dùng TIM HỒI SINH (Còn $count)?"),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Bỏ qua")),
              ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text("HỒI SINH")),
            ],
          );
        });
  }
}