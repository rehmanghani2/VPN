import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/theme/app_theme.dart';

class WifiTrustScreen extends StatefulWidget {
  const WifiTrustScreen({super.key});

  @override
  State<WifiTrustScreen> createState() => _WifiTrustScreenState();
}

class _WifiTrustScreenState extends State<WifiTrustScreen> {
  final TextEditingController _ssidController = TextEditingController();
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 4),
    receiveTimeout: const Duration(seconds: 4),
    followRedirects: false,
    validateStatus: (status) => true,
  ));
  bool _isProbingCaptivePortal = false;
  String? _captivePortalStatus;
  int? _lastStatusCode;

  @override
  void dispose() {
    _ssidController.dispose();
    super.dispose();
  }

  Future<void> _checkCaptivePortal() async {
    setState(() {
      _isProbingCaptivePortal = true;
      _captivePortalStatus = null;
      _lastStatusCode = null;
    });

    try {
      // Standard Android / Chrome OS captive portal probe endpoint
      final response = await _dio.get('http://connectivitycheck.gstatic.com/generate_204');

      if (!mounted) return;

      final status = response.statusCode ?? 0;
      setState(() {
        _isProbingCaptivePortal = false;
        _lastStatusCode = status;
        if (status == 204) {
          _captivePortalStatus = 'Clear (Direct Internet Access, HTTP 204 No Content)';
        } else if (status == 200 || status == 302 || status == 301) {
          _captivePortalStatus = 'Captive Portal Detected! Network intercepted traffic (HTTP $status). Auto-suspending VPN for authentication.';
        } else {
          _captivePortalStatus = 'HTTP $status - Unknown Network Response';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isProbingCaptivePortal = false;
        _captivePortalStatus = 'Probe timed out or unreachable (Simulated offline/captive redirect: $e)';
      });
    }
  }

  void _addSsid(StorageService storage) {
    final text = _ssidController.text.trim();
    if (text.isEmpty) return;

    final current = List<String>.from(storage.trustedWifiSsids);
    if (!current.contains(text)) {
      current.add(text);
      storage.setTrustedWifiSsids(current);
      setState(() {});
    }
    _ssidController.clear();
    Navigator.of(context).pop();
  }

  void _removeSsid(StorageService storage, String ssid) {
    final current = List<String>.from(storage.trustedWifiSsids);
    current.remove(ssid);
    storage.setTrustedWifiSsids(current);
    setState(() {});
  }

  void _showAddDialog(StorageService storage) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Add Trusted Wi-Fi Network', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter the SSID (Network Name) of your trusted home or office network:',
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _ssidController,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'e.g. MyHome_5GHz',
                hintStyle: const TextStyle(color: AppTheme.textSecondary),
                filled: true,
                fillColor: AppTheme.surfaceLight,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              _ssidController.clear();
              Navigator.of(ctx).pop();
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () => _addSsid(storage),
            child: const Text('Add SSID'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final storage = context.watch<StorageService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Wi-Fi Trust & Captive Portals'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 1. Overview Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.primary.withOpacity(0.2),
                  AppTheme.accent.withOpacity(0.08),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.wifi_protected_setup_rounded, color: AppTheme.primary, size: 24),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Smart Wi-Fi Automation',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Automatically manage VPN tunnel states when connecting to known trusted home/office Wi-Fi networks or public airport/hotel captive portals.',
                  style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.4),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // 2. Automation Toggles
          Container(
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.surfaceLight),
            ),
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Automated Wi-Fi Trust Manager', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                  subtitle: const Text(
                    'Automatically pause the tunnel on trusted SSIDs and enforce protection on untrusted public networks.',
                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                  activeColor: AppTheme.primary,
                  value: storage.isWifiTrustManagerEnabled,
                  onChanged: (val) {
                    storage.setWifiTrustManagerEnabled(val);
                    setState(() {});
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // 3. Captive Portal Detection Section
          const Text(
            'CAPTIVE PORTAL ASSISTANT',
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      _lastStatusCode == 204
                          ? Icons.check_circle_rounded
                          : (_lastStatusCode != null ? Icons.warning_amber_rounded : Icons.sensors_rounded),
                      color: _lastStatusCode == 204
                          ? AppTheme.connectedGreen
                          : (_lastStatusCode != null ? AppTheme.warningYellow : AppTheme.primary),
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Airport / Hotel Splash Page Probe',
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'When active, Antigravity temporarily suspends the VPN tunnel so you can accept terms or login on captive portal web forms, then automatically re-engages encryption.',
                            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (_captivePortalStatus != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: (_lastStatusCode == 204 ? AppTheme.connectedGreen : AppTheme.warningYellow).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: (_lastStatusCode == 204 ? AppTheme.connectedGreen : AppTheme.warningYellow).withOpacity(0.4),
                      ),
                    ),
                    child: Text(
                      _captivePortalStatus!,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: _lastStatusCode == 204 ? AppTheme.connectedGreen : AppTheme.warningYellow,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primary,
                      side: BorderSide(color: AppTheme.primary.withOpacity(0.5)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _isProbingCaptivePortal ? null : _checkCaptivePortal,
                    icon: _isProbingCaptivePortal
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary),
                          )
                        : const Icon(Icons.radar_rounded, size: 18),
                    label: Text(_isProbingCaptivePortal ? 'Probing Network...' : 'Test Captive Portal Probe (HTTP 204)'),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // 4. Trusted SSIDs List
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'TRUSTED WI-FI NETWORKS (SSIDS)',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  color: AppTheme.textSecondary,
                ),
              ),
              TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.primary,
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: () => _showAddDialog(storage),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Network', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.surfaceLight),
            ),
            child: storage.trustedWifiSsids.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(
                      child: Text(
                        'No trusted networks added.\nAll Wi-Fi networks will be treated as untrusted and secured.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                      ),
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: storage.trustedWifiSsids.length,
                    separatorBuilder: (context, index) => const Divider(height: 1, color: AppTheme.surfaceLight),
                    itemBuilder: (context, index) {
                      final ssid = storage.trustedWifiSsids[index];
                      return ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.connectedGreen.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.wifi_lock_rounded, color: AppTheme.connectedGreen, size: 18),
                        ),
                        title: Text(ssid, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        subtitle: const Text('Trusted (Tunnel bypasses auto-protection)', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: AppTheme.disconnectedRed, size: 20),
                          onPressed: () => _removeSsid(storage, ssid),
                          tooltip: 'Remove SSID',
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
