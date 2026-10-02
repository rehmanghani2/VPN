import '../../../core/services/api_service.dart';
import '../../../core/constants/api_constants.dart';
import '../models/port_forward_rule.dart';

class PortForwardingService {
  final ApiService _api;

  PortForwardingService(this._api);

  Future<List<PortForwardRule>> fetchMyPortForwards() async {
    final res = await _api.client.get(ApiConstants.portForwarding);
    final list = res.data as List<dynamic>;
    return list.map((item) => PortForwardRule.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<Map<String, dynamic>> createPortForward({
    required String deviceId,
    required String serverId,
    required int internalPort,
    int? externalPort,
    String protocol = 'BOTH',
  }) async {
    final payload = <String, dynamic>{
      'deviceId': deviceId,
      'serverId': serverId,
      'internalPort': internalPort,
      'protocol': protocol,
    };
    if (externalPort != null) {
      payload['externalPort'] = externalPort;
    }

    final res = await _api.client.post(
      ApiConstants.portForwarding,
      data: payload,
    );
    return res.data as Map<String, dynamic>;
  }

  Future<void> deletePortForward(String ruleId) async {
    await _api.client.delete('${ApiConstants.portForwarding}/$ruleId');
  }
}
