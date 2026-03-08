// lib/screens/admin/gift_code_tab.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class GiftCodeTab extends StatefulWidget {
  const GiftCodeTab({super.key});

  @override
  State<GiftCodeTab> createState() => _GiftCodeTabState();
}

class _GiftCodeTabState extends State<GiftCodeTab> {
  final _codeController = TextEditingController();
  final _coinController = TextEditingController(text: "0");
  final _expController = TextEditingController(text: "0");

  // [MỚI] Controller cho số lượng và biến ngày tháng
  final _limitController = TextEditingController(text: "100");
  DateTime? _selectedDate;

  @override
  void dispose() {
    _codeController.dispose();
    _coinController.dispose();
    _expController.dispose();
    _limitController.dispose();
    super.dispose();
  }

  // [MỚI] Hàm chọn ngày hết hạn
  void _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 7)), // Mặc định chọn ngày tuần sau
      firstDate: now,
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  void _createCode() async {
    String code = _codeController.text.trim().toUpperCase();
    int coin = int.tryParse(_coinController.text) ?? 0;
    int exp = int.tryParse(_expController.text) ?? 0;
    int limit = int.tryParse(_limitController.text) ?? 0;

    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Chưa nhập mã code!")));
      return;
    }
    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Chưa chọn ngày hết hạn!")));
      return;
    }

    // Set giờ hết hạn là cuối ngày (23:59:59) của ngày được chọn
    final expiry = DateTime(
        _selectedDate!.year, _selectedDate!.month, _selectedDate!.day, 23, 59, 59
    );

    // Check trùng
    final doc = await FirebaseFirestore.instance.collection('gift_codes').doc(code).get();
    if (doc.exists) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Mã này đã tồn tại!")));
      return;
    }

    await FirebaseFirestore.instance.collection('gift_codes').doc(code).set({
      'rewards': {
        'coin': coin,
        'exp': exp,
      },
      'expiryDate': Timestamp.fromDate(expiry), // [MỚI] Lưu ngày đã chọn
      'limit': limit,                           // [MỚI] Lưu giới hạn đã nhập
      'usedCount': 0,
      'isActive': true,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Reset form
    _codeController.clear();
    _coinController.text = "0";
    _expController.text = "0";
    _limitController.text = "100";
    setState(() => _selectedDate = null);

    if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Tạo Giftcode thành công!"), backgroundColor: Colors.green));
  }

  void _deleteCode(String codeId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Xóa Giftcode"),
        content: Text("Bạn muốn xóa mã $codeId?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Hủy")),
          TextButton(
              onPressed: () {
                FirebaseFirestore.instance.collection('gift_codes').doc(codeId).delete();
                Navigator.pop(ctx);
              },
              child: const Text("Xóa", style: TextStyle(color: Colors.red))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Format ngày hiển thị
    String dateStr = _selectedDate == null
        ? "Chọn ngày hết hạn"
        : "${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}";

    return Column(
      children: [
        // FORM NHẬP LIỆU
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.purple[50],
          child: Column(
            children: [
              // Hàng 1: Mã Code
              TextField(
                controller: _codeController,
                decoration: const InputDecoration(
                    labelText: "Nhập mã (VD: TET2026)",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.qr_code),
                    filled: true, fillColor: Colors.white
                ),
              ),
              const SizedBox(height: 10),

              // Hàng 2: Vàng & Exp
              Row(
                children: [
                  Expanded(child: TextField(controller: _coinController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Vàng", prefixIcon: Icon(Icons.monetization_on, color: Colors.amber), filled: true, fillColor: Colors.white))),
                  const SizedBox(width: 10),
                  Expanded(child: TextField(controller: _expController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Exp", prefixIcon: Icon(Icons.star, color: Colors.blue), filled: true, fillColor: Colors.white))),
                ],
              ),
              const SizedBox(height: 10),

              // [MỚI] Hàng 3: Số lượng & Hạn dùng
              Row(
                children: [
                  Expanded(
                      child: TextField(
                          controller: _limitController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                              labelText: "Số lượng",
                              prefixIcon: Icon(Icons.people),
                              filled: true, fillColor: Colors.white
                          )
                      )
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: InkWell(
                      onTap: _pickDate,
                      child: Container(
                        height: 55, // Chiều cao cố định để bằng với TextField
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today, color: Colors.grey),
                            const SizedBox(width: 8),
                            // [QUAN TRỌNG] Thêm Expanded để chữ tự thu gọn nếu quá dài
                            Expanded(
                              child: Text(
                                dateStr,
                                style: TextStyle(color: _selectedDate == null ? Colors.grey[700] : Colors.black),
                                overflow: TextOverflow.ellipsis, // Hiện dấu "..." nếu dài quá
                                maxLines: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _createCode,
                  icon: const Icon(Icons.add),
                  label: const Text("TẠO MÃ THƯỞNG"),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.purple, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)),
                ),
              )
            ],
          ),
        ),

        // DANH SÁCH MÃ
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('gift_codes').orderBy('createdAt', descending: true).snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

              if (snapshot.data!.docs.isEmpty) {
                return const Center(child: Text("Chưa có mã nào được tạo"));
              }

              return ListView.separated(
                itemCount: snapshot.data!.docs.length,
                separatorBuilder: (_,__) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final data = snapshot.data!.docs[index].data() as Map<String, dynamic>;
                  final codeId = snapshot.data!.docs[index].id;
                  final rewards = data['rewards'] as Map<String, dynamic>;

                  // Xử lý hiển thị ngày hết hạn
                  Timestamp? expiryTs = data['expiryDate'];
                  String expiryStr = expiryTs != null
                      ? "${expiryTs.toDate().day}/${expiryTs.toDate().month}/${expiryTs.toDate().year}"
                      : "Vô thời hạn";

                  int used = data['usedCount'] ?? 0;
                  int limit = data['limit'] ?? 0;
                  // Tính phần trăm đã dùng để hiển thị thanh tiến trình (nếu thích)

                  return ListTile(
                    tileColor: Colors.white,
                    leading: CircleAvatar(
                      backgroundColor: Colors.purple[100],
                      child: const Icon(Icons.card_giftcard, color: Colors.purple),
                    ),
                    title: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(codeId, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        if (used >= limit)
                          Container(padding: const EdgeInsets.symmetric(horizontal:6, vertical:2), decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(4)), child: const Text("HẾT LƯỢT", style: TextStyle(fontSize: 10, color: Colors.white)))
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("🎁 Vàng: ${rewards['coin']} | Exp: ${rewards['exp']}"),
                        Text("📅 Hết hạn: $expiryStr"),
                        Text("👥 Đã dùng: $used / $limit"),
                      ],
                    ),
                    trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: () => _deleteCode(codeId)
                    ),
                  );
                },
              );
            },
          ),
        )
      ],
    );
  }
}