// lib/constants/avatar_data.dart

class AvatarPack {
  final String id;
  final String name;
  final String folderPath;
  final int pricePerAvatar;
  final List<String> fileNames;

  const AvatarPack({
    required this.id,
    required this.name,
    required this.folderPath,
    required this.pricePerAvatar,
    required this.fileNames,
  });
}

class AvatarData {
  static const List<AvatarPack> packs = [
    AvatarPack(
      id: 'free',
      name: 'Gói cơ bản',
      folderPath: 'assets/avatars/free',
      pricePerAvatar: 0,
      fileNames: [
        '2.png', '4.png', '5.png', '7.png', '11.png', '12.png', '13.png', '16.png',
        '19.png', '20.png', '21.png', '22.png', '25.png', '26.png', '27.png', '28.png',
        '29.png', '30.png', '31.png', '33.png', '35.png', '36.png', '38.png', '41.png',
        '45.png', '51.png', '59.png', '70.png', '71.png', '78.png', '79.png', '80.png',
        '81.png', '82.png', '83.png', '84.png', '85.png', '92.png'
      ],
    ),
    AvatarPack(
      id: 'v1',
      name: 'Gói V1 (Trung cấp)',
      folderPath: 'assets/avatars/v1',
      pricePerAvatar: 300,
      // Liệt kê tên file trong thư mục v1
      fileNames: [
        '1.png', '6.png', '8.png', '9.png', '10.png', '14.png', '17.png', '18.png',
        '23.png', '24.png', '37.png', '39.png', '40.png', '42.png', '43.png', '48.png',
        '49.png', '52.png', '58.png', '72.png', '73.png', '75.png', '76.png', '77.png',
        '86.png', '87.png', '88.png', '89.png', '90.png', '91.png'
      ],
    ),
    AvatarPack(
      id: 'v2',
      name: 'Gói V2 (Cao cấp)',
      folderPath: 'assets/avatars/v2',
      pricePerAvatar: 500,
      // Liệt kê tên file trong thư mục v2
      fileNames: [
        '60.png', '61.png', '62.png', '63.png', '64.png', '65.png', '66.png', '67.png',
        '68.png', '69.png', '74.png', '93.png', '94.png', '95.png', '96.png', '97.png',
        '98.png', '99.png', '100.png', '101.png'
      ],
    ),
    AvatarPack(
      id: 'v3',
      name: 'Gói V3 (Siêu cấp)',
      folderPath: 'assets/avatars/v3',
      pricePerAvatar: 1000,
      // Liệt kê tên file trong thư mục v3
      fileNames: [
        '3.png', '32.png', '34.png', '44.png', '46.png', '47.png', '50.png', '53.png',
        '54.png', '55.png', '56.png', '57.png'
      ],
    ),
  ];
}