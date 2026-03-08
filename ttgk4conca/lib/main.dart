// lib/main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'firebase_options.dart';
// QUAN TRỌNG: Import MainScreen chứa BottomNavigationBar
import 'screens/main_screen.dart';
import 'utils/audio_manager.dart';

// --- 1. Khởi tạo App ---
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  AudioManager().playMainMenuMusic();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Word Chain Game',
        theme: ThemeData(
          primarySwatch: Colors.indigo,
          useMaterial3: true,
          scaffoldBackgroundColor: Colors.white,
        ),
        home: const AuthWrapper(), // Kiểm tra trạng thái đăng nhập
      ),
    );
  }
}

// --- 2. Widget điều hướng ---
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      // Lắng nghe trạng thái đăng nhập liên tục từ Firebase
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // 1. TRƯỜNG HỢP ĐANG TẢI (Firebase đang lục lại bộ nhớ xem ai đăng nhập chưa)
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // 2. TRƯỜNG HỢP CÓ LỖI
        if (snapshot.hasError) {
          return const Scaffold(
            body: Center(child: Text("Có lỗi xảy ra khi kết nối!")),
          );
        }

        // 3. TRƯỜNG HỢP ĐÃ ĐĂNG NHẬP (Snapshot có dữ liệu User)
        if (snapshot.hasData && snapshot.data != null) {
          // Cập nhật User vào Provider để dùng trong app (nếu cần)
          // Dùng addPostFrameCallback để tránh lỗi vẽ giao diện
          WidgetsBinding.instance.addPostFrameCallback((_) {
            // FIX: Hàm updateUser đã được thêm vào AuthProvider bên dưới
            Provider.of<AuthProvider>(context, listen: false).updateUser(snapshot.data);
          });

          // CHUYỂN THẲNG VÀO MÀN HÌNH CHÍNH
          return const MainScreen();
        }

        // 4. TRƯỜNG HỢP CHƯA ĐĂNG NHẬP
        return const LoginScreen();
      },
    );
  }
}

