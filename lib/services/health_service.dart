import 'package:health/health.dart';
import 'package:flutter/foundation.dart';

/// Supported health metrics for habit auto-tracking.
enum HealthMetric {
  steps('Steps', 'steps'),
  sleepMinutes('Sleep (minutes)', 'minutes'),
  workoutMinutes('Workout (minutes)', 'minutes'),
  waterLiters('Water (liters)', 'liters'),
  mindfulMinutes('Mindful Minutes', 'minutes');

  final String label;
  final String unit;

  const HealthMetric(this.label, this.unit);
}

class HealthService {
  final Health _health = Health();
  bool _isConfigured = false;

  Future<bool> _ensureConfigured() async {
    if (kIsWeb) {
      return false;
    }

    if (_isConfigured) {
      return true;
    }

    try {
      await _health.configure();
      _isConfigured = true;
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error configuring health service: $e');
      }
      return false;
    }
  }

  List<HealthDataType> _typesForMetric(HealthMetric metric) {
    return switch (metric) {
      HealthMetric.steps => [HealthDataType.STEPS],
      HealthMetric.sleepMinutes => [HealthDataType.SLEEP_ASLEEP],
      HealthMetric.workoutMinutes => [HealthDataType.WORKOUT],
      HealthMetric.waterLiters => [HealthDataType.WATER],
      HealthMetric.mindfulMinutes => [HealthDataType.MINDFULNESS],
    };
  }

  Future<bool> requestPermissions({
    HealthMetric metric = HealthMetric.steps,
  }) async {
    if (!await _ensureConfigured()) {
      return false;
    }

    final types = _typesForMetric(metric);
    final permissions = types.map((_) => HealthDataAccess.READ).toList();
    try {
      bool? hasPermissions = await _health.hasPermissions(
        types,
        permissions: permissions,
      );
      if (hasPermissions != true) {
        return await _health.requestAuthorization(
          types,
          permissions: permissions,
        );
      }
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('Error requesting health permissions: $e');
      return false;
    }
  }

  Future<int> fetchStepsForToday() async {
    if (!await _ensureConfigured()) {
      return 0;
    }

    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day);
    try {
      int? steps = await _health.getTotalStepsInInterval(midnight, now);
      return steps ?? 0;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error fetching steps from HealthKit/HealthConnect: $e');
      }
      return 0;
    }
  }

  /// Fetch a health metric value for today.
  /// Returns the aggregate value (e.g., total steps, total sleep minutes).
  Future<double> fetchMetricForToday(HealthMetric metric) async {
    if (metric == HealthMetric.steps) {
      return (await fetchStepsForToday()).toDouble();
    }

    if (!await _ensureConfigured()) {
      return 0;
    }

    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day);

    try {
      final types = _typesForMetric(metric);
      final data = await _health.getHealthDataFromTypes(
        types: types,
        startTime: midnight,
        endTime: now,
      );

      if (data.isEmpty) return 0;

      // Sum values — health data points are in native units
      double total = 0;
      for (final point in data) {
        final numValue = point.value;
        if (numValue is NumericHealthValue) {
          total += numValue.numericValue.toDouble();
        }
      }

      // Convert to the metric's display unit
      return switch (metric) {
        HealthMetric.sleepMinutes => total, // already in minutes
        HealthMetric.workoutMinutes => total, // already in minutes
        HealthMetric.waterLiters => total, // already in liters
        HealthMetric.mindfulMinutes => total, // already in minutes
        HealthMetric.steps => total,
      };
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error fetching $metric: $e');
      }
      return 0;
    }
  }

  /// Check if a health metric has met a target threshold.
  /// Useful for auto-completing health-backed habits.
  Future<bool> hasMetTarget(HealthMetric metric, double target) async {
    final value = await fetchMetricForToday(metric);
    return value >= target;
  }
}

