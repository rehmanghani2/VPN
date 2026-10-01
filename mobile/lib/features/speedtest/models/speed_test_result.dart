class SpeedTestResult {
  final int pingMs;
  final int jitterMs;
  final double downloadMbps;
  final double uploadMbps;
  final String serverName;
  final DateTime timestamp;

  SpeedTestResult({
    required this.pingMs,
    required this.jitterMs,
    required this.downloadMbps,
    required this.uploadMbps,
    required this.serverName,
    required this.timestamp,
  });
}
