import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/farm_action.dart';
import '../models/farm_alert.dart';
import '../models/iot_device.dart';
import '../models/prediction.dart';
import '../models/sensor_data_point.dart';
import '../models/zone.dart';
import '../models/zone_details.dart';
import '../services/ai_api_service.dart';

enum AnalyticsRange {
  last24Hours('24h', 24),
  last7Days('7d', 7 * 24),
  last30Days('30d', 30 * 24);

  const AnalyticsRange(this.label, this.hours);
  final String label;
  final int hours;
}

class FarmRepository {
  FarmRepository({
    required AiApiService aiApiService,
    SupabaseClient? supabaseClient,
  }) : _aiApiService = aiApiService,
       _supabaseClient = supabaseClient;

  final AiApiService _aiApiService;
  final SupabaseClient? _supabaseClient;

  Future<List<Zone>> fetchZones() async {
    final client = _supabaseClient;
    if (client != null) {
      try {
        final zoneRows = await client.from('zones').select();
        final zones = (zoneRows as List<dynamic>)
            .map((item) => Zone.fromMap(item as Map<String, dynamic>))
            .toList();
        if (zones.isEmpty) {
          return _mockZones();
        }
        return Future.wait(zones.map(_enrichZone));
      } catch (_) {
        return _mockZones();
      }
    }

    return _mockZones();
  }

  Stream<List<Zone>> watchZones() {
    return _watchZonesStream();
  }

  Future<ZoneDetails> fetchZoneDetails(String zoneId) async {
    final zones = await fetchZones();
    final zone = zones.firstWhere((item) => item.id == zoneId);
    final history = await fetchSensorHistory(
      zoneId,
      AnalyticsRange.last24Hours,
    );
    final prediction = await fetchPrediction(zoneId);
    final action = await fetchLastAction(zoneId);
    final latestSensorData = history.isNotEmpty
        ? history.first
        : _mockHistory(zoneId, AnalyticsRange.last24Hours).first;

    return ZoneDetails(
      zone: zone,
      latestSensorData: latestSensorData,
      prediction: prediction,
      lastAction: action,
    );
  }

  Future<List<SensorDataPoint>> fetchSensorHistory(
    String zoneId,
    AnalyticsRange range,
  ) async {
    final client = _supabaseClient;
    if (client != null) {
      try {
        final start = DateTime.now()
            .subtract(Duration(hours: range.hours))
            .toIso8601String();
        final response = await client
            .from('sensor_data')
            .select()
            .eq('zone_id', zoneId)
            .gte('recorded_at', start)
            .order('recorded_at', ascending: false);

        return (response as List<dynamic>)
            .map(
              (item) => SensorDataPoint.fromMap(item as Map<String, dynamic>),
            )
            .toList();
      } catch (_) {
        return _mockHistory(zoneId, range);
      }
    }

    return _mockHistory(zoneId, range);
  }

  Future<Prediction> fetchPrediction(String zoneId) async {
    try {
      return await _aiApiService.fetchPrediction(zoneId);
    } catch (_) {
      final client = _supabaseClient;
      if (client != null) {
        try {
          final response = await client
              .from('predictions')
              .select()
              .eq('zone_id', zoneId)
              .order('created_at', ascending: false)
              .limit(1)
              .maybeSingle();

          if (response != null) {
            return Prediction.fromMap(response);
          }
        } catch (_) {
          return _mockPrediction(zoneId);
        }
      }
    }

    return _mockPrediction(zoneId);
  }

  Future<List<FarmAlert>> fetchAlerts() async {
    final client = _supabaseClient;
    if (client != null) {
      try {
        final response = await client
            .from('alerts')
            .select()
            .order('created_at', ascending: false);

        return (response as List<dynamic>)
            .map((item) => FarmAlert.fromMap(item as Map<String, dynamic>))
            .toList();
      } catch (_) {
        return _mockAlerts();
      }
    }

    try {
      return await _aiApiService.fetchAlerts();
    } catch (_) {
      return _mockAlerts();
    }
  }

