import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/api_service.dart';
import '../../vpn/vpn_provider.dart';
import '../services/speed_test_service.dart';
import '../widgets/speedometer_gauge.dart';

class SpeedTestScreen extends StatefulWidget {
  const SpeedTestScreen({super.key});

  @override
  State<SpeedTestScreen> createState() => _SpeedTestScreenState();
}

class _SpeedTestScreenState extends State<SpeedTestScreen> {
  SpeedTestStage _stage = SpeedTestStage.idle;
  double _currentSpeedMbps = 0.0;
  int? _pingMs;
  int? _jitterMs;
  double? _finalDownloadMbps;
  double? _finalUploadMbps;
  bool _isRunning = false;

  void _runBenchmark() async {
    if (_isRunning) return;

    setState(() {
      _isRunning = true;
      _currentSpeedMbps = 0.0;
      _pingMs = null;
      _jitterMs = null;
      _finalDownloadMbps = null;
      _finalUploadMbps = null;
    });

    final api = context.read<ApiService>();
    final vpn = context.read<VpnProvider>();
    final service = SpeedTestService(api);

    final serverName = vpn.isConnected
        ? (vpn.currentTunnel?.serverName ?? 'Active VPN Server')
        : 'Direct Connection (No VPN)';

    try {
      final result = await service.runTest(
        serverName: serverName,
        onProgress: (stage, speed, ping, jitter) {
          if (mounted) {
            setState(() {
              _stage = stage;
              _currentSpeedMbps = speed;
              if (ping != null) _pingMs = ping;
              if (jitter != null) _jitterMs = jitter;
              if (stage == SpeedTestStage.uploading && _finalDownloadMbps == null) {
                _finalDownloadMbps = speed;
              }
            });
          }
        },
      );

      if (mounted) {
        setState(() {
          _stage = SpeedTestStage.complete;
          _currentSpeedMbps = 0.0;
          _pingMs = result.pingMs;
          _jitterMs = result.jitterMs;
          _finalDownloadMbps = result.downloadMbps;
          _finalUploadMbps = result.uploadMbps;
          _isRunning = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _stage = SpeedTestStage.error;
          _isRunning = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final vpn = context.watch<VpnProvider>();
    final isVpnActive = vpn.isConnected;
    final serverName = isVpnActive
        ? (vpn.currentTunnel?.serverName ?? 'Connected Server')
        : 'Direct Connection (VPN Disconnected)';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Speed & Latency Benchmark'),
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 12),

            // Server Context Banner
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isVpnActive
                      ? AppTheme.connectedGreen.withOpacity(0.4)
                      : AppTheme.surfaceLight,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isVpnActive ? Icons.shield : Icons.wifi,
                    color: isVpnActive ? AppTheme.connectedGreen : AppTheme.textSecondary,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isVpnActive ? 'TESTING THROUGH VPN TUNNEL' : 'TESTING DIRECT NETWORK',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                            color: isVpnActive ? AppTheme.connectedGreen : AppTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          serverName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: AppTheme.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const Spacer(),

            // Speedometer Gauge
            SpeedometerGauge(
              speedMbps: _currentSpeedMbps,
              maxSpeed: 100.0,
              stage: _stage,
            ),

            const Spacer(),

            // 4-Quadrant Metric Cards
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: _buildMetricCard(
                      title: 'PING',
                      value: _pingMs != null ? '$_pingMs ms' : '--',
                      icon: Icons.speed,
                      iconColor: AppTheme.warningYellow,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildMetricCard(
                      title: 'JITTER',
                      value: _jitterMs != null ? '$_jitterMs ms' : '--',
                      icon: Icons.timeline,
                      iconColor: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildMetricCard(
                      title: 'DOWNLOAD',
                      value: _finalDownloadMbps != null
                          ? '${_finalDownloadMbps!.toStringAsFixed(1)} M'
                          : '--',
                      icon: Icons.arrow_downward,
                      iconColor: AppTheme.connectedGreen,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildMetricCard(
                      title: 'UPLOAD',
                      value: _finalUploadMbps != null
                          ? '${_finalUploadMbps!.toStringAsFixed(1)} M'
                          : '--',
                      icon: Icons.arrow_upward,
                      iconColor: AppTheme.primary,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Start / Stop Benchmark Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isRunning ? AppTheme.disconnectedRed : AppTheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 4,
                  ),
                  onPressed: _isRunning ? null : _runBenchmark,
                  icon: _isRunning
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.play_arrow_rounded, size: 24),
                  label: Text(
                    _isRunning
                        ? 'Benchmarking Network...'
                        : _stage == SpeedTestStage.complete
                            ? 'Run Benchmark Again'
                            : 'Start Speed Test',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.surfaceLight),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: iconColor),
              const SizedBox(width: 4),
              Text(
                title,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                  color: AppTheme.textSecondary.withOpacity(0.8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
