// lib/screens/shop_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../constants/app_colors.dart';
import '../constants/game_items.dart';
import '../utils/toast_helper.dart';
import '../utils/number_formatter.dart';
import '../utils/audio_manager.dart';

class ShopScreen extends StatelessWidget {
  const ShopScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final List<String> equippedIds = authProvider.equippedItems;
    final int maxSlots = 4;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("Cửa hàng", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(color: Colors.amber[100], borderRadius: BorderRadius.circular(20)),
            child: Row(children: [
              const Icon(Icons.monetization_on, color: Colors.orange, size: 20),
              const SizedBox(width: 5),
              Text(NumberFormatter.format(authProvider.coin), style: TextStyle(color: Colors.orange[800], fontWeight: FontWeight.bold)),
            ]),
          )
        ],
      ),
      body: Column(
        children: [
          // ==========================================================
          // PHẦN 1: LOADOUT (GIỮ NGUYÊN VÌ ĐÃ TỐT)
          // ==========================================================
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 5))],
            ),
            child: Column(
              children: [
                const Text("VẬT PHẨM RA TRẬN", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1.2)),
                const SizedBox(height: 5),
                Text("${equippedIds.length}/$maxSlots slot đã dùng", style: const TextStyle(color: Colors.white70, fontSize: 12)),
                const SizedBox(height: 15),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(maxSlots, (index) {
                    String? itemId = index < equippedIds.length ? equippedIds[index] : null;
                    GameItem? item = itemId != null ? AppItems.getById(itemId) : null;
                    int quantity = (itemId != null) ? (authProvider.inventory[itemId] ?? 0) : 0;

                    return GestureDetector(
                      onTap: () {
                        if (itemId != null) authProvider.equipItem(itemId);
                      },
                      child: Container(
                        width: 70, height: 70,
                        decoration: BoxDecoration(
                          color: itemId != null ? Colors.white : Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: itemId != null
                            ? Stack(
                          children: [
                            Center(child: Icon(item!.icon, color: item.color, size: 30)),
                            Positioned(
                              top: 4, right: 4,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(10)),
                                child: Text("x$quantity", style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                              ),
                            )
                          ],
                        )
                            : const Icon(Icons.add, color: Colors.white54),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),

          // ==========================================================
          // PHẦN 2: DANH SÁCH VẬT PHẨM (THIẾT KẾ LẠI)
          // ==========================================================
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2, // 3 cột cho gọn
                  childAspectRatio: 1, // Tỉ lệ dọc
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemCount: AppItems.list.length,
                itemBuilder: (ctx, index) {
                  final item = AppItems.list[index];
                  return _buildGridItem(context, authProvider, item);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  // WIDGET Ô VẬT PHẨM TRONG DANH SÁCH (NHỎ GỌN)
  Widget _buildGridItem(BuildContext context, AuthProvider auth, GameItem item) {
    int owned = auth.inventory[item.id] ?? 0;
    bool isEquipped = auth.isEquipped(item.id);

    return GestureDetector(
      // BẤM VÀO ĐỂ HIỆN CHI TIẾT (Thay vì mua luôn)
      onTap: () {
        // [MỚI] Tiếng bấm nút
        AudioManager().playSFX('button.mp3');

        _showItemDetailDialog(context, auth, item);
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isEquipped ? Colors.green : Colors.grey[200]!, width: isEquipped ? 2 : 1),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(),
            Icon(item.icon, color: item.color, size: 40), // Increased icon size slightly
            const SizedBox(height: 8),
            Text(
                item.name,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold), // Increased font size slightly
                maxLines: 1
            ),
            const Spacer(),
            // Thanh trạng thái
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 6), // Increased vertical padding
              decoration: BoxDecoration(
                color: isEquipped ? Colors.green : (owned > 0 ? Colors.blue[50] : Colors.amber[50]),
                borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(12), bottomRight: Radius.circular(12)),
              ),
              child: Text(
                owned > 0 ? "$owned đang có" : "${item.price}\$",
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 11, // Increased font size slightly
                    fontWeight: FontWeight.bold,
                    color: isEquipped ? Colors.white : (owned > 0 ? Colors.blue : Colors.orange[800])
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================
  // [MỚI] DIALOG CHI TIẾT (THẺ CHỨC NĂNG)
  // ==========================================================
  void _showItemDetailDialog(BuildContext context, AuthProvider auth, GameItem item) {
    showDialog(
      context: context,
      builder: (ctx) {
        // Dùng StatefulBuilder để cập nhật UI trong Dialog khi mua/trang bị
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            int owned = auth.inventory[item.id] ?? 0;
            bool isEquipped = auth.isEquipped(item.id);

            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              backgroundColor: const Color(0xFFFFF8E1), // Màu nền kem giống game
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header: Tên & Nút đóng
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(item.name, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.brown[800])),
                        InkWell(onTap: () => Navigator.pop(context), child: const Icon(Icons.close, color: Colors.brown)),
                      ],
                    ),
                    const Divider(color: Colors.brown),
                    const SizedBox(height: 10),

                    // Icon Lớn
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: item.color, width: 2),
                        boxShadow: [BoxShadow(color: item.color.withOpacity(0.3), blurRadius: 15)],
                      ),
                      child: Icon(item.icon, size: 60, color: item.color),
                    ),
                    const SizedBox(height: 20),

                    // Thông số kỹ thuật (Giả lập style game)
                    _buildStatRow(Icons.bolt, "Độ hiếm", "Hiếm", Colors.purple),
                    const SizedBox(height: 8),
                    _buildStatRow(Icons.timelapse, "Giới hạn", "${item.limitPerMatch} lần/trận", Colors.blue),

                    const SizedBox(height: 20),

                    // Mô tả chi tiết
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.brown[50], borderRadius: BorderRadius.circular(10)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            const Icon(Icons.info_outline, size: 16, color: Colors.brown),
                            const SizedBox(width: 5),
                            Text("CHI TIẾT KỸ NĂNG", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.brown[800], fontSize: 12))
                          ]),
                          const SizedBox(height: 5),
                          Text(item.description, style: TextStyle(color: Colors.brown[600], fontSize: 13, height: 1.4)),
                        ],
                      ),
                    ),

                    const SizedBox(height: 25),

                    // HÀNG NÚT BẤM (QUAN TRỌNG NHẤT)
                    Row(
                      children: [
                        // Nút Mua (Luôn hiện để mua thêm)
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.amber,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: () async {
                              bool success = await auth.buyItem(item.id, item.price);
                              if (success) {
                                setStateDialog(() {}); // Load lại số lượng
                                ToastHelper.show(context, "Mua thêm thành công!");
                              } else {
                                ToastHelper.show(context, "Không đủ tiền!", isError: true);
                              }
                            },
                            child: Column(
                              children: [
                                const Text("MUA THÊM", style: TextStyle(color: Colors.brown, fontWeight: FontWeight.bold, fontSize: 10)),
                                const SizedBox(height: 2),
                                Text("${item.price} \$", style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 14)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),

                        // Nút Trang Bị / Gỡ (Chỉ hiện khi có đồ)
                        if (owned > 0)
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isEquipped ? Colors.redAccent : Colors.green,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: () async {
                                bool success = await auth.equipItem(item.id);
                                if (!success && !isEquipped) {
                                  ToastHelper.show(context, "Đã đầy 4 slot!", isError: true);
                                } else {
                                  setStateDialog(() {}); // Load lại trạng thái nút
                                }
                              },
                              child: Column(
                                children: [
                                  Text(isEquipped ? "GỠ BỎ" : "TRANG BỊ", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10)),
                                  const SizedBox(height: 2),
                                  Text(isEquipped ? "Đang dùng" : "Có sẵn: $owned", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                                ],
                              ),
                            ),
                          ),
                      ],
                    )
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Helper tạo dòng thông số
  Widget _buildStatRow(IconData icon, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          const Spacer(),
          Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }
}