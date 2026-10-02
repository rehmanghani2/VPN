class PortForwardRule {
  final String id;
  final String deviceId;
  final String deviceName;
  final String serverId;
  final String serverName;
  final String serverIp;
  final int externalPort;
  final int internalPort;
  final String protocol;
  final String status;
  final DateTime createdAt;

  PortForwardRule({
    required this.id,
    required this.deviceId,
    required this.deviceName,
    required this.serverId,
    required this.serverName,
    required this.serverIp,
    required this.externalPort,
    required this.internalPort,
    required this.protocol,
    required this.status,
    required this.createdAt,
  });

  factory PortForwardRule.fromJson(Map<String, dynamic> json) {
    final dev = json['device'] as Map<String, dynamic>?;
    final srv = json['server'] as Map<String, dynamic>?;

    return PortForwardRule(
      id: json['id'] ?? '',
      deviceId: json['deviceId'] ?? '',
      deviceName: dev != null ? (dev['name'] ?? 'Device') : 'Device',
      serverId: json['serverId'] ?? '',
      serverName: srv != null ? (srv['name'] ?? 'Server') : 'Server',
      serverIp: srv != null ? (srv['publicIp'] ?? '') : '',
      externalPort: json['externalPort'] ?? 0,
      internalPort: json['internalPort'] ?? 0,
      protocol: json['protocol'] ?? 'BOTH',
      status: json['status'] ?? 'ACTIVE',
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt']) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  String get publicEndpoint => '$serverIp:$externalPort';
}
