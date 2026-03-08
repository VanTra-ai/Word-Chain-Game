// lib/screens/admin/dictionary_tab.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DictionaryTab extends StatefulWidget {
  const DictionaryTab({super.key});

  @override
  State<DictionaryTab> createState() => _DictionaryTabState();
}

class _DictionaryTabState extends State<DictionaryTab> {
  final TextEditingController _wordController = TextEditingController();

  // [MỚI] Controller và biến lưu từ khóa tìm kiếm
  final TextEditingController _searchController = TextEditingController();
  String _searchKeyword = "";

  bool _isLoading = false;

  @override
  void dispose() {
    _wordController.dispose();
    _searchController.dispose(); // [MỚI] Dispose controller tìm kiếm
    super.dispose();
  }

  void _addWord() async {
    String word = _wordController.text.trim().toLowerCase();
    if (word.isEmpty) return;

    setState(() => _isLoading = true);

    // Check trùng
    final check = await FirebaseFirestore.instance.collection('new_words').where('word', isEqualTo: word).get();
    if (check.docs.isNotEmpty) {
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Từ này đã tồn tại!"), backgroundColor: Colors.orange));
        setState(() => _isLoading = false);
      }
      return;
    }

    await FirebaseFirestore.instance.collection('new_words').add({
      'word': word,
      'addedBy': 'admin',
      'timestamp': FieldValue.serverTimestamp(),
    });

    _wordController.clear();
    if(mounted) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Đã thêm từ mới thành công!"), backgroundColor: Colors.green));
    }
  }

  void _deleteWord(String docId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Xác nhận xóa"),
        content: const Text("Bạn có chắc muốn xóa từ này không?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Hủy")),
          TextButton(
              onPressed: () {
                FirebaseFirestore.instance.collection('new_words').doc(docId).delete();
                Navigator.pop(ctx);
              },
              child: const Text("Xóa", style: TextStyle(color: Colors.red))
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 1. KHU VỰC THÊM TỪ MỚI (Giữ nguyên)
        Container(
          padding: const EdgeInsets.all(16.0),
          color: Colors.grey[100],
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _wordController,
                  decoration: const InputDecoration(
                      labelText: "Thêm từ mới (Ví dụ: 'check var')",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.add_circle_outline),
                      filled: true,
                      fillColor: Colors.white
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: _isLoading ? null : _addWord,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                ),
                child: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.send, color: Colors.white),
              ),
            ],
          ),
        ),

        // 2. [MỚI] KHU VỰC TÌM KIẾM
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Colors.white,
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: "🔍 Tìm kiếm từ trong danh sách...",
              contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 0),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide(color: Colors.grey.shade300)),
              filled: true,
              fillColor: Colors.grey[50],
              suffixIcon: _searchKeyword.isNotEmpty
                  ? IconButton(
                icon: const Icon(Icons.clear, color: Colors.grey),
                onPressed: () {
                  _searchController.clear();
                  setState(() => _searchKeyword = "");
                },
              )
                  : null,
            ),
            // Cập nhật từ khóa mỗi khi gõ
            onChanged: (value) {
              setState(() {
                _searchKeyword = value.trim().toLowerCase();
              });
            },
          ),
        ),

        const Divider(height: 1),

        // 3. DANH SÁCH (Đã thêm logic lọc)
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('new_words').orderBy('timestamp', descending: true).snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

              // Lấy toàn bộ danh sách gốc
              final allDocs = snapshot.data!.docs;

              // [LOGIC LỌC] Lọc danh sách dựa trên từ khóa
              final filteredDocs = allDocs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                String word = (data['word'] ?? "").toString().toLowerCase();
                // Nếu ô tìm kiếm trống -> lấy hết. Nếu có chữ -> tìm chữ đó
                return _searchKeyword.isEmpty || word.contains(_searchKeyword);
              }).toList();

              if (filteredDocs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search_off, size: 60, color: Colors.grey[300]),
                      const SizedBox(height: 10),
                      Text(
                          _searchKeyword.isEmpty ? "Chưa có từ mới nào" : "Không tìm thấy từ '$_searchKeyword'",
                          style: const TextStyle(color: Colors.grey)
                      ),
                    ],
                  ),
                );
              }

              return ListView.separated(
                itemCount: filteredDocs.length, // Dùng độ dài danh sách ĐÃ LỌC
                separatorBuilder: (_,__) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final doc = filteredDocs[index]; // Lấy item từ danh sách ĐÃ LỌC
                  final data = doc.data() as Map<String, dynamic>;

                  return ListTile(
                    tileColor: Colors.white,
                    leading: const CircleAvatar(backgroundColor: Colors.blueAccent, child: Icon(Icons.font_download, color: Colors.white, size: 20)),
                    title: Text(data['word'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    subtitle: Text("Added: ${data['addedBy'] ?? 'unknown'}"),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () => _deleteWord(doc.id),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}