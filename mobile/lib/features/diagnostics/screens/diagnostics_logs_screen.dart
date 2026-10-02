import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/vpn_bridge.dart';
import '../../../core/services/storage_service.dart';
import '../../vpn/vpn_provider.dart';

class DiagnosticsLogsScreen extends StatefulWidget {
  const DiagnosticsLogsScreen({super.key});

  @override
  State<DiagnosticsLogsScreen> createState() => _DiagnosticsLogsScreenState();
}

class _DiagnosticsLogsScreenState extends State<DiagnosticsLogsScreen> {
  String _filterLevel = 'ALL';
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Color _getLevelColor(String level) {
    switch (level.toUpperCase()) {
      case 'SUCCESS':
        return AppTheme.connectedGreen;
      case 'ERROR':
        return Colors.redAccent;
      case 'WARN':
        return AppTheme.warningYellow;
      case 'SEC':
        return AppTheme.accent;
      case 'TUNNEL':
        return AppTheme.primary;
      default:
        return AppTheme.textSecondary;
    }
  }

  void _copyAllLogs(List<Map<String, dynamic>> logs) {
    final buffer = StringBuffer();
    buffer.writeln('=== ANTIGRAVITY VPN DIAGNOSTIC REPORT ===');
    buffer.writeln('Generated at: ${DateTime.now().toUtc().toIso8601String()}');
    buffer.writeln('Total Log Entries: ${logs.length}');
    buffer.writeln('----------------------------------------\n');

    for (final l in logs) {
      buffer.writeln('[${l['timestamp']}] [${l['level']}] ${l['message']}');
      if (l['meta'] != null) {
        buffer.writeln('  Meta: ${jsonEncode(l['meta'])}');
      }
    }

    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Diagnostic report copied to clipboard for support debugging!'),
        backgroundColor: AppTheme.primary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bridge = context.watch<VpnBridge>();
    final vpn = context.watch<VpnProvider>();
    final storage = context.watch<StorageService>();

    final allLogs = bridge.diagnosticLogs;
    final filteredLogs = allLogs.where((log) {
      final level = (log['level'] ?? '').toString().toUpperCase();
      final message = (log['message'] ?? '').toString().toLowerCase();
      final query = _searchController.text.toLowerCase();

      final matchesLevel = _filterLevel == 'ALL' || level == _filterLevel;
      final matchesSearch = query.isEmpty || message.contains(query);
      return matchesLevel && matchesSearch;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Connection Diagnostics & Logs'),
        actions: [
          IconButton(
            tooltip: 'Clear Logs',
            icon: const Icon(Icons.delete_outline),
            onPressed: () {
              bridge.clearLogs();
              setState(() {});
            },
          ),
          IconButton(
            tooltip: 'Export & Copy All',
            icon: const Icon(Icons.copy_all_rounded),
            onPressed: () => _copyAllLogs(allLogs),
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. Diagnostic Summary Header Card
          Container(
            margin: const EdgeInsets.all(16),
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
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.security_update_good_rounded, color: AppTheme.primary, size: 20),
                        ),
                        const SizedBox(width: 12),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Cryptographic Key Rotation',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            Text(
                              'PQ-WireGuard Kyber768 • Forward Secrecy',
                              style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                            ),
                          ],
                        ),
                      ],
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        try {
                          await vpn.rotateCryptographicKeys();
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text('WireGuard Keypair & Kyber768 Preshared Key rotated!'),
                              backgroundColor: AppTheme.connectedGreen,
                            ),
                          );
                        } catch (e) {
                          messenger.showSnackBar(
                            SnackBar(content: Text('Rotation failed: $e'), backgroundColor: Colors.redAccent),
                          );
                        }
                      },
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('Rekey Now', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1, color: AppTheme.surfaceLight),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildMetaMetric('Tunnel State', bridge.currentState.name.toUpperCase(), AppTheme.connectedGreen),
                    _buildMetaMetric('Post-Quantum', storage.isPostQuantumEnabled ? 'ENABLED' : 'DISABLED', AppTheme.accent),
                    _buildMetaMetric('Buffer Count', '${allLogs.length} events', AppTheme.textSecondary),
                  ],
                ),
              ],
            ),
          ),

          // 2. Filter Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Search logs (e.g. handshake, tunnel)...',
                      hintStyle: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                      prefixIcon: const Icon(Icons.search, size: 18, color: AppTheme.textSecondary),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      filled: true,
                      fillColor: AppTheme.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppTheme.surfaceLight),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppTheme.surfaceLight),
                      ),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: _filterLevel,
                  dropdownColor: AppTheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  underline: const SizedBox(),
                  items: const [
                    DropdownMenuItem(value: 'ALL', child: Text('ALL')),
                    DropdownMenuItem(value: 'INFO', child: Text('INFO')),
                    DropdownMenuItem(value: 'SUCCESS', child: Text('SUCCESS')),
                    DropdownMenuItem(value: 'SEC', child: Text('SEC')),
                    DropdownMenuItem(value: 'TUNNEL', child: Text('TUNNEL')),
                    DropdownMenuItem(value: 'WARN', child: Text('WARN')),
                    DropdownMenuItem(value: 'ERROR', child: Text('ERROR')),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _filterLevel = val);
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // 3. Log Stream ListView
          Expanded(
            child: filteredLogs.isEmpty
                ? const Center(
                    child: Text(
                      'No matching logs found',
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredLogs.length,
                    itemBuilder: (context, index) {
                      final item = filteredLogs[index];
                      final level = item['level'] ?? 'INFO';
                      final msg = item['message'] ?? '';
                      final time = item['timestamp'] != null
                          ? item['timestamp'].toString().substring(11, 19)
                          : '';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.surfaceLight.withOpacity(0.5)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  time,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontFamily: 'monospace',
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: _getLevelColor(level).withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    level,
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: _getLevelColor(level),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              msg,
                              style: const TextStyle(
                                fontSize: 12,
                                fontFamily: 'monospace',
                                color: Colors.white,
                              ),
                            ),
                            if (item['meta'] != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                jsonEncode(item['meta']),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontFamily: 'monospace',
                                  color: AppTheme.textSecondary.withOpacity(0.8),
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetaMetric(String title, String val, Color color) {
    return Column(
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 2),
        Text(
          val,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }
}
