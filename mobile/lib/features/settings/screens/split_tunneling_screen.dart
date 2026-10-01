import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/services/vpn_bridge.dart';

class SplitTunnelingScreen extends StatefulWidget {
  const SplitTunnelingScreen({super.key});

  @override
  State<SplitTunnelingScreen> createState() => _SplitTunnelingScreenState();
}

class _SplitTunnelingScreenState extends State<SplitTunnelingScreen> {
  late bool _enabled;
  late String _mode; // 'bypass' or 'only_vpn'
  late bool _bypassLan;
  late Set<String> _selectedApps;

  List<Map<String, String>> _allApps = [];
  String _searchQuery = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    final storage = context.read<StorageService>();
    _enabled = storage.isSplitTunnelingEnabled;
    _mode = storage.splitTunnelingMode;
    _bypassLan = storage.isLocalLanBypassEnabled;
    _selectedApps = storage.splitTunnelingApps.toSet();

    _loadApps();
  }

  Future<void> _loadApps() async {
    final bridge = context.read<VpnBridge>();
    final apps = await bridge.getInstalledApps();
    if (mounted) {
      setState(() {
        _allApps = apps;
        _isLoading = false;
      });
    }
  }

  Future<void> _saveSettings() async {
    final storage = context.read<StorageService>();
    await storage.setSplitTunneling(_enabled);
    await storage.setSplitTunnelingMode(_mode);
    await storage.setSplitTunnelingApps(_selectedApps.toList());
    await storage.setLocalLanBypass(_bypassLan);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Split Tunneling rules updated'),
          backgroundColor: AppTheme.connectedGreen,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredApps = _allApps.where((app) {
      final name = (app['appName'] ?? '').toLowerCase();
      final pkg = (app['packageName'] ?? '').toLowerCase();
      final q = _searchQuery.toLowerCase();
      return name.contains(q) || pkg.contains(q);
    }).toList();

    return WillPopScope(
      onWillPop: () async {
        await _saveSettings();
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Split Tunneling'),
          actions: [
            if (_selectedApps.isNotEmpty)
              TextButton(
                onPressed: () {
                  setState(() => _selectedApps.clear());
                },
                child: const Text('Clear All', style: TextStyle(color: AppTheme.disconnectedRed)),
              ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 1. Master Toggle
            Container(
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _enabled ? AppTheme.primary.withOpacity(0.5) : AppTheme.surfaceLight,
                ),
              ),
              child: SwitchListTile(
                title: const Text(
                  'Enable Split Tunneling',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                subtitle: const Text(
                  'Select specific applications that bypass or exclusively use the VPN tunnel.',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
                activeColor: AppTheme.primary,
                value: _enabled,
                onChanged: (val) {
                  setState(() => _enabled = val);
                },
              ),
            ),

            if (_enabled) ...[
              const SizedBox(height: 16),

              // 2. Mode Selector
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.surfaceLight),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ROUTING POLICY',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    RadioListTile<String>(
                      title: const Text(
                        'Bypass VPN (Recommended)',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      subtitle: const Text(
                        'Selected apps connect directly to the internet outside the VPN tunnel (ideal for banking, local delivery, and gaming).',
                        style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                      ),
                      activeColor: AppTheme.primary,
                      value: 'bypass',
                      groupValue: _mode,
                      onChanged: (val) => setState(() => _mode = val!),
                    ),
                    const Divider(height: 1, color: AppTheme.surfaceLight),
                    RadioListTile<String>(
                      title: const Text(
                        'Only Route Selected Apps',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      subtitle: const Text(
                        'Only selected apps use the VPN tunnel; all other internet traffic remains unencrypted.',
                        style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                      ),
                      activeColor: AppTheme.primary,
                      value: 'only_vpn',
                      groupValue: _mode,
                      onChanged: (val) => setState(() => _mode = val!),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // 3. Local LAN Bypass
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.surfaceLight),
                ),
                child: SwitchListTile(
                  title: const Text(
                    'Bypass Local Network (LAN)',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                  subtitle: const Text(
                    'Allows continuous access to Wi-Fi printers, smart home devices, and local file servers while connected.',
                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                  activeColor: AppTheme.primary,
                  value: _bypassLan,
                  onChanged: (val) => setState(() => _bypassLan = val),
                ),
              ),

              const SizedBox(height: 20),

              // 4. App Search & Count Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'APPLICATIONS',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${_selectedApps.length} selected',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Search input
              TextField(
                decoration: InputDecoration(
                  hintText: 'Search installed applications...',
                  prefixIcon: const Icon(Icons.search, size: 20, color: AppTheme.textSecondary),
                  filled: true,
                  fillColor: AppTheme.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.surfaceLight),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.surfaceLight),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                onChanged: (val) => setState(() => _searchQuery = val),
              ),

              const SizedBox(height: 12),

              // 5. Installed Apps List
              if (_isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (filteredApps.isEmpty)
                Container(
                  padding: const EdgeInsets.all(32),
                  alignment: Alignment.center,
                  child: const Text(
                    'No matching applications found.',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                )
              else
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.surfaceLight),
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: filteredApps.length,
                    separatorBuilder: (_, index) => const Divider(height: 1, color: AppTheme.surfaceLight),
                    itemBuilder: (context, index) {
                      final app = filteredApps[index];
                      final pkg = app['packageName'] ?? '';
                      final name = app['appName'] ?? pkg;
                      final isSelected = _selectedApps.contains(pkg);

                      return CheckboxListTile(
                        value: isSelected,
                        activeColor: AppTheme.primary,
                        title: Text(
                          name,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                        subtitle: Text(
                          pkg,
                          style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        secondary: CircleAvatar(
                          backgroundColor: AppTheme.surfaceLight,
                          child: Text(
                            name.isNotEmpty ? name[0].toUpperCase() : 'A',
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        onChanged: (bool? checked) {
                          setState(() {
                            if (checked == true) {
                              _selectedApps.add(pkg);
                            } else {
                              _selectedApps.remove(pkg);
                            }
                          });
                        },
                      );
                    },
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
