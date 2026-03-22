import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/async_value_widget.dart';
import '../../../data/models/iot_device.dart';
import '../../../presentation/widgets/empty_state_card.dart';
import '../../../presentation/widgets/iot_device_card.dart';
import '../../../presentation/widgets/zone_card.dart';
import '../../../presentation/widgets/runtime_status_banner.dart';
import '../../alerts/application/alerts_providers.dart';
import '../application/dashboard_providers.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final zones = ref.watch(zonesProvider);
    final unreadCount = ref.watch(unreadAlertsCountProvider);
    final runtimeStatus = ref.watch(appRuntimeStatusProvider).asData?.value;
    final iotDevices =
        ref.watch(iotDevicesProvider).asData?.value ?? const <IoTDevice>[];

    return AsyncValueWidget(
      value: zones,
      loadingMessage: 'Loading live farm zones...',
      data: (items) {
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(zonesProvider),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2F7D32), Color(0xFF7FB069)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Farm overview',
                      style: Theme.of(
                        context,
                      ).textTheme.titleMedium?.copyWith(color: Colors.white70),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Monitor plant health, stress signals, and irrigation activity across all zones.',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ],
                ),
              ),
              if (runtimeStatus != null) ...[
                const SizedBox(height: 16),
                RuntimeStatusBanner(status: runtimeStatus),
              ],
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Active zones',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            Text(
                              '${items.length}',
                              style: Theme.of(context).textTheme.displaySmall
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Unread alerts',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            Text(
                              '$unreadCount',
                              style: Theme.of(context).textTheme.displaySmall
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'IoT nodes online',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            Text(
                              '${iotDevices.where((device) => device.connectionState == IoTConnectionState.online).length}',
                              style: Theme.of(context).textTheme.displaySmall
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (iotDevices.isNotEmpty) ...[
                Text(
                  'IoT node monitoring',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                for (final device in iotDevices.take(2)) ...[
                  IoTDeviceCard(device: device, compact: true),
                  const SizedBox(height: 12),
                ],
              ] else ...[
                const EmptyStateCard(
                  icon: Icons.router_outlined,
                  title: 'No IoT nodes yet',
                  message:
                      'Attach ESP32 sensor nodes to each farm zone to monitor device health and connectivity here.',
                ),
                const SizedBox(height: 12),
              ],
              for (final zone in items) ...[
                ZoneCard(
                  zone: zone,
                  onTap: () => context.push('/zone/${zone.id}'),
                ),
                const SizedBox(height: 12),
              ],
            ],
          ),
        );
      },
    );
  }
}
