class UserAction {
  final String action;
  final DateTime timestamp;
  final Map<String, dynamic>? metadata;
  final String? userId;
  final String? userName;

  UserAction({
    required this.action,
    required this.timestamp,
    this.metadata,
    this.userId,
    this.userName,
  });
}
