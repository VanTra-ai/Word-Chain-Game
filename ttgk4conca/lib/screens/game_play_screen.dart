// lib/screens/game_play_screen.dart
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_colors.dart';
import '../widgets/message_bubble.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../services/presence_service.dart';
import '../services/history_service.dart';
import '../utils/toast_helper.dart';
import '../constants/game_items.dart';
import '../utils/audio_manager.dart';

class GamePlayScreen extends StatefulWidget {
  const GamePlayScreen({super.key});

  @override
  State<GamePlayScreen> createState() => _GamePlayScreenState();
}

class _GamePlayScreenState extends State<GamePlayScreen> {
  // Dữ liệu Game
  List<Map<String, dynamic>> _displayWords = [];
  List<String> _dictionary = [];

  // Logic Timer & Điểm
  Timer? _timer;
  static const int _maxTime = 30;
  int _timeLeft = _maxTime;
  int _score = 0;

  final Map<String, int> _itemUsageCount = {};

  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isBotThinking = false;

  @override
  void initState() {
    super.initState();
    PresenceService.setPlayingStatus(true);
    _loadDictionary();
    AudioManager().playGameMusic();
  }

  @override
  void dispose() {
    PresenceService.setPlayingStatus(false);
    _timer?.cancel();
    super.dispose();
  }

