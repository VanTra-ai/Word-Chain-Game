import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FriendService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // 1. Gửi lời mời kết bạn
  static Future<void> sendFriendRequest(String targetUserId, String targetName, String targetAvatar) async {
    final user = _auth.currentUser;
    if (user == null) return;

    // Ghi vào collection 'friend_requests' của người nhận
    await _firestore.collection('users').doc(targetUserId).collection('friend_requests').doc(user.uid).set({
      'fromId': user.uid,
      'fromName': user.displayName ?? "Unknown",
      'fromAvatar': user.photoURL ?? "",
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  // 2. Chấp nhận lời mời
  static Future<void> acceptFriendRequest(String requestUserId, String requestName, String requestAvatar) async {
    final user = _auth.currentUser;
    if (user == null) return;

    // A. Thêm người đó vào danh sách bạn của MÌNH
    await _firestore.collection('users').doc(user.uid).collection('friends').doc(requestUserId).set({
      'id': requestUserId,
      'name': requestName,
      'avatar': requestAvatar,
      'since': FieldValue.serverTimestamp(),
    });

    // B. Thêm MÌNH vào danh sách bạn của NGƯỜI ĐÓ
    await _firestore.collection('users').doc(requestUserId).collection('friends').doc(user.uid).set({
      'id': user.uid,
      'name': user.displayName ?? "Unknown",
      'avatar': user.photoURL ?? "",
      'since': FieldValue.serverTimestamp(),
    });

    // C. Xóa lời mời sau khi đã đồng ý
    await _firestore.collection('users').doc(user.uid).collection('friend_requests').doc(requestUserId).delete();
  }

  // 3. Từ chối lời mời
  static Future<void> declineFriendRequest(String requestUserId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _firestore.collection('users').doc(user.uid).collection('friend_requests').doc(requestUserId).delete();
  }

  // 4. Kiểm tra xem có phải bạn bè không (Để ẩn nút kết bạn)
  static Future<bool> isFriend(String targetUserId) async {
    final user = _auth.currentUser;
    if (user == null) return false;

    final doc = await _firestore.collection('users').doc(user.uid).collection('friends').doc(targetUserId).get();
    return doc.exists;
  }
}