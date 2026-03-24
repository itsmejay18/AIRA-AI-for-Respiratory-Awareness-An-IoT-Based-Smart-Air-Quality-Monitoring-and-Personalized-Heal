import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/app_runtime_status.dart';
import '../../../core/utils/app_config.dart';
import '../../../data/models/zone.dart';
import '../../../data/repositories/farm_repository.dart';
import '../../../data/services/ai_api_service.dart';
import '../../auth/application/auth_controller.dart';
import '../../devices/application/device_providers.dart';

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
  return Stream<void>.periodic(
    const Duration(seconds: 10),
  ).asyncMap((_) async {
    final repository = ref.read(farmRepositoryProvider);
    final remoteZones = await repository.fetchZones();
    if (remoteZones.isNotEmpty) return remoteZones;
    return ref.read(localZonesProvider.future);
  }).startWithAsync(() async {
    final repository = ref.read(farmRepositoryProvider);
    final remoteZones = await repository.fetchZones();
    if (remoteZones.isNotEmpty) return remoteZones;
    return ref.read(localZonesProvider.future);
  });
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

  if (!liveDataAvailable) {
    final localZones = await ref.watch(localZonesProvider.future);
    liveDataAvailable = localZones.isNotEmpty;
  }

  final aiServerAvailable = await aiApi.ping();

  return AppRuntimeStatus(
    supabaseConfigured: config.isSupabaseConfigured,
    liveDataAvailable: liveDataAvailable,
    aiServerAvailable: aiServerAvailable,
  );
});

extension<T> on Stream<T> {
  Stream<T> startWithAsync(Future<T> Function() loader) async* {
    yield await loader();
    yield* this;
  }
}
