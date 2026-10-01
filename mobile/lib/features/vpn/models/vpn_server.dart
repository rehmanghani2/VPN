class VpnServer {
  final String id;
  final String name;
  final String countryCode;
  final String countryName;
  final String city;
  final String hostname;
  final String status;
  final int capacity;
  final int currentLoad;
  final bool isObfuscated;
  final int obfuscationPort;
  final String obfuscationProtocol;

  VpnServer({
    required this.id,
    required this.name,
    required this.countryCode,
    required this.countryName,
    required this.city,
    required this.hostname,
    required this.status,
    required this.capacity,
    required this.currentLoad,
    this.isObfuscated = false,
    this.obfuscationPort = 443,
    this.obfuscationProtocol = 'NONE',
  });

  factory VpnServer.fromJson(Map<String, dynamic> json) {
    return VpnServer(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      countryCode: json['countryCode'] ?? '',
      countryName: json['countryName'] ?? '',
      city: json['city'] ?? '',
      hostname: json['hostname'] ?? '',
      status: json['status'] ?? 'ONLINE',
      capacity: json['capacity'] ?? 500,
      currentLoad: json['currentLoad'] ?? 0,
      isObfuscated: json['isObfuscated'] ?? false,
      obfuscationPort: json['obfuscationPort'] ?? 443,
      obfuscationProtocol: json['obfuscationProtocol'] ?? 'NONE',
    );
  }

  // Country Flag Emoji Helper
  String get flagEmoji {
    if (countryCode.length != 2) return '🌐';
    final int firstLetter = countryCode.toUpperCase().codeUnitAt(0) - 0x41 + 0x1F1E6;
    final int secondLetter = countryCode.toUpperCase().codeUnitAt(1) - 0x41 + 0x1F1E6;
    return String.fromCharCode(firstLetter) + String.fromCharCode(secondLetter);
  }

  int get loadPercentage {
    if (capacity <= 0) return 0;
    final percent = ((currentLoad / capacity) * 100).round();
    return percent > 100 ? 100 : percent;
  }
}
