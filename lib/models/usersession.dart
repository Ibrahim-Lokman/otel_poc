import 'package:otel_poc/models/useraction.dart';

class UserSession {
  final String sessionId;
  final String userId;
  final String userName;
  final DateTime startTime;
  DateTime? endTime;
  final List<UserAction> actions;
  bool isActive;

  UserSession({
    required this.sessionId,
    required this.userId,
    required this.userName,
    required this.startTime,
    this.endTime,
    List<UserAction>? actions,
    this.isActive = true,
  }) : actions = actions ?? [];

  String get duration {
    final end = endTime ?? DateTime.now();
    final diff = end.difference(startTime);
    if (diff.inHours > 0) {
      return '${diff.inHours}h ${diff.inMinutes % 60}m';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes}m ${diff.inSeconds % 60}s';
    } else {
      return '${diff.inSeconds}s';
    }
  }

  String get formattedFlow {
    return actions.map((a) => a.action).join(' → ');
  }
}
