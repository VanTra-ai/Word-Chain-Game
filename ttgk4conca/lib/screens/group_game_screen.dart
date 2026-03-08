// lib/screens/group_game_screen.dart
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../constants/app_colors.dart';
import '../utils/toast_helper.dart';
import '../services/history_service.dart';
import '../utils/audio_manager.dart';

class GroupGameScreen extends StatefulWidget {
  final String roomId;
  final String currentUserId;
  final bool isHost;

  const GroupGameScreen({
    super.key,
    required this.roomId,
    required this.currentUserId,
    required this.isHost,
  });

  @override
  State<GroupGameScreen> createState() => _GroupGameScreenState();
}

class _GroupGameScreenState extends State<GroupGameScreen> with TickerProviderStateMixin {
  final DatabaseReference _roomRef = FirebaseDatabase.instance.ref('group_rooms');
  final TextEditingController _answerController = TextEditingController();

  List<String> _dictionary = [];
  bool _hasSubmitted = false;
  bool _hasSavedHistory = false;

  int _currentRound = 1;
  static const int _totalRounds = 10;
  static const int _roundDuration = 20;

  late AnimationController _timerController;

  @override
  void initState() {
    super.initState();
    _loadDictionary();

    _timerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: _roundDuration),
    );

    // [FIX] Add listener to handle time-out scenarios
    _timerController.addStatusListener((status) {
      if (status == AnimationStatus.completed && widget.isHost) {
        // Timer finished, host forces round end
        _hostEndRound();
      }
    });

    _listenToRoom();
    AudioManager().playGameMusic();
  }

  @override
  void dispose() {
    _timerController.dispose();
    _answerController.dispose();
    super.dispose();
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
    } catch (e) {
      print("Dictionary load error: $e");
    }
  }

  void _listenToRoom() {
    _roomRef.child(widget.roomId).onValue.listen((event) {
      if (!mounted || event.snapshot.value == null) return;

      final data = Map<String, dynamic>.from(event.snapshot.value as Map);
      final status = data['status'];
      final round = data['round'] ?? 1;
      final currentWord = data['currentWord'] ?? "";

      // Sync logic
      if (status == 'playing') {
        if (round != _currentRound) {
          _resetLocalStateForNewRound(round, currentWord);
        }
        // Start timer if not running and we haven't submitted (or just to sync visual)
        if (!_timerController.isAnimating && _timerController.value < 1.0) {
          _timerController.forward();
        }
      }

      // Host logic: Check for all answers
      if (widget.isHost && status == 'playing') {
        _hostCheckRoundEnd(data);
      }
    });
  }

  void _resetLocalStateForNewRound(int newRound, String currentWord) {
    setState(() {
      _currentRound = newRound;
      _hasSubmitted = false;

      if (currentWord.isNotEmpty && currentWord != "bắt đầu") {
        String lastChar = currentWord.split(" ").last;
        _answerController.text = "$lastChar ";
        _answerController.selection = TextSelection.fromPosition(TextPosition(offset: _answerController.text.length));
      } else {
        _answerController.clear();
      }

      _timerController.reset();
      _timerController.forward();
    });
  }

  void _hostCheckRoundEnd(Map<String, dynamic> data) {
    final players = data['players'] as Map? ?? {};
    final answers = data['answers'] as Map? ?? {};

    // End if everyone answered
    if (answers.length >= players.length) {
      _hostEndRound();
    }
    // Note: Time-out check is handled by the _timerController listener
  }

  void _hostEndRound() async {
    // Prevent double triggering if status is already changing
    final snapshot = await _roomRef.child(widget.roomId).child('status').get();
    if (snapshot.value == 'leaderboard' || snapshot.value == 'finished') return;

    await _roomRef.child(widget.roomId).update({
      'status': 'leaderboard',
    });

    Future.delayed(const Duration(seconds: 5), () {
      if (!mounted) return;
      _hostStartNextRound();
    });
  }

  void _hostStartNextRound() async {
    final snapshot = await _roomRef.child(widget.roomId).get();
    if (!snapshot.exists) return;
    final data = Map<String, dynamic>.from(snapshot.value as Map);

    int nextRound = (data['round'] ?? 1) + 1;

    if (nextRound > _totalRounds) {
      _roomRef.child(widget.roomId).update({'status': 'finished'});
    } else {
      String nextWord = _dictionary.isNotEmpty
          ? _dictionary[Random().nextInt(_dictionary.length)]
          : "bắt đầu";

      _roomRef.child(widget.roomId).update({
        'status': 'playing',
        'round': nextRound,
        'currentWord': nextWord,
        'answers': null,
        'startTime': ServerValue.timestamp,
      });
    }
  }

  void _submitAnswer(String currentWord) async {
    if (_hasSubmitted) return;
    String answer = _answerController.text.trim().toLowerCase();

    if (answer.isEmpty) return;

    if (!_dictionary.contains(answer)) {
      ToastHelper.show(context, "Từ không có trong từ điển!", isError: true);
      return;
    }

    String lastChar = currentWord.split(" ").last;
    String firstChar = answer.split(" ").first;
    if (lastChar != firstChar) {
      ToastHelper.show(context, "Sai rồi! Phải bắt đầu bằng '$lastChar'", isError: true);
      return;
    }

    int speedBonus = ((1.0 - _timerController.value) * 90).round();
    int score = 10 + speedBonus;

    setState(() {
      _hasSubmitted = true;
    });

    final playerRef = _roomRef.child('${widget.roomId}/players/${widget.currentUserId}');
    await playerRef.child('score').set(ServerValue.increment(score));
    await _roomRef.child('${widget.roomId}/answers/${widget.currentUserId}').set(true);
  }

  Future<void> _confirmExit() async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Thoát trận?"),
        content: const Text("Bạn sẽ bị mất toàn bộ điểm số."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Ở lại")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(context);

              await _roomRef.child('${widget.roomId}/players/${widget.currentUserId}').remove();

              if (widget.isHost) {
                await _roomRef.child(widget.roomId).remove();
              } else {
                final snapshot = await _roomRef.child('${widget.roomId}/players').get();
                if (!snapshot.exists || snapshot.children.isEmpty) {
                  await _roomRef.child(widget.roomId).remove();
                }
              }

              if (mounted) Navigator.pop(context);
            },
            child: const Text("Thoát", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // [FIXED] Updated function to fix Type Error
  void _saveGameHistory(Map players) {
    _hasSavedHistory = true;
    final myId = widget.currentUserId;

    // Safely finding user data without explicit MapEntry typing issues
    Map? myData;
    players.forEach((key, value) {
      if (value['id'] == myId) {
        myData = Map<String, dynamic>.from(value);
      }
    });

    if (myData == null) return;

    var sortedList = players.values.toList();
    sortedList.sort((a, b) => (b['score'] ?? 0).compareTo(a['score'] ?? 0));

    int myRank = 1;
    for(int i=0; i<sortedList.length; i++) {
      if(sortedList[i]['id'] == myId) {
        myRank = i + 1;
        break;
      }
    }

    int score = myData!['score'] ?? 0;

    int gold = 20;
    if (myRank == 1) gold = 100;
    else if (myRank == 2) gold = 50;

    HistoryService.saveMatch(
      mode: 'arena',
      result: 'Top $myRank',
      score: score,
      rank: myRank,
      goldChange: gold,
      expChange: 10,
    );

    Provider.of<AuthProvider>(context, listen: false).addReward(goldReward: gold, expReward: 10);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DatabaseEvent>(
      stream: _roomRef.child(widget.roomId).onValue,
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final data = Map<String, dynamic>.from(snapshot.data!.snapshot.value as Map);
        final status = data['status'];
        final players = Map<String, dynamic>.from(data['players'] ?? {});
        final answers = Map<String, dynamic>.from(data['answers'] ?? {});
        final currentWord = data['currentWord'] ?? "";

        if (status == 'leaderboard') {
          return _buildLeaderboardScreen(players, "Vòng $_currentRound Kết Thúc! Chuẩn bị...", isFinal: false);
        }

        if (status == 'finished') {
          if (!_hasSavedHistory) {
            _saveGameHistory(players);
          }
          return _buildLeaderboardScreen(players, "TỔNG KẾT TRẬN ĐẤU 🏆", isFinal: true);
        }

        return Scaffold(
          backgroundColor: Colors.deepPurple[50],
          appBar: AppBar(
            title: Text("Vòng $_currentRound/$_totalRounds"),
            centerTitle: true,
            automaticallyImplyLeading: false,
            backgroundColor: Colors.deepPurple,
            actions: [
              Center(
                child: Container(
                  margin: const EdgeInsets.only(right: 16),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(12)),
                  child: Text(
                      "${answers.length}/${players.length}",
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)
                  ),
                ),
              ),
              IconButton(icon: const Icon(Icons.exit_to_app), onPressed: _confirmExit)
            ],
          ),
          body: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                AnimatedBuilder(
                  animation: _timerController,
                  builder: (context, child) {
                    Color barColor = Colors.green;
                    if (_timerController.value > 0.5) barColor = Colors.orange;
                    if (_timerController.value > 0.8) barColor = Colors.red;

                    return ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: 1.0 - _timerController.value,
                        minHeight: 15,
                        backgroundColor: Colors.grey[300],
                        valueColor: AlwaysStoppedAnimation<Color>(barColor),
                      ),
                    );
                  },
                ),

                const Spacer(),

                Container(
                  padding: const EdgeInsets.all(30),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: const Offset(0,5))],
                  ),
                  child: Column(
                    children: [
                      const Text("Nối từ tiếp theo của:", style: TextStyle(color: Colors.grey, fontSize: 16)),
                      const SizedBox(height: 10),
                      Text(
                        currentWord.toUpperCase(),
                        style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.deepPurple),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                if (!_hasSubmitted)
                  Column(
                    children: [
                      TextField(
                        controller: _answerController,
                        decoration: InputDecoration(
                          hintText: "Nhập từ nối...",
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                        ),
                        onSubmitted: (_) => _submitAnswer(currentWord),
                      ),
                      const SizedBox(height: 15),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          ),
                          onPressed: () => _submitAnswer(currentWord),
                          child: const Text("GỬI TRẢ LỜI", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                        ),
                      ),
                    ],
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(color: Colors.green[100], borderRadius: BorderRadius.circular(15)),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle, color: Colors.green),
                        SizedBox(width: 10),
                        Text("Đã trả lời! Đang chờ người khác...", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),

                const Spacer(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLeaderboardScreen(Map players, String title, {bool isFinal = false}) {
    var sortedList = players.values.toList();
    sortedList.sort((a, b) => (b['score'] ?? 0).compareTo(a['score'] ?? 0));

    return Scaffold(
      backgroundColor: Colors.deepPurple,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(30),
              child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
            ),

            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                child: ListView.separated(
                  padding: const EdgeInsets.all(10),
                  itemCount: sortedList.length,
                  separatorBuilder: (_, __) => const Divider(),
                  itemBuilder: (context, index) {
                    final p = sortedList[index];
                    bool isTop = index < 3;
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: index == 0 ? Colors.amber : (index == 1 ? Colors.grey : (index == 2 ? Colors.brown : Colors.blue[50])),
                        child: Text("#${index + 1}", style: TextStyle(color: isTop ? Colors.white : Colors.black)),
                      ),
                      title: Text(p['name'] ?? "Unknown", style: const TextStyle(fontWeight: FontWeight.bold)),
                      trailing: Text("${p['score']} pts", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.indigo)),
                    );
                  },
                ),
              ),
            ),

            if (isFinal)
              Padding(
                padding: const EdgeInsets.all(20),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.deepPurple, minimumSize: const Size(double.infinity, 50)),
                  onPressed: () async {
                    await _roomRef.child('${widget.roomId}/players/${widget.currentUserId}').remove();

                    final snapshot = await _roomRef.child('${widget.roomId}/players').get();
                    if (!snapshot.exists || snapshot.children.isEmpty) {
                      await _roomRef.child(widget.roomId).remove();
                    }

                    if (mounted) Navigator.pop(context);
                  },
                  child: const Text("VỀ SẢNH CHÍNH", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              )
            else
              const Padding(
                padding: EdgeInsets.all(30),
                child: LinearProgressIndicator(backgroundColor: Colors.white24, color: Colors.white),
              )
          ],
        ),
      ),
    );
  }
}