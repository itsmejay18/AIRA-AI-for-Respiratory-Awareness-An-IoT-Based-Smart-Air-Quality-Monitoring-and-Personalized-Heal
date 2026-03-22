import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/iot_device.dart';
import '../../dashboard/application/dashboard_providers.dart';

final zoneIoTDeviceProvider = FutureProvider.family<IoTDevice?, String>((
  ref,
  zoneId,
) async {
  final repository = ref.watch(farmRepositoryProvider);
  return repository.fetchDeviceForZone(zoneId);
});
