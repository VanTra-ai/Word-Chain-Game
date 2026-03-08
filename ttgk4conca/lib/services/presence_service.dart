// lib/services/presence_service.dart
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PresenceService {
  // 1. Cấu hình trạng thái Online/Offline tự động
  static void configurePresence() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final database = FirebaseDatabase.instance;
    final myConnectionsRef = database.ref("status/${user.uid}");

    // Dữ liệu khi Online
    final isOnline = {
      'state': 'online',
      'last_changed': ServerValue.timestamp,
      'name': user.displayName,
      'avatar': user.photoURL,
    };

    // Dữ liệu khi Offline
    final isOffline = {
      'state': 'offline',
      'last_changed': ServerValue.timestamp,
      'name': user.displayName,
      'avatar': user.photoURL,
    };

    database.ref(".info/connected").onValue.listen((event) {
      if (event.snapshot.value == false) {
        return;
      }

      // Khi mất kết nối -> Tự chuyển thành Offline
      myConnectionsRef.onDisconnect().update(isOffline).then((_) {
        // Khi có kết nối -> Chuyển thành Online
        myConnectionsRef.update(isOnline);
      });
    });
  }

  // 2. Hàm set Offline thủ công (dùng khi Đăng xuất)
  static void setOffline() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final myConnectionsRef = FirebaseDatabase.instance.ref("status/${user.uid}");
      myConnectionsRef.update({
        'state': 'offline',
        'last_changed': ServerValue.timestamp,
      });
    }
  }

  // 3. HÀM MỚI: Cập nhật trạng thái Đang chơi / Rảnh rỗi
  // Gọi hàm này với true khi vào game, false khi thoát game
  static void setPlayingStatus(bool isPlaying) {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final myConnectionsRef = FirebaseDatabase.instance.ref("status/${user.uid}");
      myConnectionsRef.update({
        'state': isPlaying ? 'playing' : 'online', // Nếu chơi thì 'playing', thoát thì về 'online'
        'last_changed': ServerValue.timestamp,
      });
    }
  }
}