  // --- [MỚI] HÀM XỬ LÝ KHI BẤM NÚT BACK ---
  Future<bool> _onWillPop() async {
    // Hiện dialog cảnh báo
    final shouldQuit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cảnh báo', style: TextStyle(color: Colors.red)),
        content: const Text('Nếu thoát bây giờ bạn sẽ bị xử THUA và không nhận được thưởng. Bạn chắc chứ?'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false), // Ở lại
            child: const Text('Ở lại'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.of(context).pop(true); // Đồng ý thoát
            },
            child: const Text('Thoát & Chịu thua', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (shouldQuit == true) {
      // Gọi hàm xử thua trước khi thoát
      _surrender();
      return true; // Cho phép thoát màn hình
    }
    return false; // Chặn thoát
  }

  // Hàm xử lý đầu hàng (Ghi nhận thua cuộc)
  void _surrender() {
    // Lưu lịch sử là LOSE
    HistoryService.saveMatch(
      mode: 'bot',
      result: 'lose', // Ghi nhận thua
      score: _score,
      words: _displayWords.map((e) => e['word'] as String).toList(),
      goldChange: 0, // Không thưởng vàng
      expChange: 0,  // Không thưởng exp
    );
  }
  // -----------------------------------------

  Future<void> _loadDictionary() async {
    try {
      final String response = await rootBundle.loadString('assets/vietnamese_dictionary.txt');
      setState(() {
        _dictionary = const LineSplitter().convert(response)
            .map((line) => line.trim().toLowerCase())
            .where((line) => line.isNotEmpty)
            .toSet().toList();

        if (_dictionary.isNotEmpty) {
          final startWord = _dictionary[Random().nextInt(_dictionary.length)];
          _displayWords.add({'word': startWord, 'isPlayer': false});

          String lastChar = startWord.split(" ").last;
          _controller.text = "$lastChar ";
          _controller.selection = TextSelection.fromPosition(TextPosition(offset: _controller.text.length));

          _startTimer();
        }
      });
    } catch (e) {
      _dictionary = ["con cá", "cá chép"];
      _displayWords.add({'word': "con cá", 'isPlayer': false});
      _startTimer();
    }
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _timeLeft = _maxTime);

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timeLeft > 0) {
        setState(() => _timeLeft--);
      } else {
        timer.cancel();
        _checkRevive();
      }
    });
  }

  void _stopTimer() {
    _timer?.cancel();
  }

  void _checkRevive() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    int inventoryCount = authProvider.inventory['revive'] ?? 0;
    bool isEquipped = authProvider.equippedItems.contains('revive');
    int usedCount = _itemUsageCount['revive'] ?? 0;
    final itemConfig = AppItems.getById('revive');

    if (inventoryCount > 0 && isEquipped && usedCount < itemConfig.limitPerMatch) {
      bool? confirm = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) {
          return StreamBuilder<int>(
              stream: Stream.periodic(const Duration(seconds: 1), (i) => 3 - i).take(5),
              initialData: 3,
              builder: (context, snapshot) {
                int countdown = snapshot.data ?? 3;
                if (countdown <= 0) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (Navigator.canPop(ctx)) {
                      Navigator.pop(ctx, false);
                    }
                  });
                }
                return AlertDialog(
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  title: Row(
                    children: [
                      const Icon(Icons.timer, color: Colors.red),
                      const SizedBox(width: 10),
                      Text("CÒN $countdown GIÂY!", style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text("Dùng TIM HỒI SINH để chơi tiếp?", style: TextStyle(fontSize: 16)),
                      const SizedBox(height: 15),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.favorite, color: Colors.pink, size: 28),
                          const SizedBox(width: 8),
                          Text("x$inventoryCount", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.indigo)),
                        ],
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text("Bỏ qua", style: TextStyle(color: Colors.grey)),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.pink, foregroundColor: Colors.white),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text("HỒI SINH NGAY!"),
                    ),
                  ],
                );
              }
          );
        },
      );

      if (confirm == true) {
        await authProvider.consumeItem('revive');
        setState(() {
          _itemUsageCount['revive'] = usedCount + 1;
          _timeLeft = 10;
        });
        _startTimer();
        ToastHelper.show(context, "Đã hồi sinh! Cố lên!");
        return;
      }
    }

    _showGameOver("Hết giờ rồi! Bạn đã thua.", isWin: false);
  }

  String? _checkValidWord(String userWord) {
    userWord = userWord.toLowerCase().trim();
    if (!_dictionary.contains(userWord)) return "Từ này không có trong từ điển!";
    if (_displayWords.any((e) => e['word'] == userWord)) return "Từ này đã dùng rồi!";

    if (_displayWords.isNotEmpty) {
      String lastWord = _displayWords.last['word'];
      String lastChar = lastWord.split(" ").last;
      String firstChar = userWord.split(" ").first;
      if (lastChar != firstChar) return "Sai rồi! Phải bắt đầu bằng '$lastChar'";
    }
    return null;
  }

  void _handlePlayerSubmit() {
    if (_isBotThinking || _timeLeft == 0) return;

    String userWord = _controller.text.trim();
    if (userWord.isEmpty) return;

    String? error = _checkValidWord(userWord);
    if (error != null) {
      ToastHelper.show(context, error, isError: true);
      return;
    }

    setState(() {
      _displayWords.add({'word': userWord, 'isPlayer': true});
      _score += 10;
      _controller.clear();
      _scrollToBottom();
      _isBotThinking = true;
    });

    _stopTimer();
    _botTurn(userWord);
  }

  void _botTurn(String lastUserWord) {
    int thinkTime = Random().nextInt(1000) + 500;

    Future.delayed(Duration(milliseconds: thinkTime), () {
      if (!mounted) return;

      String lastChar = lastUserWord.split(" ").last;
      List<String> candidates = _dictionary.where((word) {
        return word.startsWith("$lastChar ") &&
            !_displayWords.any((e) => e['word'] == word);
      }).toList();

      if (candidates.isNotEmpty) {
        String botWord = candidates[Random().nextInt(candidates.length)];
        setState(() {
          _displayWords.add({'word': botWord, 'isPlayer': false});
          _isBotThinking = false;
          _scrollToBottom();

          String lastCharBot = botWord.split(" ").last;
          _controller.text = "$lastCharBot ";
          _controller.selection = TextSelection.fromPosition(
              TextPosition(offset: _controller.text.length)
          );
        });
        _startTimer();
      } else {
        _stopTimer();
        _showGameOver("Bot bí từ! Bạn thắng rồi! 🎉 (Điểm: $_score)", isWin: true);
      }
    });
  }

  void _showGameOver(String message, {required bool isWin}) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    authProvider.updateOfflineScore(_score);

    int goldReward = isWin ? 50 : 5;
    int expReward = isWin ? 20 : 5;
    goldReward += (_score ~/ 10);

    authProvider.addReward(goldReward: goldReward, expReward: expReward);

    HistoryService.saveMatch(
      mode: 'bot',
      result: isWin ? 'win' : 'lose',
      score: _score,
      words: _displayWords.map((e) => e['word'] as String).toList(),
      goldChange: goldReward,
      expChange: expReward,
    );

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text("Kết thúc", style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 10),
            Text("Tổng điểm: $_score", style: const TextStyle(fontSize: 24, color: AppColors.primary, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.monetization_on, color: Colors.amber[700]),
                Text(" +$goldReward  ", style: TextStyle(color: Colors.amber[800], fontWeight: FontWeight.bold)),
                const Icon(Icons.star, color: Colors.blue),
                Text(" +$expReward", style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
              ],
            )
          ],
        ),
        actions: [
          TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context);
              },
              child: const Text("Về trang chủ")
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _displayWords.clear();
                _score = 0;
                _timeLeft = _maxTime;
                _itemUsageCount.clear();
                _loadDictionary();
              });
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text("Chơi lại", style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    Color timerColor = _timeLeft <= 5 ? Colors.red : AppColors.accent;

    // [MỚI] Sử dụng WillPopScope để chặn nút Back
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.primary,
          title: const Text("Infinite Mode", style: TextStyle(color: Colors.white)),
          centerTitle: true,
          iconTheme: const IconThemeData(color: Colors.white),
          // [MỚI] Thêm leading thủ công để nút Back trên AppBar cũng gọi _onWillPop
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () async {
              if (await _onWillPop()) {
                if(mounted) Navigator.pop(context);
              }
            },
          ),
          actions: [
            Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(20)),
              child: Row(
                children: [
                  const Icon(Icons.star, color: Colors.yellow, size: 20),
                  const SizedBox(width: 4),
                  Text("$_score", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ],
              ),
            )
          ],
        ),
        body: Column(
          children: [
            // 1. Timer Panel
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              color: Colors.white,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.timer, color: timerColor),
                      const SizedBox(width: 8),
                      Text(
                          "00:${_timeLeft.toString().padLeft(2, '0')}",
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: timerColor)
                      ),
                    ],
                  ),
                  Text(
                      _isBotThinking ? "Bot đang nghĩ..." : "Lượt của bạn",
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: _isBotThinking ? Colors.grey : Colors.green
                      )
                  ),
                ],
              ),
            ),

            // 2. Chat List
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                itemCount: _displayWords.length,
                itemBuilder: (context, index) {
                  return MessageBubble(
                    word: _displayWords[index]['word'],
                    isPlayer: _displayWords[index]['isPlayer'],
                  );
                },
              ),
            ),

            // 3. Input Area
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.white,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      enabled: !_isBotThinking,
                      textInputAction: TextInputAction.send,
                      decoration: InputDecoration(
                        hintText: "Nhập từ tiếp theo...",
                        filled: true,
                        fillColor: AppColors.background,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      ),
                      onSubmitted: (_) => _handlePlayerSubmit(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  FloatingActionButton(
                    onPressed: _handlePlayerSubmit,
                    backgroundColor: _isBotThinking ? Colors.grey : AppColors.primary,
                    elevation: 2,
                    mini: true,
                    child: const Icon(Icons.send, color: Colors.white),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}