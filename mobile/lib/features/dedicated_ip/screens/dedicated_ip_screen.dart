import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/api_service.dart';
import '../../vpn/vpn_provider.dart';
import '../models/dedicated_ip_model.dart';
import '../services/dedicated_ip_service.dart';

class DedicatedIpScreen extends StatefulWidget {
  const DedicatedIpScreen({super.key});

  @override
  State<DedicatedIpScreen> createState() => _DedicatedIpScreenState();
}

class _DedicatedIpScreenState extends State<DedicatedIpScreen> {
  late final DedicatedIpService _service;
  List<DedicatedIpModel> _dedicatedIps = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _service = DedicatedIpService(context.read<ApiService>());
    _loadDedicatedIps();
  }

  Future<void> _loadDedicatedIps() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final list = await _service.fetchMyDedicatedIps();
      if (mounted) {
        setState(() {
          _dedicatedIps = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _showReserveModal() async {
    List<Map<String, dynamic>> regions = [];
    try {
      regions = await _service.fetchAvailableRegions();
    } catch (_) {}

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Reserve a Dedicated IP',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              const Text(
                'Get an exclusive, clean static IP address reserved solely for your account.',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 16),
              if (regions.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('No servers available for dedicated IP reservation at this time.'),
                )
              else
                ...regions.map((r) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.location_on, color: AppTheme.primary, size: 20),
                      ),
                      title: Text('${r['name']} (${r['city']})', style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text('Gateway: ${r['publicIp']}', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                      trailing: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        ),
                        onPressed: () async {
                          Navigator.pop(ctx);
                          try {
                            await _service.reserveDedicatedIp(r['id']);
                            _loadDedicatedIps();
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Dedicated IP successfully reserved!'),
                                  backgroundColor: AppTheme.connectedGreen,
                                ),
                              );
                            }
                          } catch (err) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Reservation failed: $err'), backgroundColor: AppTheme.disconnectedRed),
                              );
                            }
                          }
                        },
                        child: const Text('RESERVE', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    )),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dedicated IP'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loadDedicatedIps,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.primary,
        icon: const Icon(Icons.add_moderator, color: Colors.white),
        label: const Text('Get Dedicated IP', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        onPressed: _showReserveModal,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, color: AppTheme.disconnectedRed, size: 48),
                      const SizedBox(height: 12),
                      const Text('Error loading dedicated IPs', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Text(_errorMessage!, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                      const SizedBox(height: 16),
                      ElevatedButton(onPressed: _loadDedicatedIps, child: const Text('RETRY')),
                    ],
                  ),
                )
              : _dedicatedIps.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                      itemCount: _dedicatedIps.length,
                      itemBuilder: (ctx, i) => _buildDedicatedIpCard(_dedicatedIps[i]),
                    ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.verified_user_rounded, color: AppTheme.primary, size: 54),
            ),
            const SizedBox(height: 20),
            const Text(
              'No Dedicated IPs Active',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'A Dedicated IP is an exclusive, private static IP address for your account only. It eliminates CAPTCHAs, prevents IP blacklisting, and allows accessing IP-restricted corporate networks.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('RESERVE DEDICATED IP'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              onPressed: _showReserveModal,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDedicatedIpCard(DedicatedIpModel item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primary.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppTheme.primary.withOpacity(0.4)),
                    ),
                    child: const Text(
                      'EXCLUSIVE STATIC IP',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.primary),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${item.serverName} (${item.serverCity})',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.connectedGreen.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  item.status,
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.connectedGreen),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Your Dedicated Public IP', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                  const SizedBox(height: 2),
                  Text(
                    item.publicIp,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.8),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.copy, color: AppTheme.primary, size: 20),
                tooltip: 'Copy IP',
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: item.publicIp));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Copied ${item.publicIp} to clipboard')),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: AppTheme.surfaceLight),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                item.expiresAt != null
                    ? 'Renews: ${item.expiresAt!.year}-${item.expiresAt!.month.toString().padLeft(2, '0')}-${item.expiresAt!.day.toString().padLeft(2, '0')}'
                    : 'Active Subscription',
                style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.flash_on, size: 14),
                label: const Text('CONNECT WITH THIS IP', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.connectedGreen,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                ),
                onPressed: () {
                  final vpn = context.read<VpnProvider>();
                  final target = vpn.servers.cast<dynamic>().firstWhere(
                        (s) => s.id == item.serverId,
                        orElse: () => null,
                      );
                  if (target != null) {
                    vpn.selectServer(target);
                    vpn.connect();
                    Navigator.pop(context);
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