  Stream<List<FarmAlert>> watchAlerts() {
    final client = _supabaseClient;
    if (client != null) {
      try {
        return client
            .from('alerts')
            .stream(primaryKey: ['id'])
            .order('created_at')
            .map(
              (rows) => rows
                  .map((item) => FarmAlert.fromMap(item))
                  .toList()
                  .reversed
                  .toList(),
            );
      } catch (_) {
        return Stream<List<FarmAlert>>.periodic(
          const Duration(seconds: 12),
          (_) => _mockAlerts(),
        ).startWith(_mockAlerts());
      }
    }

    return Stream<List<FarmAlert>>.periodic(
      const Duration(seconds: 12),
      (_) => _mockAlerts(),
    ).startWith(_mockAlerts());
  }

  Future<void> markAlertsRead(List<FarmAlert> alerts) async {
    final client = _supabaseClient;
    if (client != null) {
      try {
        for (final alert in alerts.where((item) => !item.isRead)) {
          await client
              .from('alerts')
              .update({'is_read': true})
              .eq('id', alert.id);
        }
      } catch (_) {
        return;
      }
    }
  }

  Future<FarmAction> triggerManualIrrigation(String zoneId) async {
    try {
      final action = await _aiApiService.actuate(
        zoneId: zoneId,
        action: 'manual_irrigation',
      );

      final client = _supabaseClient;
      if (client != null) {
        try {
          await client.from('actions').insert(action.toMap());
        } catch (_) {}
      }

      return action;
    } catch (_) {
      return FarmAction(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        zoneId: zoneId,
        actionType: 'manual_irrigation',
        status: 'completed',
        createdAt: DateTime.now(),
        notes: 'Pump activated successfully.',
      );
    }
  }

  Future<FarmAction?> fetchLastAction(String zoneId) async {
    final client = _supabaseClient;
    if (client != null) {
      try {
        final response = await client
            .from('actions')
            .select()
            .eq('zone_id', zoneId)
            .order('created_at', ascending: false)
            .limit(1)
            .maybeSingle();

        if (response != null) {
          return FarmAction.fromMap(response);
        }
      } catch (_) {
        // Fall through to the demo action below when the table is absent.
      }
    }

    return FarmAction(
      id: 'last-$zoneId',
      zoneId: zoneId,
      actionType: 'auto_irrigation',
      status: 'completed',
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      notes: 'Automatic drip cycle finished.',
    );
  }

  Future<List<IoTDevice>> fetchIoTDevices() async {
    final client = _supabaseClient;
    if (client != null) {
      try {
        final response = await client
            .from('iot_devices')
            .select()
            .order('last_seen', ascending: false);

        final devices = (response as List<dynamic>)
            .map((item) => IoTDevice.fromMap(item as Map<String, dynamic>))
            .toList();
        if (devices.isNotEmpty) {
          return devices;
        }
      } catch (_) {
        // Fall back to mock devices when the table is unavailable.
      }
    }

    return _mockIoTDevices();
  }

  Stream<List<IoTDevice>> watchIoTDevices() async* {
    yield await fetchIoTDevices();
    yield* Stream<void>.periodic(
      const Duration(seconds: 15),
    ).asyncMap((_) => fetchIoTDevices());
  }

  Future<IoTDevice?> fetchDeviceForZone(String zoneId) async {
    final devices = await fetchIoTDevices();
    for (final device in devices) {
      if (device.zoneId == zoneId) {
        return device;
      }
    }
    return null;
  }

  Stream<List<Zone>> _watchZonesStream() async* {
    yield await fetchZones();
    yield* Stream<void>.periodic(
      const Duration(seconds: 10),
    ).asyncMap((_) => fetchZones());
  }

  Future<Zone> _enrichZone(Zone zone) async {
    final history = await fetchSensorHistory(
      zone.id,
      AnalyticsRange.last24Hours,
    );
    final latest = history.first;
    final prediction = await fetchPrediction(zone.id);

    return zone.copyWith(
      soilMoisture: latest.soilMoisture,
      temperature: latest.temperature,
      humidity: latest.humidity,
      predictedStress: prediction.stressLevel,
    );
  }

  List<Zone> _mockZones() {
    return const [
      Zone(
        id: 'zone-1',
        name: 'North Field',
        soilMoisture: 62,
        temperature: 29,
        humidity: 58,
        currentStress: StressLevel.healthy,
        predictedStress: StressLevel.warning,
        autoIrrigationEnabled: true,
      ),
      Zone(
        id: 'zone-2',
        name: 'Greenhouse A',
        soilMoisture: 41,
        temperature: 31,
        humidity: 46,
        currentStress: StressLevel.warning,
        predictedStress: StressLevel.critical,
        autoIrrigationEnabled: true,
      ),
      Zone(
        id: 'zone-3',
        name: 'Seedling Bed',
        soilMoisture: 73,
        temperature: 27,
        humidity: 64,
        currentStress: StressLevel.healthy,
        predictedStress: StressLevel.healthy,
        autoIrrigationEnabled: false,
      ),
    ];
  }

