import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/farm_alert.dart';
import '../../devices/application/device_providers.dart';
import '../../dashboard/application/dashboard_providers.dart';

final alertsProvider = StreamProvider<List<FarmAlert>>((ref) {
  return Stream<void>.periodic(
    const Duration(seconds: 12),
  ).asyncMap((_) async {
    final repository = ref.read(farmRepositoryProvider);
    final remoteAlerts = await repository.fetchAlerts();
    if (remoteAlerts.isNotEmpty) return remoteAlerts;
    return ref.read(localAlertsProvider.future);
  }).startWithAsync(() async {
    final repository = ref.read(farmRepositoryProvider);
    final remoteAlerts = await repository.fetchAlerts();
    if (remoteAlerts.isNotEmpty) return remoteAlerts;
    return ref.read(localAlertsProvider.future);
  });
});

final unreadAlertsCountProvider = Provider<int>((ref) {
  final alerts = ref.watch(alertsProvider).asData?.value ?? const <FarmAlert>[];
  return alerts.where((item) => !item.isRead).length;
});

extension<T> on Stream<T> {
  Stream<T> startWithAsync(Future<T> Function() loader) async* {
    yield await loader();
    yield* this;
  }
}
