import '../../../core/services/api_service.dart';
import '../../../core/constants/api_constants.dart';
import '../models/dedicated_ip_model.dart';

class DedicatedIpService {
  final ApiService _api;

  DedicatedIpService(this._api);

  Future<List<DedicatedIpModel>> fetchMyDedicatedIps() async {
    final res = await _api.client.get(ApiConstants.dedicatedIp);
    final list = res.data as List<dynamic>;
    return list.map((item) => DedicatedIpModel.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<List<Map<String, dynamic>>> fetchAvailableRegions() async {
    final res = await _api.client.get(ApiConstants.dedicatedIpAvailableRegions);
    final list = res.data as List<dynamic>;
    return list.cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> reserveDedicatedIp(String serverId) async {
    final res = await _api.client.post(
      ApiConstants.dedicatedIpReserve,
      data: {'serverId': serverId},
    );
    return res.data as Map<String, dynamic>;
  }

  Future<void> releaseDedicatedIp(String id) async {
    await _api.client.delete('${ApiConstants.dedicatedIp}/$id');
  }
}
