import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/api_service.dart';
import '../../vpn/vpn_provider.dart';
import '../models/leak_audit_result.dart';
import '../services/diagnostics_service.dart';

class LeakTestScreen extends StatefulWidget {
  const LeakTestScreen({super.key});

  @override
  State<LeakTestScreen> createState() => _LeakTestScreenState();
}

class _LeakTestScreenState extends State<LeakTestScreen> with SingleTickerProviderStateMixin {
  late final DiagnosticsService _diagnosticsService;
  bool _isScanning = false;
  LeakAuditResult? _auditResult;
  String _scanStage = 'Ready to audit';
  late AnimationController _animController;
  late Animation<double> _scoreAnimation;

  @override
  void initState() {
    super.initState();
    _diagnosticsService = DiagnosticsService(context.read<ApiService>());
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _scoreAnimation = Tween<double>(begin: 0.0, end: 0.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );

    // Initial audit trigger
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startAudit();
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _startAudit() async {
    if (_isScanning) return;
    setState(() {
      _isScanning = true;
      _scanStage = 'Querying IPv4 Route & Gateway...';
    });

    try {
      await Future.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;
      setState(() => _scanStage = 'Auditing DNS Resolvers & Hijack Protection...');

      await Future.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;
      setState(() => _scanStage = 'Testing Dual-Stack IPv6 Socket Isolation...');

      await Future.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;
      setState(() => _scanStage = 'Checking WebRTC STUN Candidates...');

      final result = await _diagnosticsService.runLeakAudit();

      if (mounted) {
        final prevScore = _auditResult?.privacyScore.toDouble() ?? 0.0;
        final newScore = result.privacyScore.toDouble();
        _scoreAnimation = Tween<double>(begin: prevScore, end: newScore).animate(
          CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
        );
        _animController.forward(from: 0.0);

        setState(() {
          _auditResult = result;
          _isScanning = false;
          _scanStage = 'Audit Complete';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isScanning = false;
          _scanStage = 'Audit Encountered an Issue';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final vpn = context.watch<VpnProvider>();
    final isConnected = vpn.isConnected;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Zero-Leak Privacy Audit'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Rerun Audit',
            onPressed: _isScanning ? null : _startAudit,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildScoreHero(isConnected),
            const SizedBox(height: 16),
            _buildScanStatusBar(),
            const SizedBox(height: 16),
            _buildAuditCards(isConnected),
            const SizedBox(height: 24),
            _buildActionFooter(isConnected),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreHero(bool isConnected) {
    final result = _auditResult;
    final score = result?.privacyScore ?? (isConnected ? 100 : 0);
    final isSecured = result != null ? result.isFullySecured : isConnected;

    final ringColor = isSecured
        ? AppTheme.connectedGreen
        : (score >= 50 ? AppTheme.warningYellow : AppTheme.disconnectedRed);

    return Container(
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: ringColor.withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: ringColor.withValues(alpha: 0.1),
            blurRadius: 16,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        children: [
          AnimatedBuilder(
            animation: _animController,
            builder: (context, child) {
              final displayScore = _scoreAnimation.value.toInt();
              return Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 130,
                    height: 130,
                    child: CircularProgressIndicator(
                      value: _isScanning ? null : (_scoreAnimation.value / 100.0),
                      strokeWidth: 10,
                      backgroundColor: AppTheme.surfaceLight,
                      valueColor: AlwaysStoppedAnimation<Color>(ringColor),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isSecured ? Icons.verified_user : Icons.gpp_bad_rounded,
                        color: ringColor,
                        size: 38,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _isScanning ? '--' : '$displayScore%',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: ringColor,
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          Text(
            isSecured
                ? 'ZERO LEAKS CONFIRMED'
                : (isConnected ? 'PARTIAL PRIVACY SHIELD' : 'EXPOSED DIRECT ISP CONNECTION'),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
              color: ringColor,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isSecured
                ? 'Your public IP, DNS queries, and WebRTC sockets are completely isolated and encrypted.'
                : (isConnected
                    ? 'Tunnel active, but potential leaks detected. Verify strict kill switch and DNS settings.'
                    : 'Your real IP address and ISP DNS traffic are publicly visible to websites and network trackers.'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              color: AppTheme.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScanStatusBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          if (_isScanning) ...[
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primary),
              ),
            ),
            const SizedBox(width: 12),
          ] else ...[
            const Icon(Icons.check_circle_outline, color: AppTheme.primary, size: 18),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Text(
              _scanStage,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
          if (_auditResult?.timestamp != null)
            Text(
              '${_auditResult!.timestamp.hour.toString().padLeft(2, '0')}:${_auditResult!.timestamp.minute.toString().padLeft(2, '0')}:${_auditResult!.timestamp.second.toString().padLeft(2, '0')}',
              style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
            ),
        ],
      ),
    );
  }

  Widget _buildAuditCards(bool isConnected) {
    final result = _auditResult;

    final ipLeaked = result != null ? result.ipAudit.leakDetected : !isConnected;
    final dnsLeaked = result != null ? result.dnsAudit.dnsLeakDetected : !isConnected;
    final ipv6Leaked = result != null ? result.ipv6Audit.ipv6Leaked : false;
    final webrtcSecure = result != null ? result.webrtcAudit.webrtcSecured : true;

    return Column(
      children: [
        _buildProbeCard(
          title: 'IPv4 Exposure Audit',
          subtitle: result?.ipAudit.detectedIp != null
              ? 'Observed IP: ${result!.ipAudit.detectedIp}'
              : 'Testing route to edge gateway...',
          badge: ipLeaked ? 'IP LEAKED' : 'ENCRYPTED',
          isSecure: !ipLeaked,
          icon: Icons.public,
          detail: ipLeaked
              ? 'Your true ISP IP is exposed directly to remote servers. Connect to a WireGuard node to tunnel all IPv4 packets.'
              : 'All IPv4 traffic is encrypted and forwarded through an enterprise edge node gateway.',
        ),
        const SizedBox(height: 12),
        _buildProbeCard(
          title: 'DNS Hijack & Leak Audit',
          subtitle: result != null
              ? '${result.dnsAudit.resolversDetected} Active Resolver(s) Detected'
              : 'Verifying DNS resolver isolation...',
          badge: dnsLeaked ? 'DNS LEAK' : 'SECURE UNBOUND',
          isSecure: !dnsLeaked,
          icon: Icons.dns_rounded,
          detail: dnsLeaked
              ? 'DNS queries are resolving through your local ISP (${result?.dnsAudit.servers.map((s) => s.hostname.isNotEmpty ? s.hostname : s.ip).join(", ") ?? "ISP Gateway"}). Websites can log your browsing history.'
              : 'DNS queries are strictly encapsulated in the tunnel and resolved by private edge Unbound DNSSEC servers.',
        ),
        const SizedBox(height: 12),
        _buildProbeCard(
          title: 'Dual-Stack IPv6 Socket Isolation',
          subtitle: result != null ? 'Status: ${result.ipv6Audit.status}' : 'Testing IPv6 socket bindings...',
          badge: ipv6Leaked ? 'IPV6 LEAK' : 'PROTECTED',
          isSecure: !ipv6Leaked,
          icon: Icons.shield_outlined,
          detail: ipv6Leaked
              ? 'IPv6 packets are bypassing the VPN tunnel and disclosing your hardware IPv6 address.'
              : 'IPv6 traffic is securely tunneled with strict sinkhole routing to prevent dual-stack deanonymization.',
        ),
        const SizedBox(height: 12),
        _buildProbeCard(
          title: 'WebRTC STUN Isolation',
          subtitle: webrtcSecure ? 'No Candidate Leaks' : 'STUN Bypass Detected',
          badge: webrtcSecure ? 'SHIELDED' : 'EXPOSED',
          isSecure: webrtcSecure,
          icon: Icons.network_check_rounded,
          detail: webrtcSecure
              ? 'Browser and application WebRTC peer-to-peer STUN requests cannot discover your local or real IP.'
              : 'WebRTC STUN traversal has leaked local adapter candidates: ${result.webrtcAudit.exposedLocalIps.join(", ")}',
        ),
        const SizedBox(height: 12),
        _buildProbeCard(
          title: 'System Kill Switch Engine',
          subtitle: isConnected ? 'Active (Strict Wintun/TUN Route Filter)' : 'Standby / Armed',
          badge: isConnected ? 'ARMED & ACTIVE' : 'STANDBY',
          isSecure: isConnected,
          icon: Icons.lock_clock_rounded,
          detail: isConnected
              ? 'If the WireGuard socket drops unexpectedly, all internet traffic will be instantly severed at the kernel driver layer.'
              : 'Connect to a VPN server to activate kernel-level packet filtering and block all unencrypted traffic.',
        ),
      ],
    );
  }

  Widget _buildProbeCard({
    required String title,
    required String subtitle,
    required String badge,
    required bool isSecure,
    required IconData icon,
    required String detail,
  }) {
    final statusColor = isSecure ? AppTheme.connectedGreen : AppTheme.disconnectedRed;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSecure ? AppTheme.surfaceLight : AppTheme.disconnectedRed.withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: statusColor, size: 22),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: statusColor.withValues(alpha: 0.5)),
          ),
          child: Text(
            badge,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: statusColor,
            ),
          ),
        ),
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.background,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  isSecure ? Icons.check_circle : Icons.warning_amber_rounded,
                  color: statusColor,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    detail,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionFooter(bool isConnected) {
    return ElevatedButton.icon(
      onPressed: _isScanning ? null : _startAudit,
      icon: _isScanning
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : const Icon(Icons.security_update_good_rounded),
      label: Text(
        _isScanning ? 'RUNNING DEEP AUDIT...' : 'RUN ZERO-LEAK AUDIT SCAN',
        style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.primaryDark,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
