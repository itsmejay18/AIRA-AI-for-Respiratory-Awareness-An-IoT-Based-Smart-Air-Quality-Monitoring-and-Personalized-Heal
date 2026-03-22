import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/iot_device.dart';
import '../../../core/widgets/async_value_widget.dart';
import '../../../presentation/widgets/empty_state_card.dart';
import '../../../presentation/widgets/iot_device_card.dart';
import '../application/device_providers.dart';
import '../../alerts/application/alerts_providers.dart';
import '../../dashboard/application/dashboard_providers.dart';
import '../../zone/application/zone_providers.dart';

class DevicesScreen extends ConsumerWidget {
  const DevicesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final devices = ref.watch(iotDevicesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Devices')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Connect an ESP32 node',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Register an ESP32 directly in the app. This pairing setup is stored locally on the device, so you can prepare the hardware flow even without Supabase.',
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      FilledButton.icon(
                        onPressed: () => _showRegisterSheet(context, ref),
                        icon: const Icon(Icons.add_link),
                        label: const Text('Register ESP32'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _syncAll(context, ref),
                        icon: const Icon(Icons.sync),
                        label: const Text('Sync All'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _clearAllTelemetry(context, ref),
                        icon: const Icon(Icons.delete_sweep_outlined),
                        label: const Text('Clear Telemetry'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const _ConnectionSteps(),
          const SizedBox(height: 16),
          AsyncValueWidget(
            value: devices,
            loadingMessage: 'Loading devices...',
            data: (items) {
              if (items.isEmpty) {
                return const EmptyStateCard(
                  icon: Icons.memory_outlined,
                  title: 'No devices registered',
                  message:
                      'Once you register an ESP32 and it starts sending telemetry, it will appear here.',
                );
              }

              return Column(
                children: [
                  for (final device in items) ...[
                    IoTDeviceCard(device: device),
                    const SizedBox(height: 10),
                    _DeviceActions(
                      device: device,
                      onEdit: () => _showRegisterSheet(
                        context,
                        ref,
                        existingDevice: device,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: 8),
          const EmptyStateCard(
            icon: Icons.info_outline,
            title: 'App-managed setup',
            message:
                'Devices registered here are kept in local app storage. You can later connect telemetry delivery however you want.',
          ),
        ],
      ),
    );
  }

  Future<void> _showRegisterSheet(
    BuildContext context,
    WidgetRef ref, {
    IoTDevice? existingDevice,
  }) async {
    final formKey = GlobalKey<FormState>();
    final deviceIdController = TextEditingController(text: existingDevice?.id);
    final deviceNameController = TextEditingController(
      text: existingDevice?.name,
    );
    final zoneIdController = TextEditingController(
      text: existingDevice?.zoneId,
    );
    final endpointController = TextEditingController(
      text: existingDevice?.endpointUrl,
    );

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: StatefulBuilder(
            builder: (context, setState) {
              return Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      existingDevice == null ? 'Register ESP32' : 'Edit ESP32',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: deviceIdController,
                      decoration: const InputDecoration(
                        labelText: 'Device ID',
                        hintText: 'node-1',
                      ),
                      validator: (value) => value == null || value.trim().isEmpty
                          ? 'Device id is required'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: deviceNameController,
                      decoration: const InputDecoration(
                        labelText: 'Device name',
                        hintText: 'ESP32 North Field',
                      ),
                      validator: (value) => value == null || value.trim().isEmpty
                          ? 'Device name is required'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: zoneIdController,
                      decoration: const InputDecoration(
                        labelText: 'Zone ID',
                        hintText: 'north-field',
                      ),
                      validator: (value) => value == null || value.trim().isEmpty
                          ? 'Zone id is required'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: endpointController,
                      decoration: const InputDecoration(
                        labelText: 'ESP32 endpoint',
                        hintText: '192.168.1.50:80',
                      ),
                      validator: (value) => value == null || value.trim().isEmpty
                          ? 'Endpoint is required'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () async {
                        if (!formKey.currentState!.validate()) return;

                        try {
                          final repository = await ref.read(
                            localDeviceRepositoryProvider.future,
                          );
                          await repository.registerDevice(
                            deviceId: deviceIdController.text.trim(),
                            zoneId: zoneIdController.text.trim(),
                            deviceName: deviceNameController.text.trim(),
                            endpointUrl: endpointController.text.trim(),
                          );
                          ref.invalidate(iotDevicesProvider);
                          ref.invalidate(localZonesProvider);
                          if (!context.mounted) return;
                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                existingDevice == null
                                    ? 'ESP32 registered. Start sending telemetry to complete the connection.'
                                    : 'ESP32 settings updated.',
                              ),
                            ),
                          );
                        } catch (error) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Could not register device: $error'),
                            ),
                          );
                        }
                      },
                      child: const Text('Save Device'),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );

    deviceIdController.dispose();
    deviceNameController.dispose();
    zoneIdController.dispose();
    endpointController.dispose();
  }

  Future<void> _syncAll(BuildContext context, WidgetRef ref) async {
    final devices = await ref.read(iotDevicesProvider.future);
    if (devices.isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No devices to sync yet.')),
      );
      return;
    }

    final service = ref.read(esp32DeviceServiceProvider);
    final deviceRepository = await ref.read(localDeviceRepositoryProvider.future);
    final telemetryRepository = await ref.read(
      localTelemetryRepositoryProvider.future,
    );

    var synced = 0;
    for (final device in devices) {
      try {
        final telemetry = await service.fetchTelemetry(device);
        await telemetryRepository.saveTelemetry(telemetry);
        await deviceRepository.saveDevice(
          device.copyWith(
            zoneId: telemetry.zoneId,
            connectionState: IoTConnectionState.online,
            lastSeen: telemetry.recordedAt,
            batteryLevel: telemetry.batteryLevel,
            signalStrength: telemetry.signalStrength,
            firmwareVersion: telemetry.firmwareVersion,
            pumpOnline: telemetry.pumpOnline,
            pendingSync: false,
          ),
        );
        synced++;
      } catch (_) {
        await deviceRepository.saveDevice(
          device.copyWith(
            connectionState: IoTConnectionState.offline,
            pendingSync: true,
          ),
        );
      }
    }

    _invalidateAll(ref);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Synced $synced of ${devices.length} device(s).')),
    );
  }

