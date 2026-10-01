import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../vpn_provider.dart';

class ServersScreen extends StatefulWidget {
  const ServersScreen({super.key});

  @override
  State<ServersScreen> createState() => _ServersScreenState();
}

class _ServersScreenState extends State<ServersScreen> {
  String _searchQuery = '';
  String _filterTab = 'ALL'; // 'ALL', 'STANDARD', 'STEALTH'

  @override
  Widget build(BuildContext context) {
    final vpn = context.watch<VpnProvider>();
    final servers = vpn.servers.where((s) {
      final q = _searchQuery.toLowerCase();
      final matchesSearch = s.countryName.toLowerCase().contains(q) ||
          s.city.toLowerCase().contains(q) ||
          s.countryCode.toLowerCase().contains(q);

      if (!matchesSearch) return false;
      if (_filterTab == 'STEALTH') return s.isObfuscated;
      if (_filterTab == 'STANDARD') return !s.isObfuscated;
      return true;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('VPN Locations'),
      ),
      body: Column(
        children: [
          // Search Field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search country or city...',
                prefixIcon: Icon(Icons.search_rounded, color: AppTheme.textSecondary),
              ),
              onChanged: (val) {
                setState(() {
                  _searchQuery = val;
                });
              },
            ),
          ),

          // Filter Category Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
            child: Row(
              children: [
                _buildFilterChip('ALL', 'All Servers (${vpn.servers.length})'),
                const SizedBox(width: 8),
                _buildFilterChip('STANDARD', 'Standard WireGuard'),
                const SizedBox(width: 8),
                _buildFilterChip('STEALTH', '🥷 Stealth / Anti-DPI (Port 443)'),
              ],
            ),
          ),

          // Smart Connect Item
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
            child: InkWell(
              onTap: () {
                vpn.selectServer(null);
                Navigator.pop(context);
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: vpn.selectedServer == null
                      ? AppTheme.primary.withOpacity(0.15)
                      : AppTheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: vpn.selectedServer == null
                        ? AppTheme.primary
                        : AppTheme.surfaceLight,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Icon(Icons.bolt_rounded, color: AppTheme.primary, size: 24),
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Smart Connect',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          Text(
                            'Fastest available server based on ping',
                            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    if (vpn.selectedServer == null)
                      const Icon(Icons.check_circle_rounded, color: AppTheme.primary, size: 20),
                  ],
                ),
              ),
            ),
          ),

          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'ALL LOCATIONS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
          ),

          // Server List
          Expanded(
            child: ListView.builder(
              itemCount: servers.length,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemBuilder: (context, index) {
                final srv = servers[index];
                final isSelected = vpn.selectedServer?.id == srv.id;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: InkWell(
                    onTap: () {
                      vpn.selectServer(srv);
                      Navigator.pop(context);
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppTheme.primary.withOpacity(0.12)
                            : AppTheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? AppTheme.primary : AppTheme.surfaceLight,
                        ),
                      ),
                      child: Row(
                        children: [
                          Text(srv.flagEmoji, style: const TextStyle(fontSize: 24)),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      srv.countryName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: AppTheme.textPrimary,
                                      ),
                                    ),
                                    if (srv.isObfuscated) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                        decoration: BoxDecoration(
                                          color: AppTheme.warningYellow.withOpacity(0.18),
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(color: AppTheme.warningYellow.withOpacity(0.4)),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.shield, size: 10, color: AppTheme.warningYellow),
                                            SizedBox(width: 3),
                                            Text(
                                              'STEALTH 443',
                                              style: TextStyle(
                                                fontSize: 8.5,
                                                fontWeight: FontWeight.bold,
                                                color: AppTheme.warningYellow,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                Text(
                                  srv.city,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Capacity / Load Badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceLight.withOpacity(0.4),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${srv.loadPercentage}% load',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: srv.loadPercentage > 75
                                    ? AppTheme.disconnectedRed
                                    : AppTheme.connectedGreen,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (isSelected)
                            const Icon(Icons.check_circle_rounded,
                                color: AppTheme.primary, size: 20),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String filterKey, String label) {
    final isSelected = _filterTab == filterKey;
    return InkWell(
      onTap: () => setState(() => _filterTab = filterKey),
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary.withOpacity(0.2) : AppTheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppTheme.primary : AppTheme.surfaceLight,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }
}