// --- 3. Provider (Logic Auth & Điểm số) ---
class AuthProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: '547254181492-n996j81g3t1ae419933nbp7b1vidj5bu.apps.googleusercontent.com',
    scopes: [
      'email', // Chỉ cần email là đủ
      'profile', // Lấy thêm avatar và tên
    ],
  );

  User? _user;
  bool _isLoading = false;

  // --- CÁC BIẾN ĐIỂM SỐ CŨ ---
  int _offlineHighScore = 0; // Điểm cao nhất chơi với máy
  int _pvpScore = 0;         // Điểm tích lũy PvP
  int _totalGames = 0;
  int _totalWins = 0;

  // --- CÁC BIẾN KINH TẾ MỚI (Đưa lên trên này) ---
  int _coin = 0;
  int _level = 1;
  int _currentExp = 0;
  int _maxExp = 100;

  // GETTER
  User? get user => _user;
  bool get isLoading => _isLoading;
  int get leaderboardScore => _offlineHighScore + _pvpScore;
  int get offlineHighScore => _offlineHighScore;
  int get pvpScore => _pvpScore;
  int get totalGames => _totalGames;
  int get totalWins => _totalWins;

  // Getter mới
  int get coin => _coin;
  int get level => _level;
  int get currentExp => _currentExp;
  int get maxExp => _maxExp;
  double get levelProgress => _currentExp / _maxExp;

  Timestamp? _lastCheckIn;
  int _checkInStreak = 0; // Số ngày liên tiếp (0 -> 6)

  // Thêm biến lưu danh sách gói đã mở khóa
  List<String> _unlockedAvatars = [];
  String _customAvatar = "";

  List<String> get unlockedAvatars => _unlockedAvatars;
  String get customAvatar => _customAvatar;

  // Danh sách phần thưởng 7 ngày
  final List<int> _dailyRewards = [100, 200, 300, 400, 500, 800, 1000];

  int get checkInStreak => _checkInStreak;
  List<int> get dailyRewards => _dailyRewards;

  // Kiểm tra xem hôm nay có được điểm danh không
  bool get canCheckIn {
    if (_lastCheckIn == null) return true; // Chưa điểm danh bao giờ

    DateTime now = DateTime.now();
    DateTime last = _lastCheckIn!.toDate();

    // So sánh ngày/tháng/năm (bỏ qua giờ phút)
    bool isSameDay = now.year == last.year && now.month == last.month && now.day == last.day;
    return !isSameDay;
  }

  // CONSTRUCTOR
  AuthProvider() {
    _auth.authStateChanges().listen((User? user) {
      _user = user;
      if (user != null) {
        _loadUserData();
      } else {
        _resetData();
      }
      notifyListeners();
    });
  }

  // --- [FIX] THÊM HÀM NÀY ĐỂ SỬA LỖI ---
  void updateUser(User? user) {
    _user = user;
    if (user != null) {
      _loadUserData(); // Tải lại dữ liệu khi user được cập nhật
    } else {
      _resetData();
    }
    // Không cần notifyListeners() ở đây vì StreamBuilder đã build lại UI rồi
    // Hoặc nếu muốn chắc chắn thì để notifyListeners() cũng được, nhưng cẩn thận loop
  }
  // -------------------------------------

  void _resetData() {
    _offlineHighScore = 0;
    _pvpScore = 0;
    _totalGames = 0;
    _totalWins = 0;
    _coin = 0; // Reset thêm mấy cái này nữa
    _level = 1;
    _currentExp = 0;
    _maxExp = 100;
  }

  // KHO ĐỒ (Inventory)
  // Lưu dạng Map: {'hint': số_lượng, 'shield': số_lượng, ...}
  Map<String, int> _inventory = {
    'hint': 0,      // Gợi ý từ
    'shield': 0,    // Khiên bảo vệ (chặn thua 1 lần)
    'freeze': 0,    // Đóng băng thời gian
  };

  Map<String, int> get inventory => _inventory;

  List<String> _equippedItems = ['hint', 'peek', 'shield', 'time_plus', 'attack_time'];

  List<String> get equippedItems => _equippedItems;

  Future<void> refreshUser() async {
    if (_user != null) {
      print("Đang làm mới dữ liệu người dùng...");
      await _loadUserData(); // Gọi lại hàm tải dữ liệu từ Firestore
      notifyListeners();     // Báo cho toàn bộ App cập nhật giao diện
    }
  }

  // TẢI DỮ LIỆU TỪ FIRESTORE
  Future<void> _loadUserData() async {
    if (_user == null) return;
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(_user!.uid).get();
      if (doc.exists) {
        final data = doc.data();

        // 1. Load dữ liệu cơ bản
        _offlineHighScore = data?['offlineHighScore'] ?? 0;
        _pvpScore = data?['pvpScore'] ?? 0;
        _totalGames = data?['totalGames'] ?? 0;
        _totalWins = data?['totalWins'] ?? 0;
        _coin = data?['coin'] ?? 0;
        _level = data?['level'] ?? 1;
        _currentExp = data?['exp'] ?? 0;
        _maxExp = _level * 100;
        _lastCheckIn = data?['lastCheckIn'];
        _checkInStreak = data?['checkInStreak'] ?? 0;
        _customAvatar = data?['currentAvatar'] ?? "";

        if (data?['unlockedAvatars'] != null) {
          _unlockedAvatars = List<String>.from(data!['unlockedAvatars']);
        } else {
          _unlockedAvatars = [];
        }

        if (data?['inventory'] != null) {
          _inventory = Map<String, int>.from(data!['inventory']);
        }
        if (data?['equippedItems'] != null) {
          _equippedItems = List<String>.from(data!['equippedItems']);
        }

        // --- [QUAN TRỌNG] TỰ ĐỘNG BỔ SUNG FIELD CÒN THIẾU ---
        // Kiểm tra nếu thiếu các trường mới (cho tính năng BXH Chuỗi Thắng)
        if (data?['maxWinStreak'] == null || data?['currentStreak'] == null || data?['winStreak'] == null) {
          print("Phát hiện dữ liệu cũ, đang cập nhật schema...");
          await FirebaseFirestore.instance.collection('users').doc(_user!.uid).set({
            'winStreak': data?['winStreak'] ?? 0,      // Giữ lại nếu đã có, không thì 0
            'maxWinStreak': data?['winStreak'] ?? 0,   // Lấy winStreak cũ làm kỷ lục (nếu có)
            'currentStreak': 0,                        // Reset chuỗi hiện tại cho an toàn
            'leaderboardScore': _offlineHighScore + _pvpScore, // Đảm bảo có điểm tổng
            'level': _level,                           // Đảm bảo có level
          }, SetOptions(merge: true)); // Merge để không mất dữ liệu cũ
        }
        // ----------------------------------------------------

        // Logic Reset chuỗi điểm danh (Giữ nguyên)
        if (_lastCheckIn != null) {
          DateTime now = DateTime.now();
          DateTime last = _lastCheckIn!.toDate();
          DateTime dateNow = DateTime(now.year, now.month, now.day);
          DateTime dateLast = DateTime(last.year, last.month, last.day);
          int diffDays = dateNow.difference(dateLast).inDays;
          if (diffDays > 1) {
            _checkInStreak = 0;
            FirebaseFirestore.instance.collection('users').doc(_user!.uid).update({'checkInStreak': 0});
          }
        }

        notifyListeners();
      } else {
        // Nếu chưa có tài khoản trên Firestore (User mới tinh)
        _updateUserInfoFirestore();
      }
    } catch (e) {
      print("Lỗi tải dữ liệu: $e");
    }
  }

  // NEW: Buy a specific avatar
  Future<bool> buyAvatar(String avatarPath, int price) async {
    if (_user == null) return false;
    if (_unlockedAvatars.contains(avatarPath)) return true; // Already owned

    if (_coin >= price) {
      _coin -= price;
      _unlockedAvatars.add(avatarPath);
      AudioManager().playSFX('coin-collect-retro.mp3');
      notifyListeners();

      await FirebaseFirestore.instance.collection('users').doc(_user!.uid).update({
        'coin': _coin,
        'unlockedAvatars': _unlockedAvatars,
      });
      return true;
    }
    return false;
  }

  // HÀM ĐỔI AVATAR VÀ TÊN
  Future<void> updateProfile({String? newName, String? newAvatarAsset}) async {
    if (_user == null) return;

    Map<String, dynamic> firestoreUpdateData = {};

    // 1. Cập nhật Avatar (Local & Firestore)
    if (newAvatarAsset != null) {
      _customAvatar = newAvatarAsset;
      firestoreUpdateData['currentAvatar'] = newAvatarAsset;
    }

    // 2. Cập nhật Tên hiển thị
    if (newName != null && newName.isNotEmpty && newName != _user!.displayName) {
      try {
        // A. Cập nhật lên Firebase Auth (Quan trọng cho Profile)
        await _user!.updateDisplayName(newName);

        // [QUAN TRỌNG] Buộc tải lại thông tin User để UI nhận tên mới ngay lập tức
        await _user!.reload();
        _user = FirebaseAuth.instance.currentUser;

        // B. Chuẩn bị dữ liệu cập nhật Firestore (Quan trọng cho BXH)
        firestoreUpdateData['displayName'] = newName;
      } catch (e) {
        print("Lỗi cập nhật tên Auth: $e");
      }
    }

    // 3. Đẩy dữ liệu lên Firestore
    if (firestoreUpdateData.isNotEmpty) {
      await FirebaseFirestore.instance.collection('users').doc(_user!.uid).update(firestoreUpdateData);
    }

    // 4. Thông báo cho toàn bộ UI cập nhật lại
    notifyListeners();
  }

  // Hàm thay đổi trang bị (Gọi từ Shop)
  Future<bool> equipItem(String itemId) async {
    if (_user == null) return false;

    // Nếu đã trang bị rồi -> Gỡ ra
    if (_equippedItems.contains(itemId)) {
      _equippedItems.remove(itemId);
    } else {
      // Nếu chưa trang bị -> Kiểm tra slot (Ví dụ tối đa 4 món)
      if (_equippedItems.length >= 4) {
        return false; // Đầy túi rồi
      }
      _equippedItems.add(itemId);
    }

    notifyListeners();

    // Lưu lên Firebase
    await FirebaseFirestore.instance.collection('users').doc(_user!.uid).update({
      'equippedItems': _equippedItems,
    });
    return true;
  }

  // Kiểm tra xem item có đang được trang bị không
  bool isEquipped(String itemId) => _equippedItems.contains(itemId);

  // --- HÀM NHẬN QUÀ ĐIỂM DANH ---
  Future<void> claimDailyReward() async {
    if (!canCheckIn || _user == null) return;

    int reward = _dailyRewards[_checkInStreak % 7]; // Lấy quà theo ngày

    _coin += reward;
    _lastCheckIn = Timestamp.now();

    // Tăng chuỗi, nếu hết 7 ngày thì quay lại ngày 1 (hoặc giữ nguyên tùy logic)
    // Ở đây mình làm kiểu quay vòng 7 ngày
    _checkInStreak = (_checkInStreak + 1) % 7;

    notifyListeners();

    try {
      await FirebaseFirestore.instance.collection('users').doc(_user!.uid).update({
        'coin': _coin,
        'lastCheckIn': _lastCheckIn,
        'checkInStreak': _checkInStreak,
      });
    } catch (e) {
      print("Lỗi điểm danh: $e");
    }
  }

  Future<bool> buyItem(String itemId, int price) async {
    if (_user == null) return false;

    // Kiểm tra đủ tiền không
    if (_coin >= price) {
      _coin -= price; // Trừ tiền

      // Cộng vật phẩm vào kho
      int currentAmount = _inventory[itemId] ?? 0;
      _inventory[itemId] = currentAmount + 1;
      AudioManager().playSFX('coin-collect-retro.mp3');
      notifyListeners(); // Cập nhật UI

      // Lưu lên Firestore
      try {
        await FirebaseFirestore.instance.collection('users').doc(_user!.uid).update({
          'coin': _coin,
          'inventory': _inventory, // Lưu toàn bộ Map inventory
        });
        return true; // Mua thành công
      } catch (e) {
        print("Lỗi lưu mua hàng: $e");
        return false;
      }
    } else {
      return false; // Không đủ tiền
    }
  }

  Future<void> addReward({int goldReward = 0, int expReward = 0}) async {
    if (_user == null) return;

    _coin += goldReward;
    _currentExp += expReward;

    // Logic lên cấp: Nếu Exp hiện tại >= Max Exp
    bool isLevelUp = false;
    while (_currentExp >= _maxExp) {
      _currentExp -= _maxExp; // Trừ đi số exp đã dùng để lên cấp
      _level++;               // Tăng cấp
      _maxExp = _level * 100; // Tính mốc exp cho cấp tiếp theo
      isLevelUp = true;
    }

    notifyListeners(); // Cập nhật UI ngay lập tức

    // Lưu vào Firestore
    try {
      await FirebaseFirestore.instance.collection('users').doc(_user!.uid).set({
        'coin': _coin,
        'level': _level,
        'exp': _currentExp,
        'maxExp': _maxExp, // [Nên lưu thêm cái này]
        'lastPlayed': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (isLevelUp) {
        print("CHÚC MỪNG! BẠN ĐÃ LÊN CẤP $_level");
      }
    } catch (e) {
      print("Lỗi lưu thưởng: $e");
    }
  }

  Future<void> _updateUserInfoFirestore() async {
    if (_user == null) return;
    await FirebaseFirestore.instance.collection('users').doc(_user!.uid).set({
      'email': _user!.email,
      'displayName': _user!.displayName,
      'photoURL': _user!.photoURL,
      'lastSeen': FieldValue.serverTimestamp(),

      // Các chỉ số mặc định
      'coin': 0,
      'level': 1,
      'exp': 0,
      'maxExp': 100,
      'winStreak': 0,
      'maxWinStreak': 0,
      'currentStreak': 0,
      'leaderboardScore': 0,
      'inventory': {'hint': 1}, // Tặng tân thủ 1 gợi ý
    }, SetOptions(merge: true));
  }

  // CẬP NHẬT ĐIỂM OFFLINE (Chơi với máy)
  Future<void> updateOfflineScore(int newScore) async {
    if (_user == null) return;

    if (newScore > _offlineHighScore) {
      _offlineHighScore = newScore;
      notifyListeners();
      _syncScoreToFirebase();
    }
  }

  // CẬP NHẬT ĐIỂM ONLINE (Đấu PvP / Đấu trường)
  // amount có thể là +50 (thắng), -50 (thua), +reward (đấu trường)
  Future<void> updatePvPScore(int amount, {bool isWin = false, bool isMatch = true}) async {
    if (_user == null) return;

    if (isMatch) {
      _totalGames++;
      if (isWin) _totalWins++;
    }

    _pvpScore += amount;
    if (_pvpScore < 0) _pvpScore = 0; // Không để điểm âm

    notifyListeners();
    _syncScoreToFirebase();
  }

  // Hàm chung để đồng bộ điểm lên Firebase
  Future<void> _syncScoreToFirebase() async {
    try {
      int totalScore = _offlineHighScore + _pvpScore;
      await FirebaseFirestore.instance.collection('users').doc(_user!.uid).set({
        'offlineHighScore': _offlineHighScore,
        'pvpScore': _pvpScore,
        'totalGames': _totalGames,
        'totalWins': _totalWins,
        'leaderboardScore': totalScore, // Quan trọng: dùng để sort BXH
        'score': totalScore, // Dự phòng cho logic cũ nếu có
      }, SetOptions(merge: true));
    } catch (e) {
      print("Lỗi lưu điểm: $e");
    }
  }

  Future<void> signInWithGoogle(BuildContext context) async {
    _setLoading(true);
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        _setLoading(false);
        return;
      }
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      await _auth.signInWithCredential(credential);
    } catch (e) {
      print("Lỗi đăng nhập: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Lỗi đăng nhập: $e")),
      );
    } finally {
      _setLoading(false);
    }
  }

  // HÀM SỬ DỤNG VẬT PHẨM
  // Trả về true nếu dùng thành công (có tồn tại trong kho)
  Future<bool> consumeItem(String itemId) async {
    if (_user == null) return false;

    int currentAmount = _inventory[itemId] ?? 0;
    if (currentAmount > 0) {
      _inventory[itemId] = currentAmount - 1;
      notifyListeners(); // Cập nhật UI ngay

      // Đồng bộ Firestore (chạy ngầm, không cần await để game mượt)
      FirebaseFirestore.instance.collection('users').doc(_user!.uid).update({
        'inventory': _inventory,
      });
      return true;
    }
    return false;
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}

// --- 4. Màn hình Login ---
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: authProvider.isLoading
            ? const CircularProgressIndicator()
            : Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.indigo.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.extension, size: 80, color: Colors.indigo),
            ),
            const SizedBox(height: 20),
            const Text("NỐI CHỮ ONLINE", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.indigo)),
            const SizedBox(height: 10),
            const Text("Thử thách vốn từ vựng & So tài cùng bạn bè", style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 60),

            SizedBox(
              width: 250,
              height: 50,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black87,
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30), side: const BorderSide(color: Colors.grey)),
                ),
                icon: Image.network('https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/1200px-Google_%22G%22_logo.svg.png', height: 24),
                label: const Text("Tiếp tục bằng Google"),
                onPressed: () => authProvider.signInWithGoogle(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}