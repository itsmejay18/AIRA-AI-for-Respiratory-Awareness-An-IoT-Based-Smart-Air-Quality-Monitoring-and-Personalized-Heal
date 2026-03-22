import 'package:dio/dio.dart';

import '../models/device_telemetry.dart';
import '../models/iot_device.dart';

class Esp32DeviceService {
  Esp32DeviceService()
    : _dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
        ),
      );

  final Dio _dio;

  Future<DeviceTelemetry> fetchTelemetry(IoTDevice device) async {
    final baseUrl = _normalize(device.endpointUrl);
    final response = await _dio.get('$baseUrl/status');
    final data = response.data as Map<String, dynamic>;

    final environment = _map(data['environment']);
    final connectivity = _map(data['connectivity']);
    final actuators = _map(data['actuators']);

    return DeviceTelemetry(
      deviceId: (data['device_id'] ?? device.id).toString(),
      zoneId: (data['zone_id'] ?? device.zoneId).toString(),
      soilMoisture:
          ((environment['soil_moisture'] ?? data['soil_moisture']) as num?)
              ?.toDouble() ??
          0,
      temperature:
          ((environment['temperature'] ?? data['temperature']) as num?)
              ?.toDouble() ??
          0,
      humidity:
          ((environment['humidity'] ?? data['humidity']) as num?)?.toDouble() ??
          0,
      batteryLevel:
          (connectivity['battery_level'] ?? data['battery_level']) as int? ??
          device.batteryLevel,
      signalStrength:
          (connectivity['signal_strength'] ?? data['signal_strength']) as int? ??
          device.signalStrength,
      firmwareVersion:
          (data['firmware_version'] ?? device.firmwareVersion).toString(),
      pumpOnline:
          (actuators['pump_online'] ?? data['pump_online']) as bool? ??
          device.pumpOnline,
      recordedAt:
          DateTime.tryParse((data['timestamp'] ?? data['recorded_at'] ?? '')
                  .toString()) ??
          DateTime.now(),
    );
  }

  Future<void> triggerIrrigation(IoTDevice device) async {
    final baseUrl = _normalize(device.endpointUrl);
    await _dio.post(
      '$baseUrl/actuate',
      data: {'action': 'manual_irrigation', 'zone_id': device.zoneId},
    );
  }

  Future<bool> ping(IoTDevice device) async {
    if (device.endpointUrl.isEmpty) return false;
    try {
      final baseUrl = _normalize(device.endpointUrl);
      final response = await _dio.get('$baseUrl/health');
      return response.statusCode == 200;
    } catch (_) {
      try {
        await fetchTelemetry(device);
        return true;
      } catch (_) {
        return false;
      }
    }
  }

  Map<String, dynamic> _map(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return value.cast<String, dynamic>();
    return const <String, dynamic>{};
  }

  String _normalize(String url) {
    var normalized = url.trim();
    if (!normalized.startsWith('http://') &&
        !normalized.startsWith('https://')) {
      normalized = 'http://$normalized';
    }
    if (normalized.endsWith('/')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    return normalized;
  }
}