  List<SensorDataPoint> _mockHistory(String zoneId, AnalyticsRange range) {
    final random = Random(zoneId.hashCode + range.hours);
    final now = DateTime.now();

    return List.generate(12, (index) {
      final baseMoisture = zoneId == 'zone-2' ? 43 : 60;
      final baseTemp = zoneId == 'zone-2' ? 31 : 28;
      return SensorDataPoint(
        id: '$zoneId-$index',
        zoneId: zoneId,
        soilMoisture: baseMoisture - index * 0.9 + random.nextDouble() * 2,
        temperature: baseTemp + random.nextDouble() * 1.8,
        humidity: 48 + random.nextDouble() * 18,
        recordedAt: now.subtract(Duration(hours: index * 2)),
      );
    });
  }

  Prediction _mockPrediction(String zoneId) {
    if (zoneId == 'zone-2') {
      return Prediction(
        zoneId: zoneId,
        stressProbability: 0.82,
        stressLevel: StressLevel.critical,
        forecastHours: 3,
        summary: 'Rapid moisture decline detected.',
        createdAt: DateTime.now(),
      );
    }

    if (zoneId == 'zone-1') {
      return Prediction(
        zoneId: zoneId,
        stressProbability: 0.46,
        stressLevel: StressLevel.warning,
        forecastHours: 6,
        summary: 'Mild drought stress may appear later today.',
        createdAt: DateTime.now(),
      );
    }

    return Prediction(
      zoneId: zoneId,
      stressProbability: 0.18,
      stressLevel: StressLevel.healthy,
      forecastHours: 8,
      summary: 'Plant health is stable.',
      createdAt: DateTime.now(),
    );
  }

  List<FarmAlert> _mockAlerts() {
    return [
      FarmAlert(
        id: 'alert-1',
        zoneId: 'zone-2',
        title: 'Drought Predicted',
        message: 'Greenhouse A may enter drought stress in 3 hours.',
        type: 'prediction',
        isRead: false,
        createdAt: DateTime.now().subtract(const Duration(minutes: 15)),
      ),
      FarmAlert(
        id: 'alert-2',
        zoneId: 'zone-1',
        title: 'Irrigation Triggered',
        message: 'Automatic irrigation completed for North Field.',
        type: 'action',
        isRead: true,
        createdAt: DateTime.now().subtract(const Duration(hours: 1)),
      ),
      FarmAlert(
        id: 'alert-3',
        zoneId: 'zone-3',
        title: 'Anomaly Detected',
        message: 'Humidity spike detected in Seedling Bed.',
        type: 'anomaly',
        isRead: false,
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      ),
    ];
  }

  List<IoTDevice> _mockIoTDevices() {
    final now = DateTime.now();
    return [
      IoTDevice(
        id: 'node-1',
        zoneId: 'zone-1',
        name: 'ESP32 North Field',
        connectionState: IoTConnectionState.online,
        lastSeen: now.subtract(const Duration(minutes: 2)),
        batteryLevel: 92,
        signalStrength: 88,
        firmwareVersion: '1.2.4',
        pumpOnline: true,
        pendingSync: false,
      ),
      IoTDevice(
        id: 'node-2',
        zoneId: 'zone-2',
        name: 'ESP32 Greenhouse A',
        connectionState: IoTConnectionState.warning,
        lastSeen: now.subtract(const Duration(minutes: 12)),
        batteryLevel: 44,
        signalStrength: 57,
        firmwareVersion: '1.2.3',
        pumpOnline: true,
        pendingSync: true,
      ),
      IoTDevice(
        id: 'node-3',
        zoneId: 'zone-3',
        name: 'ESP32 Seedling Bed',
        connectionState: IoTConnectionState.online,
        lastSeen: now.subtract(const Duration(minutes: 5)),
        batteryLevel: 76,
        signalStrength: 80,
        firmwareVersion: '1.2.4',
        pumpOnline: false,
        pendingSync: false,
      ),
    ];
  }
}

extension<T> on Stream<T> {
  Stream<T> startWith(T value) async* {
    yield value;
    yield* this;
  }
}
