class DedicatedIpModel {
  final String id;
  final String serverId;
  final String serverName;
  final String serverCity;
  final String countryCode;
  final String publicIp;
  final String status;
  final DateTime? expiresAt;
  final DateTime createdAt;

  DedicatedIpModel({
    required this.id,
    required this.serverId,
    required this.serverName,
    required this.serverCity,
    required this.countryCode,
    required this.publicIp,
    required this.status,
    this.expiresAt,
    required this.createdAt,
  });

  factory DedicatedIpModel.fromJson(Map<String, dynamic> json) {
    final srv = json['server'] as Map<String, dynamic>?;

    return DedicatedIpModel(
      id: json['id'] ?? '',
      serverId: json['serverId'] ?? '',
      serverName: srv != null ? (srv['name'] ?? 'Server') : 'Server',
      serverCity: srv != null ? (srv['city'] ?? '') : '',
      countryCode: srv != null ? (srv['countryCode'] ?? 'US') : 'US',
      publicIp: json['publicIp'] ?? '',
      status: json['status'] ?? 'ACTIVE',
      expiresAt: json['expiresAt'] != null ? DateTime.tryParse(json['expiresAt']) : null,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt']) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
