import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/models/iot_device.dart';

class IoTDeviceCard extends StatelessWidget {
  const IoTDeviceCard({super.key, required this.device, this.compact = false});

  final IoTDevice device;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final tone = _colorForState(device.connectionState);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    device.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: tone.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    device.connectionState.name.toUpperCase(),
                    style: TextStyle(color: tone, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Last seen ${DateFormat.yMMMd().add_jm().format(device.lastSeen)}',
            ),
            if (!compact && device.endpointUrl.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                'Endpoint ${device.endpointUrl}',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.black54),
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _mini(context, 'Battery', '${device.batteryLevel}%'),
                _mini(context, 'Signal', '${device.signalStrength}%'),
                _mini(context, 'Firmware', device.firmwareVersion),
                _mini(
                  context,
                  'Pump',
                  device.pumpOnline ? 'Online' : 'Offline',
                ),
                if (!compact)
                  _mini(
                    context,
                    'Sync',
                    device.pendingSync ? 'Pending' : 'Synced',
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _mini(BuildContext context, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: RichText(
        text: TextSpan(
          style: Theme.of(context).textTheme.bodyMedium,
          children: [
            TextSpan(
              text: '$label\n',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }

  Color _colorForState(IoTConnectionState state) {
    switch (state) {
      case IoTConnectionState.online:
        return const Color(0xFF2E7D32);
      case IoTConnectionState.warning:
        return const Color(0xFFF9A825);
      case IoTConnectionState.offline:
        return const Color(0xFFC62828);
    }
  }
}
