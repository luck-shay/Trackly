import 'package:flutter_test/flutter_test.dart';
import 'package:trackly/models/habit.dart';
import 'package:trackly/providers/quantified_log_provider.dart';

void main() {
  group('QuantifiedLogProvider', () {
    test('clamps the initial value into range', () {
      final provider = QuantifiedLogProvider(
        min: 0,
        max: 10,
        initialValue: 99,
      );

      expect(provider.value, 10);
    });

    test('snaps increments and decrements using the resolved step', () {
      final provider = QuantifiedLogProvider(
        min: 0,
        max: 10,
        initialValue: 5,
      );

      provider.increment();
      expect(provider.value, closeTo(5.1, 0.000001));

      provider.decrement();
      provider.decrement();
      expect(provider.value, closeTo(4.9, 0.000001));
    });
  });

  group('HabitChecklistItem', () {
    test('serializes and deserializes checklist items correctly', () {
      final item = HabitChecklistItem(
        id: 'step_1',
        title: '5-min warm-up',
        isCompleted: true,
      );

      final map = item.toMap();
      expect(map['id'], 'step_1');
      expect(map['title'], '5-min warm-up');
      expect(map['isCompleted'], true);

      final reconstructed = HabitChecklistItem.fromMap(map);
      expect(reconstructed.id, 'step_1');
      expect(reconstructed.title, '5-min warm-up');
      expect(reconstructed.isCompleted, true);
    });
  });
}
