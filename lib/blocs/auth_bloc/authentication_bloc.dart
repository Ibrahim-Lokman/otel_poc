// ignore_for_file: avoid_print

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:opentelemetry/api.dart' as otel;
import 'package:otel_poc/global_instances.dart';
import 'package:otel_poc/models/user.dart';
import 'package:uuid/uuid.dart';

// Authentication BLoC
abstract class AuthEvent {}

class LoginRequested extends AuthEvent {
  final String email;
  final String password;
  LoginRequested(this.email, this.password);
}

class LogoutRequested extends AuthEvent {}

abstract class AuthState {}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

class AuthSuccess extends AuthState {
  final User user;
  AuthSuccess(this.user);
}

class AuthFailure extends AuthState {
  final String error;
  AuthFailure(this.error);
}

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  // Define valid users
  static final Map<String, Map<String, String>> validUsers = {
    'test@test.com': {
      'password': '123456',
      'name': 'Test User',
      'demographics': 'age:25-34,region:BD'
    },
    'john@example.com': {
      'password': 'password123',
      'name': 'John Doe',
      'demographics': 'age:35-44,region:US'
    },
    'sarah@example.com': {
      'password': 'sarah2024',
      'name': 'Sarah Smith',
      'demographics': 'age:18-24,region:UK'
    },
    'admin@store.com': {
      'password': 'admin123',
      'name': 'Admin User',
      'demographics': 'age:45-54,region:BD'
    },
  };

  AuthBloc() : super(AuthInitial()) {
    on<LoginRequested>(_onLoginRequested);
    on<LogoutRequested>(_onLogoutRequested);
  }

  Future<void> _onLoginRequested(
      LoginRequested event, Emitter<AuthState> emit) async {
    final span = globalTracer.startSpan('user_authentication');

    try {
      emit(AuthLoading());

      // Track login attempt
      sessionTracker.trackAction('login_attempt', metadata: {
        'email': event.email,
      });

      // Add span attributes
      span.setAttributes([
        otel.Attribute.fromString('user.email', event.email),
        otel.Attribute.fromString('auth.method', 'multi-user'),
      ]);

      // Record login attempt event
      span.addEvent('login_attempt');
      metricsCollector.incrementCounter('login_attempts');

      // Simulate API call delay
      await Future.delayed(Duration(milliseconds: 500));

      // Check against multiple users
      if (validUsers.containsKey(event.email) &&
          validUsers[event.email]!['password'] == event.password) {
        final userData = validUsers[event.email]!;
        final user = User(
          id: Uuid().v4(),
          email: event.email,
          name: userData['name']!,
          demographics: userData['demographics']!,
        );

        // Start new session
        sessionTracker.startSession(user.id, user.name);

        // Track successful login
        sessionTracker.trackAction('login_success', metadata: {
          'user_name': user.name,
          'user_email': user.email,
        });

        // Add user attributes to span
        span.setAttributes([
          otel.Attribute.fromString('user.id', user.id),
          otel.Attribute.fromString('user.name', user.name),
          otel.Attribute.fromString('user.demographics', user.demographics),
        ]);

        span.addEvent('login_success');
        metricsCollector.incrementCounter('login_success');

        emit(AuthSuccess(user));
        print('✅ Login Success: ${user.name} (${user.email})');
      } else {
        sessionTracker.trackAction('login_failed', metadata: {
          'email': event.email,
          'reason': 'invalid_credentials',
        });

        span.addEvent('login_failure', attributes: [
          otel.Attribute.fromString('failure.reason', 'invalid_credentials'),
        ]);
        metricsCollector.incrementCounter('login_failures');

        span.setStatus(otel.StatusCode.error, 'Invalid credentials');
        emit(AuthFailure('Invalid email or password'));
        print('❌ Login Failed: Invalid credentials for ${event.email}');
      }
    } catch (e) {
      span.recordException(e);
      span.setStatus(otel.StatusCode.error, e.toString());
      emit(AuthFailure('Login failed: $e'));
      print('❌ Login Exception: $e');
    } finally {
      span.end();
    }
  }

  Future<void> _onLogoutRequested(
      LogoutRequested event, Emitter<AuthState> emit) async {
    final span = globalTracer.startSpan('user_logout');

    try {
      span.addEvent('logout_initiated');

      // Track logout
      sessionTracker.trackAction('logout');

      // End session
      sessionTracker.endCurrentSession();

      await Future.delayed(Duration(milliseconds: 200));

      metricsCollector.incrementCounter('logout_success');
      span.addEvent('logout_success');

      emit(AuthInitial());
      print('✅ Logout Success');
    } finally {
      span.end();
    }
  }
}
