import 'package:flutter/foundation.dart';

class QuantifiedLogProvider extends ChangeNotifier {
  final double min;
  final double max;
  final double step;

  double _value;

  QuantifiedLogProvider({
    required this.min,
    required this.max,
    required double initialValue,
  }) : step = _resolveStep(min, max),
       _value = initialValue.clamp(min, max).toDouble();

  double get value => _value;
  int get decimalPlaces => step < 1 ? 1 : 0;
  String get formattedValue => _value.toStringAsFixed(decimalPlaces);

  int get divisions {
    final range = (max - min).abs();
    return (range / step).round().clamp(1, 2000);
  }

  void setValue(double next) {
    final snapped = _snap(next);
    if (_value == snapped) {
      return;
    }
    _value = snapped;
    notifyListeners();
  }

  void increment() => setValue(_value + step);

  void decrement() => setValue(_value - step);

  double _snap(double raw) {
    final clamped = raw.clamp(min, max).toDouble();
    final snapped = ((clamped - min) / step).round() * step + min;
    return snapped.clamp(min, max).toDouble();
  }

  static double _resolveStep(double min, double max) {
    final range = (max - min).abs();
    if (range >= 10000) {
      return 500;
    }
    if (range >= 1000) {
      return 50;
    }
    if (range >= 250) {
      return 5;
    }
    if (range <= 20) {
      return 0.1;
    }
    if (range <= 100) {
      return 0.5;
    }
    return 1;
  }
}
