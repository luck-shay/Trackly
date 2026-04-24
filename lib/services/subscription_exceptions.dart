class UpgradeRequiredException implements Exception {
  final String message;

  const UpgradeRequiredException(this.message);

  @override
  String toString() => message;
}
