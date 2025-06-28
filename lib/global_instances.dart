// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:opentelemetry/api.dart' as otel;
import 'package:opentelemetry/sdk.dart' as sdk;
import 'package:otel_poc/models/useraction.dart';
import 'package:otel_poc/models/usersession.dart';
import 'package:uuid/uuid.dart';

// Global instances
late otel.Tracer globalTracer;
late MetricsCollector metricsCollector;
late SessionTracker sessionTracker;

Future<void> initializeOpenTelemetry() async {
  // Create resource with app and device information
  final resource = sdk.Resource([
    otel.Attribute.fromString('service.name', 'ecommerce-poc'),
    otel.Attribute.fromString('service.version', '1.0.0'),
    otel.Attribute.fromString('deployment.environment', 'development'),
    otel.Attribute.fromString('device.platform',
        (kIsWeb) ? "Running on Web" : Platform.operatingSystem),
    otel.Attribute.fromString('app.name', 'E-Commerce POC'),
  ]);

  // Setup tracer provider with console exporter
  final tracerProvider = sdk.TracerProviderBase(
    resource: resource,
    processors: [
      sdk.SimpleSpanProcessor(sdk.ConsoleExporter()), // Console output
    ],
  );

  // Register global tracer provider
  otel.registerGlobalTracerProvider(tracerProvider);

  // Get tracer instance
  globalTracer = otel.globalTracerProvider.getTracer('ecommerce-poc');

  // Initialize metrics collector
  metricsCollector = MetricsCollector();

  print('🚀 OpenTelemetry initialized successfully!');
}

class SessionTracker {
  static final SessionTracker _instance = SessionTracker._internal();
  factory SessionTracker() => _instance;
  SessionTracker._internal();

  final List<UserSession> _sessions = [];
  UserSession? _currentSession;
  Timer? _inactivityTimer;

  // Session timeout after 5 minutes of inactivity
  static const _sessionTimeout = Duration(minutes: 5);

  List<UserSession> get sessions => List.unmodifiable(_sessions);
  UserSession? get currentSession => _currentSession;

  void startSession(String userId, String userName) {
    // End previous session if exists
    if (_currentSession != null) {
      endCurrentSession();
    }

    _currentSession = UserSession(
      sessionId: Uuid().v4(),
      userId: userId,
      userName: userName,
      startTime: DateTime.now(),
    );
    _sessions.add(_currentSession!);

    trackAction('session_started');
    _resetInactivityTimer();

    print('📊 Session started: ${_currentSession!.sessionId} for $userName');
  }

  void endCurrentSession() {
    if (_currentSession != null) {
      _currentSession!.endTime = DateTime.now();
      _currentSession!.isActive = false;
      trackAction('session_ended');

      print(
          '📊 Session ended: ${_currentSession!.sessionId} - Duration: ${_currentSession!.duration}');
      print('📊 User flow: ${_currentSession!.formattedFlow}');

      _currentSession = null;
      _cancelInactivityTimer();
    }
  }

  void trackAction(String action, {Map<String, dynamic>? metadata}) {
    if (_currentSession != null) {
      final userAction = UserAction(
        action: action,
        timestamp: DateTime.now(),
        metadata: metadata,
        userId: _currentSession!.userId,
        userName: _currentSession!.userName,
      );

      _currentSession!.actions.add(userAction);
      _resetInactivityTimer();

      // Also send to OpenTelemetry
      final span = globalTracer.startSpan('user_action');
      span.setAttributes([
        otel.Attribute.fromString('action.type', action),
        otel.Attribute.fromString('session.id', _currentSession!.sessionId),
        otel.Attribute.fromString('user.id', _currentSession!.userId),
        otel.Attribute.fromString('user.name', _currentSession!.userName),
      ]);

      if (metadata != null) {
        metadata.forEach((key, value) {
          if (value is String) {
            span.setAttribute(otel.Attribute.fromString('action.$key', value));
          } else if (value is int) {
            span.setAttribute(otel.Attribute.fromInt('action.$key', value));
          } else if (value is double) {
            span.setAttribute(otel.Attribute.fromDouble('action.$key', value));
          }
        });
      }

      span.end();

      print('📊 Action tracked: $action ${metadata ?? ''}');
    }
  }

  void _resetInactivityTimer() {
    _cancelInactivityTimer();
    _inactivityTimer = Timer(_sessionTimeout, () {
      if (_currentSession != null) {
        print('📊 Session timeout due to inactivity');
        endCurrentSession();
      }
    });
  }

  void _cancelInactivityTimer() {
    _inactivityTimer?.cancel();
    _inactivityTimer = null;
  }

  Map<String, dynamic> getSessionAnalytics() {
    final totalSessions = _sessions.length;
    final activeSessions = _sessions.where((s) => s.isActive).length;
    final completedSessions = totalSessions - activeSessions;

    // Calculate average session duration
    final completedSessionDurations = _sessions
        .where((s) => !s.isActive && s.endTime != null)
        .map((s) => s.endTime!.difference(s.startTime).inSeconds.toDouble())
        .toList();

    final avgDuration = completedSessionDurations.isEmpty
        ? 0.0
        : completedSessionDurations.reduce((a, b) => a + b) /
            completedSessionDurations.length;

    // Most common actions
    final actionCounts = <String, int>{};
    for (final session in _sessions) {
      for (final action in session.actions) {
        actionCounts[action.action] = (actionCounts[action.action] ?? 0) + 1;
      }
    }

    final sortedActions = actionCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return {
      'total_sessions': totalSessions,
      'active_sessions': activeSessions,
      'completed_sessions': completedSessions,
      'avg_session_duration_seconds': avgDuration,
      'most_common_actions':
          sortedActions.take(5).map((e) => '${e.key}: ${e.value}').toList(),
    };
  }
}

class MetricsCollector {
  final Map<String, int> _counters = {};
  final Map<String, double> _gauges = {};
  final List<double> _responseTimesMs = [];

  void incrementCounter(String name) {
    _counters[name] = (_counters[name] ?? 0) + 1;
    print('📊 Counter $name: ${_counters[name]}');
  }

  void setGauge(String name, double value) {
    _gauges[name] = value;
    print('📈 Gauge $name: $value');
  }

  void recordResponseTime(double milliseconds) {
    _responseTimesMs.add(milliseconds);
    print('⏱️ Response time: ${milliseconds}ms');
  }

  double getConversionRate() {
    final viewed = _counters['products_viewed'] ?? 0;
    final orders = _counters['orders_completed'] ?? 0;
    return viewed > 0 ? (orders.toDouble() / viewed.toDouble()) * 100 : 0.0;
  }

  double getCartAbandonmentRate() {
    final cartUpdates = _counters['cart_updated'] ?? 0;
    final checkouts = _counters['checkout_initiated'] ?? 0;
    return cartUpdates > 0
        ? ((cartUpdates - checkouts).toDouble() / cartUpdates.toDouble()) * 100
        : 0.0;
  }

  double getAverageResponseTime() {
    return _responseTimesMs.isEmpty
        ? 0.0
        : _responseTimesMs.reduce((a, b) => a + b) /
            _responseTimesMs.length.toDouble();
  }

  Map<String, dynamic> getAllMetrics() {
    return {
      'counters': _counters,
      'gauges': _gauges,
      'conversion_rate': getConversionRate(),
      'cart_abandonment_rate': getCartAbandonmentRate(),
      'avg_response_time_ms': getAverageResponseTime(),
    };
  }
}
