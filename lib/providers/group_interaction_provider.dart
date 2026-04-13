import 'package:flutter/foundation.dart';

class MemberActivitySheetProvider extends ChangeNotifier {
  DateTime _focusedDay;

  MemberActivitySheetProvider({DateTime? initialFocusedDay})
    : _focusedDay = initialFocusedDay ?? DateTime.now();

  DateTime get focusedDay => _focusedDay;

  void setFocusedDay(DateTime day) {
    if (_focusedDay.year == day.year &&
        _focusedDay.month == day.month &&
        _focusedDay.day == day.day) {
      return;
    }
    _focusedDay = day;
    notifyListeners();
  }
}

class GroupInviteSelectionProvider extends ChangeNotifier {
  final Set<String> _selected = <String>{};
  bool _isSending = false;

  Set<String> get selected => _selected;
  bool get isSending => _isSending;

  bool isSelected(String uid) => _selected.contains(uid);

  void toggle(String uid, bool checked) {
    if (_isSending) {
      return;
    }

    if (checked) {
      _selected.add(uid);
    } else {
      _selected.remove(uid);
    }
    notifyListeners();
  }

  void setSending(bool value) {
    if (_isSending == value) {
      return;
    }
    _isSending = value;
    notifyListeners();
  }
}

class GroupTaskEditorProvider extends ChangeNotifier {
  String _draft;
  bool _isSaving = false;
  bool _isQuantified;
  String _quantUnit;
  double _quantMax;

  GroupTaskEditorProvider({
    required String initialTask,
    required bool initialIsQuantified,
    required String initialQuantUnit,
    required double initialQuantMax,
  }) : _draft = initialTask,
       _isQuantified = initialIsQuantified,
       _quantUnit = initialQuantUnit,
       _quantMax = initialQuantMax;

  String get draft => _draft;
  bool get isSaving => _isSaving;
  bool get isQuantified => _isQuantified;
  String get quantUnit => _quantUnit;
  double get quantMax => _quantMax;
  double get quantSliderMin => _quantConfig(_quantUnit).min;
  double get quantSliderMax => _quantConfig(_quantUnit).max;
  double get quantSliderStep => _quantConfig(_quantUnit).step;
  int get quantSliderDivisions =>
      ((quantSliderMax - quantSliderMin) / quantSliderStep).round();
  int get quantDecimals => quantSliderStep < 1 ? 1 : 0;

  void setDraft(String value) {
    if (_draft == value) {
      return;
    }
    _draft = value;
    notifyListeners();
  }

  void setSaving(bool value) {
    if (_isSaving == value) {
      return;
    }
    _isSaving = value;
    notifyListeners();
  }

  void setIsQuantified(bool value) {
    if (_isQuantified == value) {
      return;
    }
    _isQuantified = value;
    notifyListeners();
  }

  void setQuantUnit(String value) {
    if (_quantUnit == value) {
      return;
    }
    _quantUnit = value;
    final config = _quantConfig(value);
    _quantMax = _quantMax.clamp(config.min, config.max).toDouble();
    notifyListeners();
  }

  void setQuantMax(double value) {
    final config = _quantConfig(_quantUnit);
    final normalized = value.clamp(config.min, config.max).toDouble();
    if (_quantMax == normalized) {
      return;
    }
    _quantMax = normalized;
    notifyListeners();
  }
}

class _QuantRangeConfig {
  final double min;
  final double max;
  final double step;

  const _QuantRangeConfig({
    required this.min,
    required this.max,
    required this.step,
  });
}

_QuantRangeConfig _quantConfig(String unit) {
  switch (unit) {
    case 'hours':
      return const _QuantRangeConfig(min: 0.5, max: 24, step: 0.5);
    case 'km':
      return const _QuantRangeConfig(min: 0.5, max: 50, step: 0.5);
    case 'reps':
      return const _QuantRangeConfig(min: 1, max: 500, step: 1);
    case 'pages':
      return const _QuantRangeConfig(min: 1, max: 300, step: 1);
    case 'steps':
      return const _QuantRangeConfig(min: 500, max: 50000, step: 500);
    default:
      return const _QuantRangeConfig(min: 1, max: 200, step: 1);
  }
}
