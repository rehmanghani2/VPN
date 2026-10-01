class LeakAuditResult {
  final IpAudit ipAudit;
  final DnsAudit dnsAudit;
  final Ipv6Audit ipv6Audit;
  final WebrtcAudit webrtcAudit;
  final String overallVerdict;
  final DateTime timestamp;

  LeakAuditResult({
    required this.ipAudit,
    required this.dnsAudit,
    required this.ipv6Audit,
    required this.webrtcAudit,
    required this.overallVerdict,
    required this.timestamp,
  });

  factory LeakAuditResult.fromJson(Map<String, dynamic> json) {
    return LeakAuditResult(
      ipAudit: IpAudit.fromJson(json['ipAudit'] ?? {}),
      dnsAudit: DnsAudit.fromJson(json['dnsAudit'] ?? {}),
      ipv6Audit: Ipv6Audit.fromJson(json['ipv6Audit'] ?? {}),
      webrtcAudit: WebrtcAudit.fromJson(json['webrtcAudit'] ?? {}),
      overallVerdict: json['overallVerdict'] ?? 'UNKNOWN',
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp']) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  bool get isFullySecured =>
      !ipAudit.leakDetected &&
      !dnsAudit.dnsLeakDetected &&
      !ipv6Audit.ipv6Leaked &&
      webrtcAudit.webrtcSecured;

  int get privacyScore {
    int score = 0;
    if (!ipAudit.leakDetected) score += 35;
    if (!dnsAudit.dnsLeakDetected) score += 30;
    if (!ipv6Audit.ipv6Leaked) score += 20;
    if (webrtcAudit.webrtcSecured) score += 15;
    return score;
  }
}

class IpAudit {
  final String detectedIp;
  final bool isEncrypted;
  final bool leakDetected;
  final String protectionGrade;

  IpAudit({
    required this.detectedIp,
    required this.isEncrypted,
    required this.leakDetected,
    required this.protectionGrade,
  });

  factory IpAudit.fromJson(Map<String, dynamic> json) {
    return IpAudit(
      detectedIp: json['detectedIp'] ?? 'Unknown',
      isEncrypted: json['isEncrypted'] ?? false,
      leakDetected: json['leakDetected'] ?? false,
      protectionGrade: json['protectionGrade'] ?? 'F',
    );
  }
}

class DnsAudit {
  final int resolversDetected;
  final List<DnsServerInfo> servers;
  final bool dnsLeakDetected;
  final bool dnssecActive;

  DnsAudit({
    required this.resolversDetected,
    required this.servers,
    required this.dnsLeakDetected,
    required this.dnssecActive,
  });

  factory DnsAudit.fromJson(Map<String, dynamic> json) {
    final list = (json['servers'] as List<dynamic>?) ?? [];
    return DnsAudit(
      resolversDetected: json['resolversDetected'] ?? 0,
      servers: list.map((e) => DnsServerInfo.fromJson(e as Map<String, dynamic>)).toList(),
      dnsLeakDetected: json['dnsLeakDetected'] ?? false,
      dnssecActive: json['dnssecActive'] ?? false,
    );
  }
}

class DnsServerInfo {
  final String ip;
  final String hostname;
  final String country;

  DnsServerInfo({
    required this.ip,
    required this.hostname,
    required this.country,
  });

  factory DnsServerInfo.fromJson(Map<String, dynamic> json) {
    return DnsServerInfo(
      ip: json['ip'] ?? '',
      hostname: json['hostname'] ?? '',
      country: json['country'] ?? '',
    );
  }
}

class Ipv6Audit {
  final bool ipv6Leaked;
  final String status;

  Ipv6Audit({
    required this.ipv6Leaked,
    required this.status,
  });

  factory Ipv6Audit.fromJson(Map<String, dynamic> json) {
    return Ipv6Audit(
      ipv6Leaked: json['ipv6Leaked'] ?? false,
      status: json['status'] ?? 'DISABLED',
    );
  }
}

class WebrtcAudit {
  final bool stunCandidateLeak;
  final List<String> exposedLocalIps;
  final bool webrtcSecured;

  WebrtcAudit({
    required this.stunCandidateLeak,
    required this.exposedLocalIps,
    required this.webrtcSecured,
  });

  factory WebrtcAudit.fromJson(Map<String, dynamic> json) {
    final list = (json['exposedLocalIps'] as List<dynamic>?) ?? [];
    return WebrtcAudit(
      stunCandidateLeak: json['stunCandidateLeak'] ?? false,
      exposedLocalIps: list.map((e) => e.toString()).toList(),
      webrtcSecured: json['webrtcSecured'] ?? true,
    );
  }
}
