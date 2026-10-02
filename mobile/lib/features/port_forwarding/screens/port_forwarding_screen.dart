import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/storage_service.dart';
import '../../vpn/vpn_provider.dart';
import '../models/port_forward_rule.dart';
import '../services/port_forwarding_service.dart';

class PortForwardingScreen extends StatefulWidget {
  const PortForwardingScreen({super.key});

  @override
  State<PortForwardingScreen> createState() => _PortForwardingScreenState();
}

class _PortForwardingScreenState extends State<PortForwardingScreen> {
  late final PortForwardingService _service;
  List<PortForwardRule> _rules = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _service = PortForwardingService(context.read<ApiService>());
    _loadRules();
  }

  Future<void> _loadRules() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final list = await _service.fetchMyPortForwards();
      if (mounted) {
        setState(() {
          _rules = list;
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

  Future<void> _deleteRule(String ruleId) async {
    try {
      await _service.deletePortForward(ruleId);
      _loadRules();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Port forward rule removed'),
            backgroundColor: AppTheme.surfaceLight,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete rule: $e'), backgroundColor: AppTheme.disconnectedRed),
        );
      }
    }
  }

  void _showAddPortModal() {
    final vpn = context.read<VpnProvider>();
    final currentServer = vpn.selectedServer ?? (vpn.servers.isNotEmpty ? vpn.servers.first : null);

    if (currentServer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a VPN server first')),
      );
      return;
    }

    final internalPortController = TextEditingController(text: '8080');
    final externalPortController = TextEditingController();
    String selectedProtocol = 'BOTH';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'New Port Forwarding Rule',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Forward incoming public traffic on ${currentServer.name} (${currentServer.city}) into your connected tunnel port.',
                    style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: internalPortController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Internal Target Port (on your device)',
                      hintText: 'e.g. 8080, 25565, 32400',
                      filled: true,
                      fillColor: AppTheme.background,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: externalPortController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Requested External Port (Optional)',
                      hintText: 'Leave empty for random safe port (40000-55000)',
                      filled: true,
                      fillColor: AppTheme.background,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Text('Protocol:', style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(width: 12),
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(value: 'BOTH', label: Text('BOTH')),
                          ButtonSegment(value: 'TCP', label: Text('TCP')),
                          ButtonSegment(value: 'UDP', label: Text('UDP')),
                        ],
                        selected: {selectedProtocol},
                        onSelectionChanged: (val) {
                          setModalState(() => selectedProtocol = val.first);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () async {
                      final internalPort = int.tryParse(internalPortController.text);
                      if (internalPort == null || internalPort < 1 || internalPort > 65535) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Invalid internal port number (1-65535)')),
                        );
                        return;
                      }

                      final extText = externalPortController.text.trim();
                      final externalPort = extText.isNotEmpty ? int.tryParse(extText) : null;

                      final messenger = ScaffoldMessenger.of(context);
                      final storage = context.read<StorageService>();
                      final deviceId = storage.getOrCreateDeviceUuid();

                      Navigator.pop(ctx);
                      try {
                        await _service.createPortForward(
                          deviceId: deviceId,
                          serverId: currentServer.id,
                          internalPort: internalPort,
                          externalPort: externalPort,
                          protocol: selectedProtocol,
                        );
                        _loadRules();
                        if (mounted) {
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text('Port forward active!'),
                              backgroundColor: AppTheme.connectedGreen,
                            ),
                          );
                        }
                      } catch (err) {
                        if (mounted) {
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text('Failed to create rule: $err'),
                              backgroundColor: AppTheme.disconnectedRed,
                            ),
                          );
                        }
                      }
                    },
                    child: const Text('CREATE PORT FORWARD', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Port Forwarding (NAT)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loadRules,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('New Port Forward', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        onPressed: _showAddPortModal,
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
                      const Text('Error loading rules', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Text(_errorMessage!, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                      const SizedBox(height: 16),
                      ElevatedButton(onPressed: _loadRules, child: const Text('RETRY')),
                    ],
                  ),
                )
              : _rules.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                      itemCount: _rules.length,
                      itemBuilder: (ctx, i) => _buildRuleCard(_rules[i]),
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
              child: const Icon(Icons.alt_route_rounded, color: AppTheme.primary, size: 54),
            ),
            const SizedBox(height: 20),
            const Text(
              'No Forwarded Ports Active',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Port forwarding routes incoming internet connections directly through the VPN tunnel to services running on your device (P2P, gaming servers, Plex, remote access).',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('ADD PORT FORWARD'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              onPressed: _showAddPortModal,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRuleCard(PortForwardRule rule) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.connectedGreen.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppTheme.connectedGreen.withOpacity(0.4)),
                    ),
                    child: Text(
                      rule.protocol,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.connectedGreen,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    rule.serverName,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: AppTheme.disconnectedRed, size: 20),
                tooltip: 'Release Port',
                onPressed: () => _deleteRule(rule.id),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.background,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Public Endpoint', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                    const SizedBox(height: 2),
                    Text(
                      rule.publicEndpoint,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.primary),
                    ),
                  ],
                ),
                const Icon(Icons.arrow_forward_rounded, color: AppTheme.textSecondary, size: 18),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('Internal Port', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                    const SizedBox(height: 2),
                    Text(
                      ':${rule.internalPort}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Device: ${rule.deviceName}',
                style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
              InkWell(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: rule.publicEndpoint));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Copied ${rule.publicEndpoint} to clipboard'),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
                child: const Row(
                  children: [
                    Icon(Icons.copy, size: 14, color: AppTheme.primary),
                    SizedBox(width: 4),
                    Text('Copy Endpoint', style: TextStyle(fontSize: 12, color: AppTheme.primary, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