  Future<void> _clearAllTelemetry(BuildContext context, WidgetRef ref) async {
    final telemetryRepository = await ref.read(
      localTelemetryRepositoryProvider.future,
    );
    await telemetryRepository.clearAllHistory();
    _invalidateAll(ref);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('All local telemetry history cleared.')),
    );
  }

  void _invalidateAll(WidgetRef ref) {
    ref.invalidate(iotDevicesProvider);
    ref.invalidate(localZonesProvider);
    ref.invalidate(localAlertsProvider);
    ref.invalidate(zonesProvider);
    ref.invalidate(alertsProvider);
  }
}

class _DeviceActions extends ConsumerWidget {
  const _DeviceActions({required this.device, required this.onEdit});

  final IoTDevice device;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        OutlinedButton.icon(
          onPressed: () => _ping(context, ref),
          icon: const Icon(Icons.wifi_tethering_outlined),
          label: const Text('Test'),
        ),
        FilledButton.tonalIcon(
          onPressed: () => _sync(context, ref),
          icon: const Icon(Icons.sync),
          label: const Text('Sync'),
        ),
        FilledButton.tonalIcon(
          onPressed: () => _irrigate(context, ref),
          icon: const Icon(Icons.water_drop_outlined),
          label: const Text('Irrigate'),
        ),
        OutlinedButton.icon(
          onPressed: onEdit,
          icon: const Icon(Icons.edit_outlined),
          label: const Text('Edit'),
        ),
        OutlinedButton.icon(
          onPressed: () => _clearTelemetry(context, ref),
          icon: const Icon(Icons.history_toggle_off),
          label: const Text('Clear History'),
        ),
        OutlinedButton.icon(
          onPressed: () => _delete(context, ref),
          icon: const Icon(Icons.delete_outline),
          label: const Text('Delete'),
        ),
      ],
    );
  }

  Future<void> _ping(BuildContext context, WidgetRef ref) async {
    final service = ref.read(esp32DeviceServiceProvider);
    final repository = await ref.read(localDeviceRepositoryProvider.future);
    final isOnline = await service.ping(device);
    final updated = device.copyWith(
      connectionState: isOnline
          ? IoTConnectionState.online
          : IoTConnectionState.offline,
      lastSeen: DateTime.now(),
      pendingSync: !isOnline,
    );
    await repository.saveDevice(updated);
    ref.invalidate(iotDevicesProvider);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isOnline
              ? '${device.name} is reachable.'
              : '${device.name} is not reachable.',
        ),
      ),
    );
  }

  Future<void> _sync(BuildContext context, WidgetRef ref) async {
    final service = ref.read(esp32DeviceServiceProvider);
    final deviceRepository = await ref.read(localDeviceRepositoryProvider.future);
    final telemetryRepository = await ref.read(
      localTelemetryRepositoryProvider.future,
    );

    try {
      final telemetry = await service.fetchTelemetry(device);
      await telemetryRepository.saveTelemetry(telemetry);
      await deviceRepository.saveDevice(
        device.copyWith(
          zoneId: telemetry.zoneId,
          connectionState: IoTConnectionState.online,
          lastSeen: telemetry.recordedAt,
          batteryLevel: telemetry.batteryLevel,
          signalStrength: telemetry.signalStrength,
          firmwareVersion: telemetry.firmwareVersion,
          pumpOnline: telemetry.pumpOnline,
          pendingSync: false,
        ),
      );
      _invalidateAll(ref);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Synced live telemetry from ${device.name}.'),
        ),
      );
    } catch (error) {
      await deviceRepository.saveDevice(
        device.copyWith(
          connectionState: IoTConnectionState.offline,
          pendingSync: true,
        ),
      );
      ref.invalidate(iotDevicesProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sync failed: $error')),
      );
    }
  }

  Future<void> _irrigate(BuildContext context, WidgetRef ref) async {
    final service = ref.read(esp32DeviceServiceProvider);
    final deviceRepository = await ref.read(localDeviceRepositoryProvider.future);
    try {
      await service.triggerIrrigation(device);
      await deviceRepository.saveDevice(
        device.copyWith(
          pumpOnline: true,
          connectionState: IoTConnectionState.online,
          lastSeen: DateTime.now(),
        ),
      );
      _invalidateAll(ref);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Irrigation triggered on ${device.name}.')),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not trigger irrigation: $error')),
      );
    }
  }

  void _invalidateAll(WidgetRef ref) {
    ref.invalidate(iotDevicesProvider);
    ref.invalidate(localZonesProvider);
    ref.invalidate(localAlertsProvider);
    ref.invalidate(zonesProvider);
    ref.invalidate(alertsProvider);
    ref.invalidate(zonePredictionProvider);
  }

  Future<void> _clearTelemetry(BuildContext context, WidgetRef ref) async {
    final telemetryRepository = await ref.read(
      localTelemetryRepositoryProvider.future,
    );
    await telemetryRepository.clearZoneHistory(device.zoneId);
    _invalidateAll(ref);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Cleared local telemetry for ${device.name}.')),
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final deviceRepository = await ref.read(localDeviceRepositoryProvider.future);
    await deviceRepository.deleteDevice(device.id);
    _invalidateAll(ref);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${device.name} removed from the app.')),
    );
  }
}

class _ConnectionSteps extends StatelessWidget {
  const _ConnectionSteps();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'How pairing works',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            const Text('1. Open the app and register your ESP32 node here.'),
            const SizedBox(height: 6),
            const Text('2. Enter the same device id and zone id you plan to use on the hardware.'),
            const SizedBox(height: 6),
            const Text('3. Flash the ESP32 with the same device id and your chosen transport setup.'),
            const SizedBox(height: 6),
            const Text('4. The app keeps the pairing record locally, even without Supabase.'),
          ],
        ),
      ),
    );
  }
}
