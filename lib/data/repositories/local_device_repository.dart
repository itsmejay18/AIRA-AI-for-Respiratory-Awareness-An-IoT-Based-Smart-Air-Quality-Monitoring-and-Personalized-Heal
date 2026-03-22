import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_constants.dart';
import '../models/iot_device.dart';

class LocalDeviceRepository {
  LocalDeviceRepository({required SharedPreferences preferences})
    : _preferences = preferences;

  final SharedPreferences _preferences;

  Future<List<IoTDevice>> loadDevices() async {
    final raw = _preferences.getString(AppConstants.localDevicesPrefsKey);
    if (raw == null || raw.isEmpty) {
      return const [];
    }

    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((item) => IoTDevice.fromMap(item as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => b.lastSeen.compareTo(a.lastSeen));
  }

  Future<void> registerDevice({
    required String deviceId,
    required String zoneId,
    required String deviceName,
    required String endpointUrl,
  }) async {
    final devices = await loadDevices();
    final index = devices.indexWhere((device) => device.id == deviceId);
    final device = IoTDevice(
      id: deviceId,
      zoneId: zoneId,
      name: deviceName,
      endpointUrl: endpointUrl,
      connectionState: IoTConnectionState.offline,
      lastSeen: DateTime.now(),
      batteryLevel: index >= 0 ? devices[index].batteryLevel : 100,
      signalStrength: index >= 0 ? devices[index].signalStrength : 0,
      firmwareVersion: index >= 0
          ? devices[index].firmwareVersion
          : 'awaiting-first-sync',
      pumpOnline: index >= 0 ? devices[index].pumpOnline : false,
      pendingSync: true,
    );

    if (index >= 0) {
      devices[index] = device;
    } else {
      devices.add(device);
    }

    await _saveDevices(devices);
  }

  Future<IoTDevice?> loadDeviceForZone(String zoneId) async {
    final devices = await loadDevices();
    for (final device in devices) {
      if (device.zoneId == zoneId) {
        return device;
      }
    }
    return null;
  }

  Future<void> saveDevice(IoTDevice device) async {
    final devices = await loadDevices();
    final index = devices.indexWhere((item) => item.id == device.id);
    if (index >= 0) {
      devices[index] = device;
    } else {
      devices.add(device);
    }
    await _saveDevices(devices);
  }

  Future<IoTDevice?> loadDevice(String deviceId) async {
    final devices = await loadDevices();
    for (final device in devices) {
      if (device.id == deviceId) {
        return device;
      }
    }
    return null;
  }

  Future<void> deleteDevice(String deviceId) async {
    final devices = await loadDevices();
    devices.removeWhere((device) => device.id == deviceId);
    await _saveDevices(devices);
  }

  Future<void> _saveDevices(List<IoTDevice> devices) async {
    await _preferences.setString(
      AppConstants.localDevicesPrefsKey,
      jsonEncode(devices.map((device) => device.toMap()).toList()),
    );
  }
}
