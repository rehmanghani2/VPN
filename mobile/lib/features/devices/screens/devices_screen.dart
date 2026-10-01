import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/constants/api_constants.dart';
import '../../auth/auth_provider.dart';
import '../../billing/screens/subscription_screen.dart';

class DevicesScreen extends StatefulWidget {
  const DevicesScreen({super.key});

  @override
  State<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends State<DevicesScreen> {
  bool _isLoading = true;
  List<dynamic> _devices = [];
  String? _currentDeviceUuid;

  @override
  void initState() {
    super.initState();
    _currentDeviceUuid = context.read<StorageService>().getOrCreateDeviceUuid();
    _loadDevices();
  }

  Future<void> _loadDevices() async {
    setState(() => _isLoading = true);
    final api = context.read<ApiService>();

    try {
      final res = await api.client.get(ApiConstants.devices);
      if (mounted) {
        setState(() {
          _devices = res.data as List<dynamic>;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _disconnectDevice(String deviceId, String name) async {
    final api = context.read<ApiService>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Disconnect Device?'),
        content: Text(
          'Terminate active VPN session for "$name"? The device will be disconnected from the VPN tunnel.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.disconnectedRed,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await api.client.post('${ApiConstants.devices}/$deviceId/disconnect');
      await _loadDevices();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.connectedGreen,
            content: Text('Device "$name" disconnected successfully.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.disconnectedRed,
            content: Text('Failed to disconnect: $e'),
          ),
        );
      }
    }
  }

  Future<void> _removeDevice(String deviceId, String name) async {
    final api = context.read<ApiService>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Remove Device?'),
        content: Text(
          'Are you sure you want to remove "$name"? It will be deregistered from your account.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.disconnectedRed,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await api.client.delete('${ApiConstants.devices}/$deviceId');
      await _loadDevices();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.surfaceLight,
            content: Text('Device "$name" removed.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.disconnectedRed,
            content: Text('Failed to remove device: $e'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final maxDevices = auth.user?.maxDevices ?? 1;
    final planType = auth.user?.planType ?? 'FREE';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Connected Devices'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDevices,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primary),
            )
          : RefreshIndicator(
              onRefresh: _loadDevices,
              color: AppTheme.primary,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Quota Overview Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.surfaceLight),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '$planType PLAN',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.2,
                                    color: AppTheme.primary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${_devices.length} of $maxDevices Devices Registered',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            if (planType == 'FREE')
                              TextButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const SubscriptionScreen(),
                                    ),
                                  );
                                },
                                style: TextButton.styleFrom(
                                  foregroundColor: AppTheme.primary,
                                ),
                                child: const Row(
                                  children: [
                                    Text('Upgrade'),
                                    SizedBox(width: 4),
                                    Icon(Icons.arrow_forward_ios, size: 12),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: maxDevices > 0
                                ? (_devices.length / maxDevices).clamp(0.0, 1.0)
                                : 0.0,
                            minHeight: 6,
                            backgroundColor: AppTheme.background,
                            color: _devices.length >= maxDevices
                                ? AppTheme.disconnectedRed
                                : AppTheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),
                  const Text(
                    'REGISTERED HARDWARE DEVICES',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 10),

                  if (_devices.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(24),
                      alignment: Alignment.center,
                      child: const Text(
                        'No devices found',
                        style: TextStyle(color: AppTheme.textSecondary),
                      ),
                    ),

                  ..._devices.map((d) {
                    final isThisDevice =
                        d['deviceIdentifier'] == _currentDeviceUuid;
                    final isConnected = d['isConnected'] == true;
                    final session = d['activeSession'];
                    final server = session?['server'];
                    final platform = (d['platform'] ?? 'OTHER').toString();

                    IconData platformIcon = Icons.devices;
                    if (platform.contains('ANDROID')) {
                      platformIcon = Icons.phone_android;
                    } else if (platform.contains('WINDOWS')) {
                      platformIcon = Icons.laptop_windows;
                    } else if (platform.contains('IOS')) {
                      platformIcon = Icons.phone_iphone;
                    }

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isThisDevice
                              ? AppTheme.primary.withOpacity(0.6)
                              : AppTheme.surfaceLight,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppTheme.background,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  platformIcon,
                                  color: isConnected
                                      ? AppTheme.connectedGreen
                                      : AppTheme.textSecondary,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          d['name'] ?? 'Device',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                          ),
                                        ),
                                        if (isThisDevice) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: AppTheme.primary
                                                  .withOpacity(0.2),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: const Text(
                                              'THIS DEVICE',
                                              style: TextStyle(
                                                fontSize: 9,
                                                fontWeight: FontWeight.bold,
                                                color: AppTheme.primary,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      isConnected
                                          ? '🟢 Connected to ${server?['name'] ?? 'VPN'}'
                                          : '⚪ Idle / Disconnected',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: isConnected
                                            ? AppTheme.connectedGreen
                                            : AppTheme.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert,
                                    color: AppTheme.textSecondary),
                                color: AppTheme.surface,
                                onSelected: (action) {
                                  if (action == 'disconnect') {
                                    _disconnectDevice(
                                        d['id'], d['name'] ?? 'Device');
                                  } else if (action == 'remove') {
                                    _removeDevice(
                                        d['id'], d['name'] ?? 'Device');
                                  }
                                },
                                itemBuilder: (ctx) => [
                                  if (isConnected)
                                    const PopupMenuItem(
                                      value: 'disconnect',
                                      child: Row(
                                        children: [
                                          Icon(Icons.stop_circle,
                                              color: AppTheme.disconnectedRed,
                                              size: 18),
                                          SizedBox(width: 8),
                                          Text('Disconnect VPN'),
                                        ],
                                      ),
                                    ),
                                  if (!isThisDevice)
                                    const PopupMenuItem(
                                      value: 'remove',
                                      child: Row(
                                        children: [
                                          Icon(Icons.delete,
                                              color: AppTheme.disconnectedRed,
                                              size: 18),
                                          SizedBox(width: 8),
                                          Text('Remove Device'),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                          if (isConnected && session != null) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppTheme.background,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.vpn_key,
                                      size: 12, color: AppTheme.primary),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Assigned IP: ${session['allocatedIpV4']}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppTheme.textSecondary,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    '${server?['city'] ?? ''}, ${server?['countryCode'] ?? ''}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
    );
  }
}
