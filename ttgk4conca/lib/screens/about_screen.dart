import 'package:flutter/material.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  // Màu chủ đạo của App (Bạn có thể đổi thành màu tím giống các màn hình trước)
  final Color primaryColor = const Color(0xFF6A5AE0);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Về ứng dụng',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- PHẦN HEADER: LOGO & TÊN APP ---
            Center(
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.extension_rounded, size: 80, color: primaryColor),
                  ),
                  const SizedBox(height: 15),
                  const Text(
                    'GAME NỐI CHỮ',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, height: 1.2),
                  ),
                  const SizedBox(height: 5),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Phiên bản 1.0.0 (Beta)',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),

            // --- PHẦN 1: GIỚI THIỆU ---
            _buildSectionTitle('Giới thiệu'),
            const SizedBox(height: 10),
            const Text(
              'Ứng dụng Game Nối Chữ là sân chơi trí tuệ giúp bạn rèn luyện tư duy ngôn ngữ và phản xạ nhanh nhạy. '
                  'Không chỉ chơi đơn, bạn còn có thể thách đấu trực tiếp với bạn bè hoặc tham gia đấu trường sinh tồn kịch tính.',
              style: TextStyle(fontSize: 15, height: 1.5, color: Colors.black87),
              textAlign: TextAlign.justify,
            ),

            const SizedBox(height: 25),

            // --- PHẦN 2: TÍNH NĂNG NỔI BẬT ---
            _buildSectionTitle('Tính năng nổi bật'),
            const SizedBox(height: 10),
            _buildFeatureItem('Luyện tập với Bot (Offline)'),
            _buildFeatureItem('Đối kháng 1vs1 Real-time'),
            _buildFeatureItem('Đấu trường nhóm (Arena)'),
            _buildFeatureItem('Bảng xếp hạng & Chat kết bạn'),

            const SizedBox(height: 25),

            // --- PHẦN 3: THÔNG TIN ĐỘI NGŨ (QUAN TRỌNG CHO ĐỒ ÁN) ---
            _buildSectionTitle('Đội ngũ phát triển'),
            const SizedBox(height: 10),
            const Text(
              'Sản phẩm thuộc đồ án môn Lập trình thiết bị di động - HUTECH.',
              style: TextStyle(fontSize: 15, height: 1.5, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 5),
            const Text(
              'Thành viên nhóm:\n'
                  '• Phạm Văn Trà\n'
                  '• Thái Hoài Duyên\n'
                  '• Phạm Trung Nguyên\n'
                  '• Lâm Bảo Trân\n',
              style: TextStyle(fontSize: 14, height: 1.6, color: Colors.black87),
            ),

            const SizedBox(height: 25),

            // --- PHẦN 4: LIÊN HỆ ---
            _buildSectionTitle('Liên hệ & Góp ý'),
            const SizedBox(height: 10),
            InkWell(
              onTap: () {
                // Thêm hành động gửi email nếu cần
              },
              child: Row(
                children: [
                  Icon(Icons.email_outlined, size: 20, color: primaryColor),
                  const SizedBox(width: 10),
                  const Text(
                    'traginomn@gmail.com', // Email từ các hình ảnh trước
                    style: TextStyle(fontSize: 15, color: Colors.blue, decoration: TextDecoration.underline),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),
            const Center(
              child: Text(
                '© 2026 HUTECH Student Project',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // Hàm helper tạo tiêu đề
  Widget _buildSectionTitle(String title) {
    return Container(
      padding: const EdgeInsets.only(left: 10),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: primaryColor, width: 4)),
      ),
      child: Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }

  // Hàm helper tạo dòng tính năng (Bullet point)
  Widget _buildFeatureItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        children: [
          Icon(Icons.check_circle, size: 16, color: Colors.green[600]),
          const SizedBox(width: 8),
          Text(text, style: const TextStyle(fontSize: 15)),
        ],
      ),
    );
  }
}