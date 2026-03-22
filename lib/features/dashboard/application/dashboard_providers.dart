import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/app_runtime_status.dart';
import '../../../data/models/iot_device.dart';
import '../../../core/utils/app_config.dart';
import '../../../data/models/zone.dart';
import '../../../data/repositories/farm_repository.dart';
import '../../../data/services/ai_api_service.dart';
import '../../auth/application/auth_controller.dart';

final aiApiServiceProvider = Provider<AiApiService>((ref) {
  final config = ref.watch(appConfigProvider);
  return AiApiService(config);
});

final farmRepositoryProvider = Provider<FarmRepository>((ref) {
  final api = ref.watch(aiApiServiceProvider);
  final client = ref.watch(supabaseClientProvider);
  return FarmRepository(aiApiService: api, supabaseClient: client);
});

final zonesProvider = StreamProvider<List<Zone>>((ref) {
  final repository = ref.watch(farmRepositoryProvider);
  return repository.watchZones();
});

final iotDevicesProvider = StreamProvider<List<IoTDevice>>((ref) {
  final repository = ref.watch(farmRepositoryProvider);
  return repository.watchIoTDevices();
});

final appRuntimeStatusProvider = FutureProvider<AppRuntimeStatus>((ref) async {
  final config = ref.watch(appConfigProvider);
  final client = ref.watch(supabaseClientProvider);
  final aiApi = ref.watch(aiApiServiceProvider);

  var liveDataAvailable = false;
  if (client != null) {
    try {
      final rows = await client.from('zones').select('id').limit(1);
      liveDataAvailable = (rows as List).isNotEmpty;
    } catch (_) {
      liveDataAvailable = false;
    }
  }

  final aiServerAvailable = await aiApi.ping();

  return AppRuntimeStatus(
    supabaseConfigured: config.isSupabaseConfigured,
    liveDataAvailable: liveDataAvailable,
    aiServerAvailable: aiServerAvailable,
  );
});
