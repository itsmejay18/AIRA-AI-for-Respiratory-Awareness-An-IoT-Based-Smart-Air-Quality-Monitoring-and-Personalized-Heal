import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/local_farm_intelligence.dart';
import '../../../data/models/farm_alert.dart';
import '../../../data/models/iot_device.dart';
import '../../../data/models/prediction.dart';
import '../../../data/models/sensor_data_point.dart';
import '../../../data/models/zone.dart';
import '../../../data/repositories/local_device_repository.dart';
import '../../../data/repositories/local_telemetry_repository.dart';
import '../../../data/services/esp32_device_service.dart';
import '../../auth/application/auth_controller.dart';

final localDeviceRepositoryProvider = FutureProvider<LocalDeviceRepository>((
  ref,
) async {
  final prefs = await ref.watch(sharedPreferencesProvider.future);
  return LocalDeviceRepository(preferences: prefs);
});

final iotDevicesProvider = FutureProvider<List<IoTDevice>>((ref) async {
  final repository = await ref.watch(localDeviceRepositoryProvider.future);
  return repository.loadDevices();
});

final localTelemetryRepositoryProvider = FutureProvider<LocalTelemetryRepository>((
  ref,
) async {
  final prefs = await ref.watch(sharedPreferencesProvider.future);
  return LocalTelemetryRepository(preferences: prefs);
});

final esp32DeviceServiceProvider = Provider<Esp32DeviceService>((ref) {
  return Esp32DeviceService();
});

final localZonesProvider = FutureProvider<List<Zone>>((ref) async {
  final devices = await ref.watch(iotDevicesProvider.future);
  final telemetryRepository = await ref.watch(
    localTelemetryRepositoryProvider.future,
  );
  final latestByZone = await telemetryRepository.loadLatestByZone();

  return [
    for (final device in devices)
      if (latestByZone[device.zoneId] != null)
        zoneFromDevice(device, latestByZone[device.zoneId]!),
  ];
});

final localAlertsProvider = FutureProvider<List<FarmAlert>>((ref) async {
  final devices = await ref.watch(iotDevicesProvider.future);
  final telemetryRepository = await ref.watch(
    localTelemetryRepositoryProvider.future,
  );
  final latestByZone = await telemetryRepository.loadLatestByZone();
  return alertsFromTelemetry(devices, latestByZone);
});

final localPredictionProvider = FutureProvider.family<Prediction?, String>((
  ref,
  zoneId,
) async {
  final telemetryRepository = await ref.watch(
    localTelemetryRepositoryProvider.future,
  );
  final telemetry = await telemetryRepository.loadLatest(zoneId);
  if (telemetry == null) return null;
  return predictionFromTelemetry(telemetry);
});

final localHistoryProvider = FutureProvider.family<List<SensorDataPoint>, ({
  String zoneId,
  int hours,
})>((ref, args) async {
  final telemetryRepository = await ref.watch(
    localTelemetryRepositoryProvider.future,
  );
  return telemetryRepository.loadSensorHistory(args.zoneId, hours: args.hours);
});
