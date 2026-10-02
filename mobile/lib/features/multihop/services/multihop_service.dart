import '../../../core/services/api_service.dart';
import '../../../core/constants/api_constants.dart';
import '../models/multihop_pair.dart';

class MultiHopService {
  final ApiService _api;

  MultiHopService(this._api);

  Future<List<MultiHopPair>> fetchMultiHopPairs() async {
    final res = await _api.client.get(ApiConstants.multihopPairs);
    final list = res.data as List<dynamic>;
    return list.map((item) => MultiHopPair.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<Map<String, dynamic>> connectMultiHop({
    required String entryServerId,
    required String exitServerId,
    required String deviceId,
  }) async {
    final res = await _api.client.post(
      ApiConstants.multihopConnect,
      data: {
        'entryServerId': entryServerId,
        'exitServerId': exitServerId,
        'deviceId': deviceId,
      },
    );
    return res.data as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> fetchOnionServers() async {
    final res = await _api.client.get(ApiConstants.onionServers);
    final list = res.data as List<dynamic>;
    return list.cast<Map<String, dynamic>>();
  }
}
