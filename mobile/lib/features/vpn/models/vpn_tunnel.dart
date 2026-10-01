class VpnTunnel {
  final String serverName;
  final String countryCode;
  final String city;
  final String endpoint;
  final String serverPublicKey;
  final String clientAddressV4;
  final String clientAddressV6;
  final List<String> dns;
  final List<String> allowedIPs;
  final int mtu;
  final int keepalive;
  final bool isObfuscated;
  final String obfuscationProtocol;
  final Map<String, dynamic>? obfuscationParams;

  VpnTunnel({
    required this.serverName,
    required this.countryCode,
    required this.city,
    required this.endpoint,
    required this.serverPublicKey,
    required this.clientAddressV4,
    required this.clientAddressV6,
    required this.dns,
    required this.allowedIPs,
    required this.mtu,
    required this.keepalive,
    this.isObfuscated = false,
    this.obfuscationProtocol = 'NONE',
    this.obfuscationParams,
  });

  factory VpnTunnel.fromJson(Map<String, dynamic> json) {
    return VpnTunnel(
      serverName: json['serverName'] ?? '',
      countryCode: json['countryCode'] ?? '',
      city: json['city'] ?? '',
      endpoint: json['endpoint'] ?? '',
      serverPublicKey: json['serverPublicKey'] ?? '',
      clientAddressV4: json['clientAddressV4'] ?? '',
      clientAddressV6: json['clientAddressV6'] ?? '',
      dns: List<String>.from(json['dns'] ?? ['10.8.0.1']),
      allowedIPs: List<String>.from(json['allowedIPs'] ?? ['0.0.0.0/0', '::/0']),
      mtu: json['mtu'] ?? 1360,
      keepalive: json['keepalive'] ?? 25,
      isObfuscated: json['isObfuscated'] ?? false,
      obfuscationProtocol: json['obfuscationProtocol'] ?? 'NONE',
      obfuscationParams: json['obfuscationParams'] != null
          ? Map<String, dynamic>.from(json['obfuscationParams'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'serverName': serverName,
      'countryCode': countryCode,
      'city': city,
      'endpoint': endpoint,
      'serverPublicKey': serverPublicKey,
      'clientAddressV4': clientAddressV4,
      'clientAddressV6': clientAddressV6,
      'dns': dns,
      'allowedIPs': allowedIPs,
      'mtu': mtu,
      'keepalive': keepalive,
      'isObfuscated': isObfuscated,
      'obfuscationProtocol': obfuscationProtocol,
      if (obfuscationParams != null) 'obfuscationParams': obfuscationParams,
    };
  }
}
