import 'package:flutter/foundation.dart';

enum CalendarScope { mine, team }

class CalendarProvider extends ChangeNotifier {
  DateTime _dateOnly(DateTime day) => DateTime(day.year, day.month, day.day);

  late final DateTime _today = _dateOnly(DateTime.now());

  late DateTime _focusedDay = _today;
  late DateTime? _selectedDay = _today;
  CalendarScope _scope = CalendarScope.mine;

  DateTime get focusedDay => _focusedDay;
  DateTime? get selectedDay => _selectedDay;
  CalendarScope get scope => _scope;

  void selectDay(DateTime selected, DateTime focused) {
    _selectedDay = _dateOnly(selected);
    _focusedDay = _dateOnly(focused);
    notifyListeners();
  }

  void goToToday() {
    final today = _dateOnly(DateTime.now());
    _selectedDay = today;
    _focusedDay = today;
    notifyListeners();
  }

  void setScope(CalendarScope newScope) {
    if (_scope != newScope) {
      _scope = newScope;
      notifyListeners();
    }
  }
}
