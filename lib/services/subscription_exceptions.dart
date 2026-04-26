class UpgradeRequiredException implements Exception {
  final String message;

  const UpgradeRequiredException(this.message);

  @override
  String toString() => message;
}

class SubscriptionUnavailableException implements Exception {
  final String message;

  const SubscriptionUnavailableException(this.message);

  @override
  String toString() => message;
}
