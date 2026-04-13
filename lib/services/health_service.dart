import 'package:health/health.dart';
import 'package:flutter/foundation.dart';

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

  Future<bool> requestPermissions() async {
    if (!await _ensureConfigured()) {
      return false;
    }

    final types = [HealthDataType.STEPS];
    final permissions = [HealthDataAccess.READ];
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
}
