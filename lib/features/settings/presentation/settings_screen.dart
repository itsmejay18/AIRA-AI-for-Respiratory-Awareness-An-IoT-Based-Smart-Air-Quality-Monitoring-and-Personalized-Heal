import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/async_value_widget.dart';
import '../../../data/models/app_settings.dart';
import '../../auth/application/auth_controller.dart';
import '../../dashboard/application/dashboard_providers.dart';
import '../application/settings_controller.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return AsyncValueWidget(
      value: settings,
      loadingMessage: 'Loading preferences...',
      data: (data) => _SettingsBody(settings: data),
    );
  }
}

class _SettingsBody extends ConsumerWidget {
  const _SettingsBody({required this.settings});

  final AppSettings settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(settingsControllerProvider);
    final runtimeStatus = ref.watch(appRuntimeStatusProvider).asData?.value;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.person)),
            title: Text(settings.fullName),
            subtitle: Text(settings.email),
          ),
        ),
        if (runtimeStatus != null) ...[
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: Icon(
                runtimeStatus.liveDataAvailable
                    ? Icons.cloud_done_outlined
                    : runtimeStatus.needsSetup
                    ? Icons.cloud_off_outlined
                    : Icons.hourglass_empty_outlined,
              ),
              title: Text(
                runtimeStatus.liveDataAvailable
                    ? 'Live Data Active'
                    : runtimeStatus.needsSetup
                    ? 'Backend Setup Required'
                    : 'Waiting for Live Data',
              ),
              subtitle: Text(
                runtimeStatus.liveDataAvailable
                    ? 'The app can reach your live farm data services.'
                    : runtimeStatus.needsSetup
                    ? 'Configure Supabase and the backend before users can receive telemetry.'
                    : 'No zone telemetry is loaded until real records arrive from your devices and database.',
              ),
            ),
          ),
        ],
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: const Icon(Icons.memory_outlined),
            title: const Text('Devices'),
            subtitle: const Text(
              'Register and connect ESP32 sensor nodes to your farm zones.',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/devices'),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: SwitchListTile(
            value: settings.autoIrrigationEnabled,
            title: const Text('Auto-Irrigation'),
            subtitle: const Text(
              'Let the system trigger irrigation automatically.',
            ),
            onChanged: controller.isLoading
                ? null
                : (value) {
                    ref
                        .read(settingsControllerProvider.notifier)
                        .updateSettings(
                          settings.copyWith(autoIrrigationEnabled: value),
                        );
                  },
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: SwitchListTile(
            value: settings.notificationsEnabled,
            title: const Text('Notifications'),
            subtitle: const Text('Receive drought and anomaly alerts.'),
            onChanged: controller.isLoading
                ? null
                : (value) {
                    ref
                        .read(settingsControllerProvider.notifier)
                        .updateSettings(
                          settings.copyWith(notificationsEnabled: value),
                        );
                  },
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.tonalIcon(
          onPressed: () async {
            await ref.read(authControllerProvider.notifier).signOut();
            if (!context.mounted) return;
            context.go('/login');
          },
          icon: const Icon(Icons.logout),
          label: const Text('Logout'),
        ),
      ],
    );
  }
}
