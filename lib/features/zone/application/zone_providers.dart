import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/prediction.dart';
import '../../../data/models/sensor_data_point.dart';
import '../../../data/models/zone_details.dart';
import '../../../data/repositories/farm_repository.dart';
import '../../devices/application/device_providers.dart';
import '../../dashboard/application/dashboard_providers.dart';

final zoneDetailsProvider = FutureProvider.family<ZoneDetails, String>((
  ref,
  zoneId,
) async {
  final zones = await ref.watch(zonesProvider.future);
  final zone = zones.firstWhere((item) => item.id == zoneId);
  final history = await ref.watch(
    zoneHistoryProvider(
      (zoneId: zoneId, range: AnalyticsRange.last24Hours),
    ).future,
  );
  final prediction = await ref.watch(zonePredictionProvider(zoneId).future);
  final repository = ref.watch(farmRepositoryProvider);
  final lastAction = await repository.fetchLastAction(zoneId);

  return ZoneDetails(
    zone: zone,
    latestSensorData: history.isNotEmpty ? history.first : null,
    prediction: prediction,
    lastAction: lastAction,
  );
});

final zonePredictionProvider = FutureProvider.family<Prediction?, String>((
  ref,
  zoneId,
) async {
  final repository = ref.watch(farmRepositoryProvider);
  final remote = await repository.fetchPrediction(zoneId);
  if (remote != null) return remote;
  return ref.watch(localPredictionProvider(zoneId).future);
});

final zoneHistoryProvider = FutureProvider.family
    .autoDispose<
      List<SensorDataPoint>,
      ({String zoneId, AnalyticsRange range})
    >((ref, args) async {
      final repository = ref.watch(farmRepositoryProvider);
      final remote = await repository.fetchSensorHistory(args.zoneId, args.range);
      if (remote.isNotEmpty) return remote;
      return ref.watch(
        localHistoryProvider((zoneId: args.zoneId, hours: args.range.hours))
            .future,
      );
    });
