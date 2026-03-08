// lib/screens/edit_profile_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../constants/app_colors.dart';
import '../constants/avatar_data.dart';
import '../utils/toast_helper.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final TextEditingController _nameController = TextEditingController();
  String? _selectedAvatar;

  @override
  void initState() {
    super.initState();
    final auth = Provider.of<AuthProvider>(context, listen: false);
    _nameController.text = auth.user?.displayName ?? "";
    _selectedAvatar = auth.customAvatar;
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: AvatarData.packs.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Chỉnh Sửa Hồ Sơ"),
          backgroundColor: Colors.white,
          actions: [
            TextButton(
              onPressed: _saveChanges,
              child: const Text("LƯU", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            )
          ],
          bottom: TabBar(
            isScrollable: true,
            tabs: AvatarData.packs.map((pack) => Tab(text: pack.name)).toList(),
          ),
        ),
        body: Column(
          children: [
            // 1. Profile Preview Section
            Container(
              padding: const EdgeInsets.all(20),
              color: Colors.grey[100],
              child: Row(
                children: [
                  _buildCurrentAvatarPreview(),
                  const SizedBox(width: 15),
                  Expanded(
                    child: TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: "Tên hiển thị",
                        border: OutlineInputBorder(),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 2. Avatar Grid
            Expanded(
              child: TabBarView(
                children: AvatarData.packs.map((pack) => _buildAvatarGrid(pack)).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentAvatarPreview() {
    return CircleAvatar(
      radius: 40,
      backgroundColor: Colors.grey[300],
      backgroundImage: _getAvatarImageProvider(_selectedAvatar),
    );
  }

  ImageProvider _getAvatarImageProvider(String? assetPath) {
    if (assetPath != null && assetPath.isNotEmpty && !assetPath.startsWith('http')) {
      return AssetImage(assetPath);
    }
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    if (user?.photoURL != null) {
      return NetworkImage(user!.photoURL!);
    }
    return const AssetImage('assets/default_avatar.png');
  }

  Widget _buildAvatarGrid(AvatarPack pack) {
    return Consumer<AuthProvider>(
      builder: (context, auth, child) {
        return GridView.builder(
          padding: const EdgeInsets.all(10),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemCount: pack.fileNames.length,
          itemBuilder: (context, index) {
            // Lấy tên file chính xác từ danh sách
            String imageName = pack.fileNames[index];
            String imagePath = "${pack.folderPath}/$imageName";

            bool isFree = pack.pricePerAvatar == 0;
            bool isUnlocked = isFree || auth.unlockedAvatars.contains(imagePath);
            bool isSelected = _selectedAvatar == imagePath;

            return GestureDetector(
              onTap: () {
                if (isUnlocked) {
                  setState(() {
                    _selectedAvatar = imagePath;
                  });
                } else {
                  // Show purchase dialog
                  _showPurchaseDialog(context, auth, imagePath, pack.pricePerAvatar);
                }
              },
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      border: isSelected ? Border.all(color: AppColors.primary, width: 3) : null,
                      borderRadius: BorderRadius.circular(10),
                      image: DecorationImage(
                        image: AssetImage(imagePath),
                        fit: BoxFit.cover,
                        // Grey out locked items slightly?
                        colorFilter: isUnlocked ? null : const ColorFilter.mode(Colors.grey, BlendMode.saturation),
                      ),
                    ),
                  ),

                  // Lock Icon for locked items
                  if (!isUnlocked)
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Center(
                        child: Icon(Icons.lock, color: Colors.white, size: 24),
                      ),
                    ),

                  // Selected Checkmark
                  if (isSelected)
                    const Align(
                        alignment: Alignment.topRight,
                        child: Icon(Icons.check_circle, color: AppColors.primary, size: 20)
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showPurchaseDialog(BuildContext context, AuthProvider auth, String imagePath, int price) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Mở khóa Avatar?"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(imagePath, height: 100, width: 100),
            const SizedBox(height: 10),
            Text("Giá: $price Vàng", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.amber)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Hủy")),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              bool success = await auth.buyAvatar(imagePath, price);
              if (success) {
                ToastHelper.show(context, "Mở khóa thành công!");
                setState(() {
                  _selectedAvatar = imagePath; // Auto-select after purchase
                });
              } else {
                ToastHelper.show(context, "Không đủ vàng!", isError: true);
              }
            },
            child: const Text("MUA"),
          )
        ],
      ),
    );
  }

  void _saveChanges() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    String newName = _nameController.text.trim();

    await auth.updateProfile(
      newName: newName != auth.user?.displayName ? newName : null,
      newAvatarAsset: _selectedAvatar != auth.customAvatar ? _selectedAvatar : null,
    );

    if (mounted) {
      ToastHelper.show(context, "Cập nhật hồ sơ thành công!");
      Navigator.pop(context);
    }
  }
}