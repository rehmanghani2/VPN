import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/services/vpn_bridge.dart';
import '../../auth/auth_provider.dart';
import '../../auth/screens/login_screen.dart';
import 'split_tunneling_screen.dart';
import 'threat_shield_screen.dart';
import '../../billing/screens/subscription_screen.dart';
import '../../devices/screens/devices_screen.dart';
import '../../speedtest/screens/speed_test_screen.dart';
import '../../diagnostics/screens/leak_test_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late bool _killSwitch;
  late bool _autoConnect;

  @override
  void initState() {
    super.initState();
    final storage = context.read<StorageService>();
    _killSwitch = storage.isKillSwitchEnabled;
    _autoConnect = storage.isAutoConnectEnabled;
  }

  @override
  Widget build(BuildContext context) {
    final storage = context.read<StorageService>();
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('VPN Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 1. Account Section
          const Text(
            'ACCOUNT & SUBSCRIPTION',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.surfaceLight),
            ),
            child: auth.isAuthenticated
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const CircleAvatar(
                            backgroundColor: AppTheme.primary,
                            child: Icon(Icons.person, color: Colors.white),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  auth.user?.email ?? '',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppTheme.primary.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        '${auth.user?.planType} PLAN (${auth.user?.maxDevices} MAX DEVICES)',
                                        style: const TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.primary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Upgrade / Manage Subscription button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const SubscriptionScreen(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.workspace_premium, size: 18),
                          label: Text(
                            auth.user?.planType == 'FREE'
                                ? 'Upgrade to Pro'
                                : 'Manage Subscription',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Manage Connected Devices button
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppTheme.surfaceLight),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const DevicesScreen(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.devices, size: 18, color: AppTheme.primary),
                          label: const Text('Connected Devices & Sessions'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppTheme.disconnectedRed),
                            foregroundColor: AppTheme.disconnectedRed,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: () => auth.logout(),
                          child: const Text('Log Out'),
                        ),
                      ),
                    ],
                  )
                : Column(
                    children: [
                      const Text(
                        'Log in to synchronize devices and enable high-speed servers.',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const LoginScreen()),
                            );
                          },
                          child: const Text('Sign In / Register'),
                        ),
                      ),
                    ],
                  ),
          ),

          const SizedBox(height: 24),

          // 2. Security Section
          const Text(
            'SECURITY & PROTOCOL',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.surfaceLight),
            ),
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text(
                    'Kill Switch',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                  subtitle: const Text(
                    'Blocks internet access if the VPN connection drops unexpectedly.',
                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                  activeColor: AppTheme.primary,
                  value: _killSwitch,
                  onChanged: (val) {
                    setState(() => _killSwitch = val);
                    storage.setKillSwitch(val);
                  },
                ),
                if (_killSwitch)
                  Padding(
                    padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
                    child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primary,
                          side: BorderSide(color: AppTheme.primary.withOpacity(0.5)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.security, size: 16),
                        label: const Text('Configure Android System Always-on VPN', style: TextStyle(fontSize: 12)),
                        onPressed: () => context.read<VpnBridge>().openVpnSettings(),
                      ),
                    ),
                  ),
                const Divider(height: 1, color: AppTheme.surfaceLight),
                ListTile(
                  title: const Text(
                    'Split Tunneling',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                  subtitle: Text(
                    storage.isSplitTunnelingEnabled
                        ? '${storage.splitTunnelingApps.length} apps configured (${storage.splitTunnelingMode == 'bypass' ? 'Bypassing' : 'Exclusive'})'
                        : 'Choose apps that bypass or exclusively use the VPN',
                    style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: storage.isSplitTunnelingEnabled
                              ? AppTheme.primary.withOpacity(0.2)
                              : AppTheme.surfaceLight,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          storage.isSplitTunnelingEnabled ? 'ON' : 'OFF',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: storage.isSplitTunnelingEnabled
                                ? AppTheme.primary
                                : AppTheme.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
                    ],
                  ),
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SplitTunnelingScreen()),
                    );
                    setState(() {});
                  },
                ),
                const Divider(height: 1, color: AppTheme.surfaceLight),
                ListTile(
                  title: const Text(
                    'DNS Threat Shield',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                  subtitle: Text(
                    storage.threatShieldLevel == 'all'
                        ? 'Full Shield: Blocking Ads, Trackers & Malware'
                        : storage.threatShieldLevel == 'malware_only'
                            ? 'Malware & Phishing Protection'
                            : 'Disabled (Standard Recursive DNS)',
                    style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: storage.threatShieldLevel != 'off'
                              ? AppTheme.connectedGreen.withOpacity(0.2)
                              : AppTheme.surfaceLight,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          storage.threatShieldLevel == 'all'
                              ? 'MAX'
                              : storage.threatShieldLevel == 'malware_only'
                                  ? 'MALWARE'
                                  : 'OFF',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: storage.threatShieldLevel != 'off'
                                ? AppTheme.connectedGreen
                                : AppTheme.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
                    ],
                  ),
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ThreatShieldScreen()),
                    );
                    setState(() {});
                  },
                ),
                const Divider(height: 1, color: AppTheme.surfaceLight),
                SwitchListTile(
                  title: const Text(
                    'Auto-Connect',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                  subtitle: const Text(
                    'Automatically secures connection when joining untrusted Wi-Fi.',
                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                  activeColor: AppTheme.primary,
                  value: _autoConnect,
                  onChanged: (val) {
                    setState(() => _autoConnect = val);
                    storage.setAutoConnect(val);
                  },
                ),
                const Divider(height: 1, color: AppTheme.surfaceLight),
                ListTile(
                  title: const Text(
                    'VPN Protocol',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                  subtitle: Text(
                    storage.isStealthModeEnabled
                        ? 'Stealth Camouflage (Anti-DPI, HTTPS Port 443)'
                        : 'WireGuard Standard (ChaCha20-Poly1305, UDP)',
                    style: TextStyle(
                      fontSize: 12,
                      color: storage.isStealthModeEnabled ? AppTheme.warningYellow : AppTheme.textSecondary,
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: storage.isStealthModeEnabled
                              ? AppTheme.warningYellow.withOpacity(0.15)
                              : AppTheme.primary.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          storage.isStealthModeEnabled ? 'STEALTH' : 'STANDARD',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: storage.isStealthModeEnabled
                                ? AppTheme.warningYellow
                                : AppTheme.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
                    ],
                  ),
                  onTap: () => _showProtocolSelector(context, storage),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // 3. Tools & Diagnostics Section
          const Text(
            'TOOLS & BENCHMARKS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.surfaceLight),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.speed, color: AppTheme.primary, size: 20),
                  ),
                  title: const Text(
                    'Speed & Latency Test',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                  subtitle: const Text(
                    'Benchmark live ping jitter, download & upload Mbps through VPN',
                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                  trailing: const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SpeedTestScreen()),
                    );
                  },
                ),
                const Divider(height: 1, color: AppTheme.surfaceLight),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.connectedGreen.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.verified_user_rounded, color: AppTheme.connectedGreen, size: 20),
                  ),
                  title: const Text(
                    'Zero-Leak Privacy Audit',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                  subtitle: const Text(
                    'Audit IPv4 exposure, DNS hijack, IPv6 leaks, and WebRTC STUN isolation',
                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                  trailing: const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const LeakTestScreen()),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showProtocolSelector(BuildContext context, StorageService storage) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Select VPN Protocol',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Choose how your tunnel traffic is transmitted across intermediate firewalls and ISPs.',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 16),
                RadioListTile<String>(
                  value: 'wireguard',
                  groupValue: storage.vpnProtocol,
                  activeColor: AppTheme.primary,
                  title: const Text('WireGuard Standard (Recommended for Speed)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: const Text('High-performance UDP transport. Best for gaming, 4K streaming, and open internet connections.', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  onChanged: (val) async {
                    await storage.setVpnProtocol(val!);
                    if (mounted) setState(() {});
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                ),
                const Divider(height: 1, color: AppTheme.surfaceLight),
                RadioListTile<String>(
                  value: 'stealth_obfuscated',
                  groupValue: storage.vpnProtocol,
                  activeColor: AppTheme.warningYellow,
                  title: const Row(
                    children: [
                      Text('Stealth Camouflage (Anti-DPI / Censorship)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      SizedBox(width: 6),
                      Icon(Icons.shield, size: 14, color: AppTheme.warningYellow),
                    ],
                  ),
                  subtitle: const Text('Disguises VPN traffic as standard HTTPS browsing over TCP/UDP Port 443. Bypasses restrictive school/work firewalls, deep-packet inspection, and ISP throttling.', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  onChanged: (val) async {
                    await storage.setVpnProtocol(val!);
                    if (mounted) setState(() {});
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
