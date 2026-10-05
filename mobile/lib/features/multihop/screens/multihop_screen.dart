import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/storage_service.dart';
import '../../vpn/vpn_provider.dart';
import '../models/multihop_pair.dart';
import '../services/multihop_service.dart';

class MultiHopScreen extends StatefulWidget {
  const MultiHopScreen({super.key});

  @override
  State<MultiHopScreen> createState() => _MultiHopScreenState();
}

class _MultiHopScreenState extends State<MultiHopScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final MultiHopService _service;
  List<MultiHopPair> _pairs = [];
  List<Map<String, dynamic>> _onionServers = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _service = MultiHopService(context.read<ApiService>());
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await Future.wait([
        _service.fetchMultiHopPairs(),
        _service.fetchOnionServers(),
      ]);

      if (mounted) {
        setState(() {
          _pairs = results[0] as List<MultiHopPair>;
          _onionServers = results[1] as List<Map<String, dynamic>>;
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

  Future<void> _connectMultiHop(MultiHopPair pair) async {
    final vpn = context.read<VpnProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final storage = context.read<StorageService>();
    final deviceId = storage.getOrCreateDeviceUuid();

    try {
      await _service.connectMultiHop(
        entryServerId: pair.entryServer.id,
        exitServerId: pair.exitServer.id,
        deviceId: deviceId,
      );

      // Select entry server on provider and trigger tunnel connect
      final entry = vpn.servers.cast<dynamic>().firstWhere(
            (s) => s.id == pair.entryServer.id,
            orElse: () => null,
          );
      if (entry != null) {
        vpn.selectServer(entry);
        vpn.connect();
      }

      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Double VPN Active: ${pair.entryServer.city} ➔ ${pair.exitServer.city}'),
            backgroundColor: AppTheme.connectedGreen,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Failed to connect Double VPN: $e'),
            backgroundColor: AppTheme.disconnectedRed,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Multi-Hop & Onion over VPN'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primary,
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.textSecondary,
          tabs: const [
            Tab(icon: Icon(Icons.hub_rounded), text: 'Double VPN (Multi-Hop)'),
            Tab(icon: Icon(Icons.security_rounded), text: 'Onion over VPN (Tor)'),
          ],
        ),
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
                      const Text('Failed to load routes', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Text(_errorMessage!, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                      const SizedBox(height: 16),
                      ElevatedButton(onPressed: _loadData, child: const Text('RETRY')),
                    ],
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildMultiHopList(),
                    _buildOnionList(),
                  ],
                ),
    );
  }

  Widget _buildMultiHopList() {
    if (_pairs.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Text(
            'Need at least 2 online servers in different countries to establish Double VPN routes.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textSecondary),
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _pairs.length,
      itemBuilder: (ctx, i) => _buildMultiHopCard(_pairs[i]),
    );
  }

  Widget _buildMultiHopCard(MultiHopPair pair) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: pair.isPopular ? AppTheme.primary.withOpacity(0.5) : AppTheme.surfaceLight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'DOUBLE ENCRYPTION (2 HOPS)',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.primary),
                ),
              ),
              Row(
                children: [
                  const Icon(Icons.speed, size: 14, color: AppTheme.textSecondary),
                  const SizedBox(width: 4),
                  Text('~${pair.estimatedPingMs} ms', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Route Chain Visualization
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.background,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('ENTRY NODE', style: TextStyle(fontSize: 10, color: AppTheme.textSecondary, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(pair.entryServer.flagEmoji, style: const TextStyle(fontSize: 18)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              pair.entryServer.city,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.lock_rounded, size: 16, color: AppTheme.primary),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('EXIT NODE', style: TextStyle(fontSize: 10, color: AppTheme.textSecondary, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Text(
                              pair.exitServer.city,
                              textAlign: TextAlign.end,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(pair.exitServer.flagEmoji, style: const TextStyle(fontSize: 18)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.bolt_rounded, size: 18),
            label: Text('CONNECT ${pair.name.toUpperCase()}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            onPressed: () => _connectMultiHop(pair),
          ),
        ],
      ),
    );
  }

  Widget _buildOnionList() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.accent.withOpacity(0.12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.accent.withOpacity(0.4)),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.shield_moon_rounded, color: AppTheme.accent, size: 24),
                  SizedBox(width: 10),
                  Text('Onion over VPN Technology', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                ],
              ),
              SizedBox(height: 8),
              Text(
                'Routes your encrypted WireGuard tunnel through the decentralized Tor network. You can open .onion websites directly in Chrome, Firefox, or Safari without installing Tor Browser.',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.4),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Pluggable Transport Selector Card
        Consumer<StorageService>(
          builder: (context, storage, _) {
            final currentTransport = storage.torPluggableTransport;
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.surfaceLight),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'PLUGGABLE TRANSPORT BRIDGE',
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
                          color: AppTheme.accent.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          currentTransport.toUpperCase(),
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.accent),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Camouflages Tor traffic against national firewalls and Deep Packet Inspection (DPI) systems.',
                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildTransportChip(context, storage, 'snowflake', 'Snowflake', 'WebRTC Proxies (Censorship Resistant)'),
                      const SizedBox(width: 8),
                      _buildTransportChip(context, storage, 'obfs4', 'Obfs4', 'Scrambled TCP'),
                      const SizedBox(width: 8),
                      _buildTransportChip(context, storage, 'direct', 'Direct', 'Standard Tor'),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 16),
        ..._onionServers.map((s) => _buildOnionCard(s)),
      ],
    );
  }

  Widget _buildOnionCard(Map<String, dynamic> server) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.surfaceLight),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.accent.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.vpn_lock_rounded, color: AppTheme.accent, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(server['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.accent.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('TOR GATEWAY', style: TextStyle(fontSize: 9, color: AppTheme.accent, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${server['city']}, ${server['countryName']} • Transparent Tor Routing',
                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              final vpn = context.read<VpnProvider>();
              final target = vpn.servers.cast<dynamic>().firstWhere(
                    (s) => s.id == server['id'],
                    orElse: () => null,
                  );
              if (target != null) {
                vpn.selectServer(target);
                vpn.connect();
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Onion over VPN Active on ${server['name']}'),
                    backgroundColor: AppTheme.accent,
                  ),
                );
              }
            },
            child: const Text('CONNECT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
          ),
        ],
      ),
    );
  }

  Widget _buildTransportChip(BuildContext context, StorageService storage, String key, String title, String subtitle) {
    final isSelected = storage.torPluggableTransport == key;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          storage.setTorPluggableTransport(key);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.accent.withOpacity(0.2) : AppTheme.background,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? AppTheme.accent : AppTheme.surfaceLight,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? AppTheme.accent : Colors.white,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                key == 'snowflake' ? 'WebRTC' : key == 'obfs4' ? 'Scrambled' : 'Standard',
                style: const TextStyle(fontSize: 9, color: AppTheme.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
