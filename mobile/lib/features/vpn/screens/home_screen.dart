import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/vpn_bridge.dart';
import '../vpn_provider.dart';
import '../../auth/auth_provider.dart';
import 'servers_screen.dart';
import '../../settings/screens/settings_screen.dart';

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
    final auth = context.watch<AuthProvider>();

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
