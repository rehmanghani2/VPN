class MultiHopPair {
  final String id;
  final String name;
  final MultiHopNode entryServer;
  final MultiHopNode exitServer;
  final int estimatedPingMs;
  final String securityRating;
  final bool isPopular;

  MultiHopPair({
    required this.id,
    required this.name,
    required this.entryServer,
    required this.exitServer,
    required this.estimatedPingMs,
    required this.securityRating,
    this.isPopular = false,
  });

  factory MultiHopPair.fromJson(Map<String, dynamic> json) {
    return MultiHopPair(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      entryServer: MultiHopNode.fromJson(json['entryServer'] ?? {}),
      exitServer: MultiHopNode.fromJson(json['exitServer'] ?? {}),
      estimatedPingMs: json['estimatedPingMs'] ?? 80,
      securityRating: json['securityRating'] ?? 'A+',
      isPopular: json['isPopular'] ?? false,
    );
  }
}

class MultiHopNode {
  final String id;
  final String name;
  final String countryCode;
  final String countryName;
  final String city;
  final String publicIp;

  MultiHopNode({
    required this.id,
    required this.name,
    required this.countryCode,
    required this.countryName,
    required this.city,
    required this.publicIp,
  });

  factory MultiHopNode.fromJson(Map<String, dynamic> json) {
    return MultiHopNode(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      countryCode: json['countryCode'] ?? 'US',
      countryName: json['countryName'] ?? 'United States',
      city: json['city'] ?? '',
      publicIp: json['publicIp'] ?? '',
    );
  }

  String get flagEmoji {
    if (countryCode.length != 2) return '🌐';
    final int firstLetter = countryCode.toUpperCase().codeUnitAt(0) - 0x41 + 0x1F1E6;
    final int secondLetter = countryCode.toUpperCase().codeUnitAt(1) - 0x41 + 0x1F1E6;
    return String.fromCharCode(firstLetter) + String.fromCharCode(secondLetter);
  }
}
