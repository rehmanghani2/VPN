class VpnStatistics {
  final int totalRxBytes;
  final int totalTxBytes;
  final double rxSpeed; // bytes per second
  final double txSpeed; // bytes per second
  final int pingMs;
  final int lastHandshakeSeconds;
  final List<double> rxHistory; // download speed history (last 30 ticks)
  final List<double> txHistory; // upload speed history (last 30 ticks)

  const VpnStatistics({
    this.totalRxBytes = 0,
    this.totalTxBytes = 0,
    this.rxSpeed = 0,
    this.txSpeed = 0,
    this.pingMs = 0,
    this.lastHandshakeSeconds = 0,
    this.rxHistory = const [],
    this.txHistory = const [],
  });

  // Human-readable formatters
  static String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  static String formatSpeed(double bytesPerSec) {
    if (bytesPerSec < 1024) return '${bytesPerSec.toStringAsFixed(0)} B/s';
    if (bytesPerSec < 1024 * 1024) {
      return '${(bytesPerSec / 1024).toStringAsFixed(1)} KB/s';
    }
    return '${(bytesPerSec / (1024 * 1024)).toStringAsFixed(1)} MB/s';
  }

  String get downloadSpeedStr => formatSpeed(rxSpeed);
  String get uploadSpeedStr => formatSpeed(txSpeed);
  String get totalDownloadStr => formatBytes(totalRxBytes);
  String get totalUploadStr => formatBytes(totalTxBytes);

  VpnStatistics copyWith({
    int? totalRxBytes,
    int? totalTxBytes,
    double? rxSpeed,
    double? txSpeed,
    int? pingMs,
    int? lastHandshakeSeconds,
    List<double>? rxHistory,
    List<double>? txHistory,
  }) {
    return VpnStatistics(
      totalRxBytes: totalRxBytes ?? this.totalRxBytes,
      totalTxBytes: totalTxBytes ?? this.totalTxBytes,
      rxSpeed: rxSpeed ?? this.rxSpeed,
      txSpeed: txSpeed ?? this.txSpeed,
      pingMs: pingMs ?? this.pingMs,
      lastHandshakeSeconds: lastHandshakeSeconds ?? this.lastHandshakeSeconds,
      rxHistory: rxHistory ?? this.rxHistory,
      txHistory: txHistory ?? this.txHistory,
    );
  }
}
