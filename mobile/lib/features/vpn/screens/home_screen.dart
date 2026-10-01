import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/storage_service.dart';
import '../vpn_provider.dart';
import '../widgets/telemetry_graph.dart';
import 'servers_screen.dart';
import '../../settings/screens/settings_screen.dart';
import '../../speedtest/screens/speed_test_screen.dart';
import '../../diagnostics/screens/leak_test_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(d.inHours);
    final minutes = twoDigits(d.inMinutes.remainder(60));
    final seconds = twoDigits(d.inSeconds.remainder(60));
    return '$hours:$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final vpn = context.watch<VpnProvider>();

    final isConnected = vpn.isConnected;
    final isConnecting = vpn.isConnecting;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.shield_rounded, color: AppTheme.primary, size: 20),
            ),
            const SizedBox(width: 8),
            const Text(
              'ANTIGRAVITY VPN',
              style: TextStyle(letterSpacing: 1.5, fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.speed, color: AppTheme.textSecondary),
            tooltip: 'Speed & Latency Benchmark',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SpeedTestScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.verified_user_rounded, color: AppTheme.textSecondary),
            tooltip: 'Zero-Leak Privacy Audit',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LeakTestScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.tune_rounded, color: AppTheme.textSecondary),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            children: [
              // 1. Connection Status Banner
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isConnected
                      ? AppTheme.connectedGreen.withOpacity(0.15)
                      : isConnecting
                          ? AppTheme.primary.withOpacity(0.15)
                          : AppTheme.surfaceLight.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isConnected
                        ? AppTheme.connectedGreen.withOpacity(0.4)
                        : isConnecting
                            ? AppTheme.primary.withOpacity(0.4)
                            : Colors.transparent,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isConnected
                            ? AppTheme.connectedGreen
                            : isConnecting
                                ? AppTheme.primary
                                : AppTheme.disconnectedRed,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isConnected
                          ? 'PROTECTED & ENCRYPTED'
                          : isConnecting
                              ? 'SECURING CONNECTION...'
                              : 'UNPROTECTED',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                        color: isConnected
                            ? AppTheme.connectedGreen
                            : isConnecting
                                ? AppTheme.primary
                                : AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // 2. Large Interactive Power / Connect Button
              Center(
                child: GestureDetector(
                  onTap: isConnecting ? null : () => vpn.toggleConnect(),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.surface,
                      border: Border.all(
                        color: isConnected
                            ? AppTheme.connectedGreen
                            : isConnecting
                                ? AppTheme.primary
                                : AppTheme.surfaceLight,
                        width: 4,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: isConnected
                              ? AppTheme.connectedGreen.withOpacity(0.35)
                              : isConnecting
                                  ? AppTheme.primary.withOpacity(0.35)
                                  : Colors.black.withOpacity(0.4),
                          blurRadius: 36,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: Center(
                      child: isConnecting
                          ? const SizedBox(
                              width: 64,
                              height: 64,
                              child: CircularProgressIndicator(
                                strokeWidth: 4,
                                valueColor: AlwaysStoppedAnimation(AppTheme.primary),
                              ),
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.power_settings_new_rounded,
                                  size: 72,
                                  color: isConnected
                                      ? AppTheme.connectedGreen
                                      : AppTheme.textSecondary,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  isConnected ? 'DISCONNECT' : 'QUICK CONNECT',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.5,
                                    color: isConnected
                                        ? AppTheme.connectedGreen
                                        : AppTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Connection Duration
              if (isConnected) ...[
                Text(
                  _formatDuration(vpn.connectedDuration),
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    fontFeatures: [],
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Connection Duration',
                  style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                ),
              ] else ...[
                const Text(
                  'WireGuard Protocol Active',
                  style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
                ),
              ],

              const SizedBox(height: 16),

              // Active Features Badges (Kill Switch, Split Tunneling, Stealth Mode)
              Consumer<StorageService>(
                builder: (context, storage, _) {
                  final hasKillSwitch = storage.isKillSwitchEnabled;
                  final hasSplit = storage.isSplitTunnelingEnabled && storage.splitTunnelingApps.isNotEmpty;
                  final hasStealth = storage.isStealthModeEnabled || (vpn.currentTunnel?.isObfuscated == true);

                  if (!hasKillSwitch && !hasSplit && !hasStealth) return const SizedBox.shrink();

                  return Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      if (hasKillSwitch)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.shield_outlined, size: 14, color: AppTheme.primary),
                              SizedBox(width: 4),
                              Text('Kill Switch', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primary)),
                            ],
                          ),
                        ),
                      if (hasSplit)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.connectedGreen.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.connectedGreen.withOpacity(0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.alt_route_rounded, size: 14, color: AppTheme.connectedGreen),
                              const SizedBox(width: 4),
                              Text('Split (${storage.splitTunnelingApps.length})', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.connectedGreen)),
                            ],
                          ),
                        ),
                      if (hasStealth)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.warningYellow.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.warningYellow.withOpacity(0.3)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.shield, size: 14, color: AppTheme.warningYellow),
                              SizedBox(width: 4),
                              Text('Stealth Anti-DPI', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.warningYellow)),
                            ],
                          ),
                        ),
                    ],
                  );
                },
              ),

              // Live Telemetry & Throughput Graph (Phase 5)
              if (isConnected) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.surfaceLight.withOpacity(0.5)),
                  ),
                  child: Column(
                    children: [
                      // Speeds & Ping Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Download speed
                          Row(
                            children: [
                              const Icon(Icons.arrow_downward_rounded, size: 16, color: AppTheme.primary),
                              const SizedBox(width: 4),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    vpn.statistics.downloadSpeedStr,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textPrimary),
                                  ),
                                  Text(
                                    'Down (${vpn.statistics.totalDownloadStr})',
                                    style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          // Upload speed
                          Row(
                            children: [
                              const Icon(Icons.arrow_upward_rounded, size: 16, color: AppTheme.accent),
                              const SizedBox(width: 4),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    vpn.statistics.uploadSpeedStr,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textPrimary),
                                  ),
                                  Text(
                                    'Up (${vpn.statistics.totalUploadStr})',
                                    style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          // Latency & Handshake
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 7,
                                    height: 7,
                                    decoration: const BoxDecoration(color: AppTheme.connectedGreen, shape: BoxShape.circle),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${vpn.statistics.pingMs} ms',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.connectedGreen),
                                  ),
                                ],
                              ),
                              Text(
                                'Handshake: ${vpn.statistics.lastHandshakeSeconds}s ago',
                                style: const TextStyle(fontSize: 9.5, color: AppTheme.textSecondary),
                              ),
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),

                      // Live Throughput Graph
                      TelemetryGraph(
                        rxHistory: vpn.statistics.rxHistory,
                        txHistory: vpn.statistics.txHistory,
                        height: 60,
                      ),
                    ],
                  ),
                ),
              ],

              const Spacer(),

              // 3. Server Selector Card
              InkWell(
                onTap: isConnecting
                    ? null
                    : () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const ServersScreen()),
                        );
                      },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.surfaceLight),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceLight.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(
                            vpn.selectedServer?.flagEmoji ?? '⚡',
                            style: const TextStyle(fontSize: 22),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              vpn.selectedServer == null
                                  ? 'Fastest Location (Smart Connect)'
                                  : '${vpn.selectedServer!.countryName} (${vpn.selectedServer!.city})',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              vpn.selectedServer == null
                                  ? 'Automatically connects to lowest latency'
                                  : 'WireGuard • ${vpn.selectedServer!.loadPercentage}% Server Load',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios_rounded,
                          size: 16, color: AppTheme.textSecondary),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
