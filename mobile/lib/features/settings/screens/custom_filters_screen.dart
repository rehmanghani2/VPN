import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/storage_service.dart';

class CustomFiltersScreen extends StatefulWidget {
  const CustomFiltersScreen({super.key});

  @override
  State<CustomFiltersScreen> createState() => _CustomFiltersScreenState();
}

class _CustomFiltersScreenState extends State<CustomFiltersScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late List<String> _blocklists;
  late List<String> _domains;

  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _domainController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    final storage = context.read<StorageService>();
    _blocklists = List.from(storage.customBlocklists);
    _domains = List.from(storage.customBlockedDomains);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _urlController.dispose();
    _domainController.dispose();
    super.dispose();
  }

  void _addBlocklistUrl() {
    final text = _urlController.text.trim();
    if (text.isNotEmpty && !_blocklists.contains(text)) {
      setState(() {
        _blocklists.add(text);
      });
      _urlController.clear();
      context.read<StorageService>().setCustomBlocklists(_blocklists);
    }
  }

  void _removeBlocklistUrl(int index) {
    setState(() {
      _blocklists.removeAt(index);
    });
    context.read<StorageService>().setCustomBlocklists(_blocklists);
  }

  void _addDomain() {
    final text = _domainController.text.trim().toLowerCase();
    if (text.isNotEmpty && !_domains.contains(text)) {
      setState(() {
        _domains.add(text);
      });
      _domainController.clear();
      context.read<StorageService>().setCustomBlockedDomains(_domains);
    }
  }

  void _removeDomain(int index) {
    setState(() {
      _domains.removeAt(index);
    });
    context.read<StorageService>().setCustomBlockedDomains(_domains);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Custom DNS Filter Lists'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primary,
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.textSecondary,
          tabs: const [
            Tab(icon: Icon(Icons.link_rounded), text: 'Blocklist Feeds'),
            Tab(icon: Icon(Icons.block_flipped), text: 'Custom Blacklist'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // TAB 1: Remote Hosts / Pi-hole URL feeds
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'SUBSCRIBE TO CUSTOM BLOCKLIST FEEDS',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Add raw hosts or Pi-hole format blocklist URLs. DNS queries matching these lists are sinkholed to 0.0.0.0 directly on the WireGuard Unbound resolver.',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _urlController,
                        style: const TextStyle(fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'https://example.com/hosts.txt',
                          hintStyle: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
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
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: _addBlocklistUrl,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: _blocklists.isEmpty
                      ? const Center(
                          child: Text(
                            'No custom blocklist URLs configured',
                            style: TextStyle(color: AppTheme.textSecondary),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _blocklists.length,
                          itemBuilder: (context, index) {
                            final url = _blocklists[index];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: AppTheme.surface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppTheme.surfaceLight),
                              ),
                              child: ListTile(
                                leading: const Icon(Icons.security, color: AppTheme.primary, size: 20),
                                title: Text(
                                  url,
                                  style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                  onPressed: () => _removeBlocklistUrl(index),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),

          // TAB 2: Custom Blocked Domains
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'MANUALLY BLOCKED DOMAINS',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Instantly sinkhole specific tracking, advertising, or unwanted hostnames across all tunnel connections.',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _domainController,
                        style: const TextStyle(fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'e.g. tracking.example.com',
                          hintStyle: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
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
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: _addDomain,
                      icon: const Icon(Icons.block, size: 18),
                      label: const Text('Block'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: _domains.isEmpty
                      ? const Center(
                          child: Text(
                            'No custom blocked domains configured',
                            style: TextStyle(color: AppTheme.textSecondary),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _domains.length,
                          itemBuilder: (context, index) {
                            final domain = _domains[index];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: AppTheme.surface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppTheme.surfaceLight),
                              ),
                              child: ListTile(
                                leading: const Icon(Icons.cancel_outlined, color: Colors.redAccent, size: 20),
                                title: Text(
                                  domain,
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                ),
                                subtitle: const Text('Sinkholed: 0.0.0.0 (Local Override)', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete_outline, color: AppTheme.textSecondary, size: 20),
                                  onPressed: () => _removeDomain(index),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
