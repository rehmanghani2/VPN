import 'package:dio/dio.dart';
import '../../../core/services/api_service.dart';
import '../../../core/constants/api_constants.dart';
import '../models/leak_audit_result.dart';

class DiagnosticsService {
  final ApiService _api;

  DiagnosticsService(this._api);

  Future<Map<String, dynamic>> fetchIpInfo() async {
    try {
      final res = await _api.client.get(
        ApiConstants.diagnosticsIp,
        options: Options(
          headers: {'Cache-Control': 'no-cache'},
          sendTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
        ),
      );
      return res.data as Map<String, dynamic>;
    } catch (e) {
      return {
        'detectedIp': 'Unavailable',
        'isVpnConnection': false,
        'status': 'OFFLINE_OR_ERROR',
        'error': e.toString(),
      };
    }
  }

  Future<LeakAuditResult> runLeakAudit() async {
    try {
      final res = await _api.client.get(
        ApiConstants.diagnosticsLeakAudit,
        options: Options(
          headers: {'Cache-Control': 'no-cache'},
          sendTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 8),
        ),
      );
      return LeakAuditResult.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      // Return safe fallback indicating scan failure / unencrypted
      return LeakAuditResult(
        ipAudit: IpAudit(
          detectedIp: 'Unknown',
          isEncrypted: false,
          leakDetected: true,
          protectionGrade: 'F',
        ),
        dnsAudit: DnsAudit(
          resolversDetected: 0,
          servers: [],
          dnsLeakDetected: true,
          dnssecActive: false,
        ),
        ipv6Audit: Ipv6Audit(
          ipv6Leaked: false,
          status: 'UNCHECKED',
        ),
        webrtcAudit: WebrtcAudit(
          stunCandidateLeak: false,
          exposedLocalIps: [],
          webrtcSecured: false,
        ),
        overallVerdict: 'AUDIT_REQUEST_FAILED',
        timestamp: DateTime.now(),
      );
    }
  }
}
