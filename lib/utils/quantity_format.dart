String formatQuantity(num value, {int maxDecimals = 1}) {
  final number = value.toDouble();
  if (!number.isFinite) {
    return value.toString();
  }

  final rounded = number.roundToDouble();
  if ((number - rounded).abs() < 0.000000001) {
    return rounded.toStringAsFixed(0);
  }

  final safeMaxDecimals = maxDecimals < 0
      ? 0
      : (maxDecimals > 10 ? 10 : maxDecimals);
  final fixed = number.toStringAsFixed(safeMaxDecimals);

  if (!fixed.contains('.')) {
    return fixed;
  }

  return fixed
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '');
}
