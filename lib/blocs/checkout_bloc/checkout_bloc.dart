// ignore_for_file: avoid_print

import 'dart:math';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:otel_poc/global_instances.dart';
import 'package:opentelemetry/api.dart' as otel;
import 'package:otel_poc/models/cartitem.dart';
import 'package:otel_poc/models/order.dart';
import 'package:uuid/uuid.dart';

abstract class CheckoutEvent {}

class InitiateCheckout extends CheckoutEvent {}

class ProcessPayment extends CheckoutEvent {
  final List<CartItem> items;
  final double total;
  ProcessPayment(this.items, this.total);
}

abstract class CheckoutState {}

class CheckoutInitial extends CheckoutState {}

class CheckoutLoading extends CheckoutState {}

class CheckoutSuccess extends CheckoutState {
  final Order order;
  CheckoutSuccess(this.order);
}

class CheckoutFailure extends CheckoutState {
  final String error;
  CheckoutFailure(this.error);
}

class CheckoutBloc extends Bloc<CheckoutEvent, CheckoutState> {
  CheckoutBloc() : super(CheckoutInitial()) {
    on<InitiateCheckout>(_onInitiateCheckout);
    on<ProcessPayment>(_onProcessPayment);
  }

  Future<void> _onInitiateCheckout(
      InitiateCheckout event, Emitter<CheckoutState> emit) async {
    final span = globalTracer.startSpan('checkout_initiated');

    try {
      // Track checkout initiation
      sessionTracker.trackAction('checkout_initiated');

      span.addEvent('checkout_process_started');
      metricsCollector.incrementCounter('checkout_initiated');

      // Don't emit loading here - wait for actual payment processing
      emit(CheckoutInitial());
    } finally {
      span.end();
    }
  }

  Future<void> _onProcessPayment(
      ProcessPayment event, Emitter<CheckoutState> emit) async {
    final parentSpan = globalTracer.startSpan('checkout_process');

    try {
      // IMPORTANT: Emit loading state immediately
      emit(CheckoutLoading());

      // Track payment attempt
      sessionTracker.trackAction('payment_attempted', metadata: {
        'total_amount': event.total,
        'item_count': event.items.length,
      });

      parentSpan.setAttributes([
        otel.Attribute.fromInt('order.item_count', event.items.length),
        otel.Attribute.fromDouble('order.total_amount', event.total),
      ]);

      // Payment processing span
      final paymentSpan = globalTracer.startSpan('payment_processing');

      try {
        paymentSpan.addEvent('payment_started');

        // Simulate payment processing delay
        await Future.delayed(
            Duration(milliseconds: Random().nextInt(2000) + 1000));

        // Simulate 70% success rate
        final paymentSuccess = Random().nextDouble() < 0.7;

        if (paymentSuccess) {
          paymentSpan.addEvent('payment_success');
          metricsCollector.incrementCounter('payments_successful');

          // Order completion span
          final orderSpan = globalTracer.startSpan('order_completion');

          try {
            final order = Order(
              id: Uuid().v4(),
              items: List.from(event.items),
              total: event.total,
              timestamp: DateTime.now(),
            );

            // Track successful order
            sessionTracker.trackAction('order_completed', metadata: {
              'order_id': order.id,
              'order_total': order.total,
              'item_count': order.items.length,
            });

            orderSpan.setAttributes([
              otel.Attribute.fromString('order.id', order.id),
              otel.Attribute.fromString(
                  'order.timestamp', order.timestamp.toIso8601String()),
            ]);

            orderSpan.addEvent('order_placed');
            metricsCollector.incrementCounter('orders_completed');

            // Emit success state
            emit(CheckoutSuccess(order));
            print('✅ Checkout Success - Order ID: ${order.id}');
          } finally {
            orderSpan.end();
          }
        } else {
          // Payment failure
          final error = 'Payment failed: Card declined';

          // Track payment failure
          sessionTracker.trackAction('payment_failed', metadata: {
            'reason': 'card_declined',
            'total_amount': event.total,
          });

          paymentSpan.recordException(Exception(error));
          paymentSpan.setStatus(otel.StatusCode.error, error);

          paymentSpan.addEvent('payment_failed', attributes: [
            otel.Attribute.fromString('failure.reason', 'card_declined'),
          ]);

          metricsCollector.incrementCounter('payments_failed');

          // Emit failure state
          emit(CheckoutFailure(error));
          print('❌ Checkout Failed: $error');
        }
      } finally {
        paymentSpan.end();
      }
    } catch (e) {
      parentSpan.recordException(e);
      parentSpan.setStatus(otel.StatusCode.error, e.toString());

      // Emit failure state for any exceptions
      emit(CheckoutFailure('Checkout failed: $e'));
      print('❌ Checkout Exception: $e');
    } finally {
      parentSpan.end();
    }
  }
}

// UI Screens
