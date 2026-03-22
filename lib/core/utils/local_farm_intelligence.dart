import '../../data/models/device_telemetry.dart';
import '../../data/models/farm_alert.dart';
import '../../data/models/prediction.dart';
import '../../data/models/sensor_data_point.dart';
import '../../data/models/zone.dart';
import '../../data/models/iot_device.dart';

double _clamp(double value, double min, double max) {
  if (value < min) return min;
  if (value > max) return max;
  return value;
}

double estimateStressProbability(DeviceTelemetry telemetry) {
  final moistureRisk = _clamp((55 - telemetry.soilMoisture) / 35, 0, 1);
  final temperatureRisk = _clamp((telemetry.temperature - 28) / 10, 0, 1);
  final humidityRisk = _clamp((50 - telemetry.humidity) / 30, 0, 1);
  return ((moistureRisk * 0.55) +
          (temperatureRisk * 0.30) +
          (humidityRisk * 0.15))
      .clamp(0, 1)
      .toDouble();
}

StressLevel estimateStressLevel(DeviceTelemetry telemetry) {
  final probability = estimateStressProbability(telemetry);
  if (probability >= 0.7) return StressLevel.critical;
  if (probability >= 0.4) return StressLevel.warning;
  return StressLevel.healthy;
}

Zone zoneFromDevice(IoTDevice device, DeviceTelemetry telemetry) {
  final stress = estimateStressLevel(telemetry);
  return Zone(
    id: telemetry.zoneId,
    name: device.name,
    soilMoisture: telemetry.soilMoisture,
    temperature: telemetry.temperature,
    humidity: telemetry.humidity,
    currentStress: stress,
    predictedStress: stress,
    autoIrrigationEnabled: true,
  );
}

Prediction predictionFromTelemetry(DeviceTelemetry telemetry) {
  final probability = estimateStressProbability(telemetry);
  final level = estimateStressLevel(telemetry);
  final summary = switch (level) {
    StressLevel.critical =>
      'High drought stress risk detected from direct ESP32 telemetry.',
    StressLevel.warning =>
      'Warning signs detected from local device telemetry.',
    StressLevel.healthy => 'Local telemetry indicates stable plant conditions.',
  };

  return Prediction(
    zoneId: telemetry.zoneId,
    stressProbability: probability,
    stressLevel: level,
    forecastHours: level == StressLevel.healthy ? 8 : 4,
    summary: summary,
    createdAt: telemetry.recordedAt,
  );
}

SensorDataPoint sensorPointFromTelemetry(DeviceTelemetry telemetry) {
  return SensorDataPoint(
    id: '${telemetry.zoneId}-${telemetry.recordedAt.millisecondsSinceEpoch}',
    zoneId: telemetry.zoneId,
    soilMoisture: telemetry.soilMoisture,
    temperature: telemetry.temperature,
    humidity: telemetry.humidity,
    recordedAt: telemetry.recordedAt,
  );
}

List<FarmAlert> alertsFromTelemetry(
  List<IoTDevice> devices,
  Map<String, DeviceTelemetry> latestByZone,
) {
  final alerts = <FarmAlert>[];
  for (final device in devices) {
    final telemetry = latestByZone[device.zoneId];

    if (device.connectionState == IoTConnectionState.offline) {
      alerts.add(
        FarmAlert(
          id: 'local-offline-${device.id}',
          zoneId: device.zoneId,
          title: 'Device Offline',
          message: '${device.name} is offline or unreachable.',
          type: 'device',
          isRead: false,
          createdAt: device.lastSeen,
        ),
      );
    }

    if (telemetry == null) continue;

    final prediction = predictionFromTelemetry(telemetry);
    if (prediction.stressLevel == StressLevel.warning ||
        prediction.stressLevel == StressLevel.critical) {
      alerts.add(
        FarmAlert(
          id: 'local-stress-${device.id}-${telemetry.recordedAt.millisecondsSinceEpoch}',
          zoneId: device.zoneId,
          title: prediction.stressLevel == StressLevel.critical
              ? 'Critical Stress Risk'
              : 'Stress Warning',
          message: prediction.summary,
          type: 'prediction',
          isRead: false,
          createdAt: telemetry.recordedAt,
        ),
      );
    }
  }

  alerts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return alerts;
}
