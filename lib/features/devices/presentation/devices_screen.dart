import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/async_value_widget.dart';
import '../../../data/models/zone.dart';
import '../../../presentation/widgets/empty_state_card.dart';
import '../../../presentation/widgets/iot_device_card.dart';
import '../../dashboard/application/dashboard_providers.dart';

class DevicesScreen extends ConsumerWidget {
  const DevicesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final zones = ref.watch(zonesProvider);
    final devices = ref.watch(iotDevicesProvider);
    final runtimeStatus = ref.watch(appRuntimeStatusProvider).asData?.value;

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
                    'Register a device to a farm zone first. After that, flash the ESP32 with the backend URL and matching device id so real telemetry starts appearing in the app.',
                  ),
                  if (runtimeStatus != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      runtimeStatus.liveDataAvailable
                          ? 'Backend status: connected to live data'
                          : runtimeStatus.needsSetup
                          ? 'Backend status: setup still incomplete'
                          : 'Backend status: connected but waiting for real telemetry',
                    ),
                  ],
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () => _showRegisterSheet(context, ref),
                    icon: const Icon(Icons.add_link),
                    label: const Text('Register ESP32'),
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
                    const SizedBox(height: 12),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: 8),
          AsyncValueWidget(
            value: zones,
            loadingMessage: 'Loading available zones...',
            data: (items) {
              if (items.isEmpty) {
                return const EmptyStateCard(
                  icon: Icons.map_outlined,
                  title: 'No zones available for pairing',
                  message:
                      'Create zone rows in Supabase first. Device registration depends on a real zone id.',
                );
              }

              return const SizedBox.shrink();
            },
          ),
        ],
      ),
    );
  }

  Future<void> _showRegisterSheet(BuildContext context, WidgetRef ref) async {
    final zones = ref.read(zonesProvider).asData?.value ?? const <Zone>[];
    if (zones.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Create at least one real zone in Supabase before registering a device.',
          ),
        ),
      );
      return;
    }

    final formKey = GlobalKey<FormState>();
    final deviceIdController = TextEditingController();
    final deviceNameController = TextEditingController();
    var selectedZoneId = zones.first.id;

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
                      'Register ESP32',
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
                    DropdownButtonFormField<String>(
                      initialValue: selectedZoneId,
                      decoration: const InputDecoration(labelText: 'Zone'),
                      items: [
                        for (final zone in zones)
                          DropdownMenuItem(
                            value: zone.id,
                            child: Text(zone.name),
                          ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => selectedZoneId = value);
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () async {
                        if (!formKey.currentState!.validate()) return;

                        try {
                          await ref.read(farmRepositoryProvider).registerDevice(
                            deviceId: deviceIdController.text.trim(),
                            zoneId: selectedZoneId,
                            deviceName: deviceNameController.text.trim(),
                          );
                          ref.invalidate(iotDevicesProvider);
                          if (!context.mounted) return;
                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'ESP32 registered. Start sending telemetry to complete the connection.',
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
            const Text('1. Create real zone rows in Supabase.'),
            const SizedBox(height: 6),
            const Text('2. Register the ESP32 here with its real device id.'),
            const SizedBox(height: 6),
            const Text('3. Flash the ESP32 with the same device id and backend URL.'),
            const SizedBox(height: 6),
            const Text('4. Once telemetry reaches the backend, the device status becomes live in the app.'),
          ],
        ),
      ),
    );
  }
}
