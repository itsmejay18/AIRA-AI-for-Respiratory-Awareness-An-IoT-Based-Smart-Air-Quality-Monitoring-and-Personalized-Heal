import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_constants.dart';
import '../models/device_telemetry.dart';
import '../models/sensor_data_point.dart';

class LocalTelemetryRepository {
  LocalTelemetryRepository({required SharedPreferences preferences})
    : _preferences = preferences;

  final SharedPreferences _preferences;

  Future<void> saveTelemetry(DeviceTelemetry telemetry) async {
    final all = await _loadAll();
    final zoneItems = List<Map<String, dynamic>>.from(
      all[telemetry.zoneId] ?? const [],
    );

    zoneItems.insert(0, telemetry.toMap());
    if (zoneItems.length > 120) {
      zoneItems.removeRange(120, zoneItems.length);
    }
    all[telemetry.zoneId] = zoneItems;

    await _preferences.setString(
      AppConstants.localTelemetryPrefsKey,
      jsonEncode(all),
    );
  }

  Future<DeviceTelemetry?> loadLatest(String zoneId) async {
    final history = await loadHistory(zoneId);
    return history.isEmpty ? null : history.first;
  }

  Future<Map<String, DeviceTelemetry>> loadLatestByZone() async {
    final all = await _loadAll();
    final result = <String, DeviceTelemetry>{};
    for (final entry in all.entries) {
      final items = List<Map<String, dynamic>>.from(entry.value);
      if (items.isNotEmpty) {
        result[entry.key] = DeviceTelemetry.fromMap(items.first);
      }
    }
    return result;
  }

  Future<List<DeviceTelemetry>> loadHistory(String zoneId) async {
    final all = await _loadAll();
    final items = List<Map<String, dynamic>>.from(all[zoneId] ?? const []);
    return items.map(DeviceTelemetry.fromMap).toList();
  }

  Future<List<SensorDataPoint>> loadSensorHistory(
    String zoneId, {
    required int hours,
  }) async {
    final cutoff = DateTime.now().subtract(Duration(hours: hours));
    final history = await loadHistory(zoneId);
    return history
        .where((item) => item.recordedAt.isAfter(cutoff))
        .map(
          (item) => SensorDataPoint(
            id: '${item.zoneId}-${item.recordedAt.millisecondsSinceEpoch}',
            zoneId: item.zoneId,
            soilMoisture: item.soilMoisture,
            temperature: item.temperature,
            humidity: item.humidity,
            recordedAt: item.recordedAt,
          ),
        )
        .toList();
  }

  Future<void> clearZoneHistory(String zoneId) async {
    final all = await _loadAll();
    all.remove(zoneId);
    await _preferences.setString(
      AppConstants.localTelemetryPrefsKey,
      jsonEncode(all),
    );
  }

  Future<void> clearAllHistory() async {
    await _preferences.remove(AppConstants.localTelemetryPrefsKey);
  }

  Future<Map<String, dynamic>> _loadAll() async {
    final raw = _preferences.getString(AppConstants.localTelemetryPrefsKey);
    if (raw == null || raw.isEmpty) return <String, dynamic>{};
    return Map<String, dynamic>.from(jsonDecode(raw) as Map<String, dynamic>);
  }
}
