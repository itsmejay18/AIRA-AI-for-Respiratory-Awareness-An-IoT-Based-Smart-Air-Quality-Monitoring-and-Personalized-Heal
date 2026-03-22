import 'package:equatable/equatable.dart';

enum IoTConnectionState { online, warning, offline }

class IoTDevice extends Equatable {
  const IoTDevice({
    required this.id,
    required this.zoneId,
    required this.name,
    required this.connectionState,
    required this.lastSeen,
    required this.batteryLevel,
    required this.signalStrength,
    required this.firmwareVersion,
    required this.pumpOnline,
    required this.pendingSync,
  });

  final String id;
  final String zoneId;
  final String name;
  final IoTConnectionState connectionState;
  final DateTime lastSeen;
  final int batteryLevel;
  final int signalStrength;
  final String firmwareVersion;
  final bool pumpOnline;
  final bool pendingSync;

  factory IoTDevice.fromMap(Map<String, dynamic> map) {
    return IoTDevice(
      id: map['id'].toString(),
      zoneId: map['zone_id'].toString(),
      name: map['name'] as String? ?? 'Sensor Node',
      connectionState: _stateFromString(map['connection_state'] as String?),
      lastSeen:
          DateTime.tryParse(map['last_seen'] as String? ?? '') ??
          DateTime.now(),
      batteryLevel: map['battery_level'] as int? ?? 100,
      signalStrength: map['signal_strength'] as int? ?? 100,
      firmwareVersion: map['firmware_version'] as String? ?? '1.0.0',
      pumpOnline: map['pump_online'] as bool? ?? true,
      pendingSync: map['pending_sync'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'zone_id': zoneId,
      'name': name,
      'connection_state': connectionState.name,
      'last_seen': lastSeen.toIso8601String(),
      'battery_level': batteryLevel,
      'signal_strength': signalStrength,
      'firmware_version': firmwareVersion,
      'pump_online': pumpOnline,
      'pending_sync': pendingSync,
    };
  }

  static IoTConnectionState _stateFromString(String? value) {
    return IoTConnectionState.values.firstWhere(
      (item) => item.name == value,
      orElse: () => IoTConnectionState.online,
    );
  }

  @override
  List<Object?> get props => [
    id,
    zoneId,
    name,
    connectionState,
    lastSeen,
    batteryLevel,
    signalStrength,
    firmwareVersion,
    pumpOnline,
    pendingSync,
  ];
}
