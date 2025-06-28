import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:opentelemetry/api.dart' as otel;
import 'package:otel_poc/global_instances.dart';
import 'package:otel_poc/models/cartitem.dart';
import 'package:otel_poc/models/product.dart';

// Cart BLoC
abstract class CartEvent {}

class AddToCart extends CartEvent {
  final Product product;
  AddToCart(this.product);
}

class RemoveFromCart extends CartEvent {
  final String productId;
  RemoveFromCart(this.productId);
}

class UpdateQuantity extends CartEvent {
  final String productId;
  final int quantity;
  UpdateQuantity(this.productId, this.quantity);
}

class ClearCart extends CartEvent {}

abstract class CartState {}

class CartInitial extends CartState {}

class CartUpdated extends CartState {
  final List<CartItem> items;
  final double total;
  CartUpdated(this.items, this.total);
}

class CartBloc extends Bloc<CartEvent, CartState> {
  final List<CartItem> _items = [];
  Timer? _abandonmentTimer;

  CartBloc() : super(CartInitial()) {
    on<AddToCart>(_onAddToCart);
    on<RemoveFromCart>(_onRemoveFromCart);
    on<UpdateQuantity>(_onUpdateQuantity);
    on<ClearCart>(_onClearCart);
  }

  Future<void> _onAddToCart(AddToCart event, Emitter<CartState> emit) async {
    final span = globalTracer.startSpan('add_to_cart');

    try {
      // Track add to cart action
      sessionTracker.trackAction('add_to_cart', metadata: {
        'product_id': event.product.id,
        'product_name': event.product.name,
        'product_price': event.product.price,
      });

      span.setAttributes([
        otel.Attribute.fromString('product.id', event.product.id),
        otel.Attribute.fromString('product.name', event.product.name),
        otel.Attribute.fromDouble('product.price', event.product.price),
      ]);

      // Check if item already exists
      final existingIndex =
          _items.indexWhere((item) => item.product.id == event.product.id);

      if (existingIndex >= 0) {
        _items[existingIndex].quantity++;
        span.addEvent('quantity_updated');
      } else {
        _items.add(CartItem(product: event.product));
        span.addEvent('new_item_added');
      }

      final total = _calculateTotal();

      span.setAttributes([
        otel.Attribute.fromInt('cart.item_count', _items.length),
        otel.Attribute.fromDouble('cart.total_value', total),
      ]);

      // Record metrics
      metricsCollector.incrementCounter('cart_items_added');
      metricsCollector.setGauge('cart_value', total);
      metricsCollector.incrementCounter('cart_updated');

      span.addEvent('cart_updated');

      // Start abandonment timer (5 minutes)
      _startAbandonmentTimer();

      emit(CartUpdated(_items, total));
    } finally {
      span.end();
    }
  }

  Future<void> _onRemoveFromCart(
      RemoveFromCart event, Emitter<CartState> emit) async {
    final span = globalTracer.startSpan('remove_from_cart');

    try {
      final removedItem =
          _items.firstWhere((item) => item.product.id == event.productId);

      // Track remove from cart
      sessionTracker.trackAction('remove_from_cart', metadata: {
        'product_id': removedItem.product.id,
        'product_name': removedItem.product.name,
      });

      _items.removeWhere((item) => item.product.id == event.productId);
      final total = _calculateTotal();

      span.setAttributes([
        otel.Attribute.fromString('product.id', event.productId),
        otel.Attribute.fromInt('cart.remaining_items', _items.length),
        otel.Attribute.fromDouble('cart.total_value', total),
      ]);

      metricsCollector.incrementCounter('cart_items_removed');
      metricsCollector.setGauge('cart_value', total);

      span.addEvent('item_removed_from_cart');
      emit(CartUpdated(_items, total));
    } finally {
      span.end();
    }
  }

  Future<void> _onUpdateQuantity(
      UpdateQuantity event, Emitter<CartState> emit) async {
    final span = globalTracer.startSpan('update_cart_quantity');

    try {
      final item =
          _items.firstWhere((item) => item.product.id == event.productId);
      final oldQuantity = item.quantity;
      item.quantity = event.quantity;

      // Track quantity update
      sessionTracker.trackAction('cart_quantity_updated', metadata: {
        'product_id': item.product.id,
        'product_name': item.product.name,
        'old_quantity': oldQuantity,
        'new_quantity': event.quantity,
      });

      final total = _calculateTotal();

      span.setAttributes([
        otel.Attribute.fromString('product.id', event.productId),
        otel.Attribute.fromInt('quantity.old', oldQuantity),
        otel.Attribute.fromInt('quantity.new', event.quantity),
        otel.Attribute.fromDouble('cart.total_value', total),
      ]);

      span.addEvent('quantity_updated');
      emit(CartUpdated(_items, total));
    } finally {
      span.end();
    }
  }

  Future<void> _onClearCart(ClearCart event, Emitter<CartState> emit) async {
    final span = globalTracer.startSpan('clear_cart');

    try {
      final itemCount = _items.length;
      _items.clear();
      _abandonmentTimer?.cancel();

      // Track cart clear
      sessionTracker.trackAction('cart_cleared', metadata: {
        'items_cleared': itemCount,
      });

      span.setAttributes([
        otel.Attribute.fromInt('items.cleared', itemCount),
      ]);

      span.addEvent('cart_cleared');
      emit(CartUpdated(_items, 0.0));
    } finally {
      span.end();
    }
  }

  double _calculateTotal() {
    return _items.fold(
        0.0, (total, item) => total + (item.product.price * item.quantity));
  }

  void _startAbandonmentTimer() {
    _abandonmentTimer?.cancel();
    _abandonmentTimer = Timer(Duration(minutes: 5), () {
      final span = globalTracer.startSpan('cart_abandoned');

      // Track cart abandonment
      sessionTracker.trackAction('cart_abandoned', metadata: {
        'abandoned_items': _items.length,
        'abandoned_value': _calculateTotal(),
      });

      span.setAttributes([
        otel.Attribute.fromInt('cart.abandoned_items', _items.length),
        otel.Attribute.fromDouble('cart.abandoned_value', _calculateTotal()),
      ]);

      span.addEvent('cart_abandoned');
      metricsCollector.incrementCounter('cart_abandoned');

      span.end();
    });
  }
}
