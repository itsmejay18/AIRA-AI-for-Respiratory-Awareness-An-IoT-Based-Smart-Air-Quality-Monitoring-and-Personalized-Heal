import 'package:equatable/equatable.dart';

class DeviceTelemetry extends Equatable {
  const DeviceTelemetry({
    required this.deviceId,
    required this.zoneId,
    required this.soilMoisture,
    required this.temperature,
    required this.humidity,
    required this.batteryLevel,
    required this.signalStrength,
    required this.firmwareVersion,
    required this.pumpOnline,
    required this.recordedAt,
  });

  final String deviceId;
  final String zoneId;
  final double soilMoisture;
  final double temperature;
  final double humidity;
  final int batteryLevel;
  final int signalStrength;
  final String firmwareVersion;
  final bool pumpOnline;
  final DateTime recordedAt;

  factory DeviceTelemetry.fromMap(Map<String, dynamic> map) {
    return DeviceTelemetry(
      deviceId: map['device_id'].toString(),
      zoneId: map['zone_id'].toString(),
      soilMoisture: (map['soil_moisture'] as num?)?.toDouble() ?? 0,
      temperature: (map['temperature'] as num?)?.toDouble() ?? 0,
      humidity: (map['humidity'] as num?)?.toDouble() ?? 0,
      batteryLevel: map['battery_level'] as int? ?? 100,
      signalStrength: map['signal_strength'] as int? ?? 100,
      firmwareVersion: map['firmware_version'] as String? ?? '1.0.0',
      pumpOnline: map['pump_online'] as bool? ?? false,
      recordedAt:
          DateTime.tryParse(map['recorded_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'device_id': deviceId,
      'zone_id': zoneId,
      'soil_moisture': soilMoisture,
      'temperature': temperature,
      'humidity': humidity,
      'battery_level': batteryLevel,
      'signal_strength': signalStrength,
      'firmware_version': firmwareVersion,
      'pump_online': pumpOnline,
      'recorded_at': recordedAt.toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [
    deviceId,
    zoneId,
    soilMoisture,
    temperature,
    humidity,
    batteryLevel,
    signalStrength,
    firmwareVersion,
    pumpOnline,
    recordedAt,
  ];
}
