import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/services/vpn_bridge.dart';
import '../../auth/auth_provider.dart';
import '../../auth/screens/login_screen.dart';
import 'split_tunneling_screen.dart';

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
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
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
                const ListTile(
                  title: Text(
                    'VPN Protocol',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                  subtitle: Text(
                    'WireGuard (ChaCha20-Poly1305 encryption, UDP)',
                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                  trailing: Icon(Icons.lock_rounded, size: 18, color: AppTheme.primary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
