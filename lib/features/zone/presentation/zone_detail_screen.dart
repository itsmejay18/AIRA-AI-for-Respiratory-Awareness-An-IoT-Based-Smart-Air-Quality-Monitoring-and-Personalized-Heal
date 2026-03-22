import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/plant_translator.dart';
import '../../../core/utils/status_color_helper.dart';
import '../../../core/widgets/async_value_widget.dart';
import '../../../data/models/sensor_data_point.dart';
import '../../../data/repositories/farm_repository.dart';
import '../../../presentation/widgets/empty_state_card.dart';
import '../../../presentation/widgets/iot_device_card.dart';
import '../../../presentation/widgets/sensor_metric_tile.dart';
import '../../../presentation/widgets/time_range_selector.dart';
import '../../dashboard/application/dashboard_providers.dart';
import '../application/iot_providers.dart';
import '../application/zone_providers.dart';

class ZoneDetailScreen extends ConsumerStatefulWidget {
  const ZoneDetailScreen({super.key, required this.zoneId});

  final String zoneId;

  @override
  ConsumerState<ZoneDetailScreen> createState() => _ZoneDetailScreenState();
}

class _ZoneDetailScreenState extends ConsumerState<ZoneDetailScreen> {
  AnalyticsRange _range = AnalyticsRange.last24Hours;

  @override
  Widget build(BuildContext context) {
    final details = ref.watch(zoneDetailsProvider(widget.zoneId));
    final history = ref.watch(
      zoneHistoryProvider((zoneId: widget.zoneId, range: _range)),
    );
    final device = ref.watch(zoneIoTDeviceProvider(widget.zoneId));

    return Scaffold(
      appBar: AppBar(title: const Text('Zone Details')),
      body: AsyncValueWidget(
        value: details,
        loadingMessage: 'Loading zone telemetry...',
        data: (zoneDetails) {
          final statusColor = StatusColorHelper.forLevel(
            zoneDetails.prediction.stressLevel,
          );
          final translator = plantTranslatorMessage(
            zone: zoneDetails.zone,
            prediction: zoneDetails.prediction,
          );

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        zoneDetails.zone.name,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _StatusBadge(
                            label:
                                'Current ${zoneDetails.zone.currentStress.name}',
                            color: StatusColorHelper.forLevel(
                              zoneDetails.zone.currentStress,
                            ),
                          ),
                          _StatusBadge(
                            label:
                                'Predicted ${zoneDetails.zone.predictedStress.name}',
                            color: statusColor,
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Text(
                        translator,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: MediaQuery.of(context).size.width > 700 ? 3 : 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 2.2,
                children: [
                  SensorMetricTile(
                    icon: Icons.water_drop_outlined,
                    label: 'Soil Moisture',
                    value:
                        '${zoneDetails.latestSensorData.soilMoisture.toStringAsFixed(1)}%',
                  ),
                  SensorMetricTile(
                    icon: Icons.thermostat_outlined,
                    label: 'Temperature',
                    value:
                        '${zoneDetails.latestSensorData.temperature.toStringAsFixed(1)}C',
                  ),
                  SensorMetricTile(
                    icon: Icons.waterfall_chart,
                    label: 'Humidity',
                    value:
                        '${zoneDetails.latestSensorData.humidity.toStringAsFixed(1)}%',
                  ),
                  SensorMetricTile(
                    icon: Icons.psychology_outlined,
                    label: 'Stress Probability',
                    value:
                        '${(zoneDetails.prediction.stressProbability * 100).toStringAsFixed(0)}%',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Forecast',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(zoneDetails.prediction.summary),
                      const SizedBox(height: 8),
                      Text(
                        'Next ${zoneDetails.prediction.forecastHours} hours',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Last action: ${zoneDetails.lastAction?.actionType ?? 'No recent action'}',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              device.when(
                data: (value) => value == null
                    ? const EmptyStateCard(
                        icon: Icons.memory_outlined,
                        title: 'No node assigned',
                        message:
                            'Assign an ESP32 device to this zone to monitor connectivity, battery, and actuator health.',
                      )
                    : IoTDeviceCard(device: value),
                loading: () => const Card(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ),
                error: (error, _) => Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text('Unable to load IoT node status: $error'),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () async {
                  final repository = ref.read(farmRepositoryProvider);
                  final action = await repository.triggerManualIrrigation(
                    widget.zoneId,
                  );

                  if (!context.mounted) return;

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Irrigation ${action.status}: ${action.notes}',
                      ),
                    ),
                  );

                  ref.invalidate(zoneDetailsProvider(widget.zoneId));
                },
                icon: const Icon(Icons.power),
                label: const Text('Start Manual Irrigation'),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Sensor History',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          TimeRangeSelector(
                            selected: _range,
                            onSelected: (range) {
                              setState(() => _range = range);
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      history.when(
                        data: (points) {
                          if (points.isEmpty) {
                            return const EmptyStateCard(
                              icon: Icons.timeline,
                              title: 'No history yet',
                              message:
                                  'Sensor history will appear here after telemetry records start arriving.',
                            );
                          }

                          return SizedBox(
                            height: 280,
                            child: _HistoryChart(
                              points: points.reversed.toList(),
                            ),
                          );
                        },
                        loading: () => const Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                        error: (error, _) => Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text('Could not load history: $error'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _HistoryChart extends StatelessWidget {
  const _HistoryChart({required this.points});

  final List<SensorDataPoint> points;

  @override
  Widget build(BuildContext context) {
    final moistureSpots = <FlSpot>[];
    final temperatureSpots = <FlSpot>[];
    final humiditySpots = <FlSpot>[];

    for (var i = 0; i < points.length; i++) {
      final point = points[i];
      moistureSpots.add(FlSpot(i.toDouble(), point.soilMoisture));
      temperatureSpots.add(FlSpot(i.toDouble(), point.temperature));
      humiditySpots.add(FlSpot(i.toDouble(), point.humidity));
    }

    return LineChart(
      LineChartData(
        minY: 0,
        gridData: const FlGridData(show: true),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 3,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= points.length) {
                  return const SizedBox.shrink();
                }

                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(DateFormat.Hm().format(points[index].recordedAt)),
                );
              },
            ),
          ),
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: true, reservedSize: 40),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: moistureSpots,
            isCurved: true,
            color: const Color(0xFF2F7D32),
            barWidth: 3,
          ),
          LineChartBarData(
            spots: temperatureSpots,
            isCurved: true,
            color: const Color(0xFFE65100),
            barWidth: 3,
          ),
          LineChartBarData(
            spots: humiditySpots,
            isCurved: true,
            color: const Color(0xFF0277BD),
            barWidth: 3,
          ),
        ],
      ),
    );
  }
}
