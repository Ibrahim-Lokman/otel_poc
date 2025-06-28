import 'dart:math';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:opentelemetry/api.dart' as otel;
import 'package:otel_poc/global_instances.dart';
import 'package:otel_poc/models/product.dart';

// Product BLoC
abstract class ProductEvent {}

class LoadProducts extends ProductEvent {}

class ViewProduct extends ProductEvent {
  final Product product;
  ViewProduct(this.product);
}

abstract class ProductState {}

class ProductInitial extends ProductState {}

class ProductLoading extends ProductState {}

class ProductLoaded extends ProductState {
  final List<Product> products;
  ProductLoaded(this.products);
}

class ProductError extends ProductState {
  final String error;
  ProductError(this.error);
}

class ProductBloc extends Bloc<ProductEvent, ProductState> {
  static final List<Product> _mockProducts = [
    Product(
        id: '1',
        name: 'iPhone 15',
        price: 999.99,
        category: 'Electronics',
        imageUrl: '📱'),
    Product(
        id: '2',
        name: 'MacBook Pro',
        price: 1999.99,
        category: 'Electronics',
        imageUrl: '💻'),
    Product(
        id: '3',
        name: 'Nike Shoes',
        price: 129.99,
        category: 'Clothing',
        imageUrl: '👟'),
    Product(
        id: '4',
        name: 'Coffee Mug',
        price: 19.99,
        category: 'Home',
        imageUrl: '☕'),
    Product(
        id: '5',
        name: 'Wireless Earbuds',
        price: 199.99,
        category: 'Electronics',
        imageUrl: '🎧'),
    Product(
        id: '6',
        name: 'T-Shirt',
        price: 29.99,
        category: 'Clothing',
        imageUrl: '👕'),
    Product(
        id: '7',
        name: 'Smart Watch',
        price: 299.99,
        category: 'Electronics',
        imageUrl: '⌚'),
    Product(
        id: '8',
        name: 'Book: Flutter Guide',
        price: 39.99,
        category: 'Books',
        imageUrl: '📚'),
  ];

  ProductBloc() : super(ProductInitial()) {
    on<LoadProducts>(_onLoadProducts);
    on<ViewProduct>(_onViewProduct);
  }

  Future<void> _onLoadProducts(
      LoadProducts event, Emitter<ProductState> emit) async {
    final span = globalTracer.startSpan('fetch_products');
    final stopwatch = Stopwatch()..start();

    try {
      emit(ProductLoading());

      // Track product catalog view
      sessionTracker.trackAction('product_catalog_viewed');

      span.setAttributes([
        otel.Attribute.fromInt('products.request_count', _mockProducts.length),
      ]);

      // Simulate API call with potential failure
      await Future.delayed(
          Duration(milliseconds: Random().nextInt(1000) + 500));

      // Simulate 10% failure rate
      if (Random().nextDouble() < 0.1) {
        throw Exception('Network error: Failed to load products');
      }

      stopwatch.stop();
      final responseTimeMs = stopwatch.elapsedMilliseconds.toDouble();

      // Record metrics
      metricsCollector.recordResponseTime(responseTimeMs);
      metricsCollector.incrementCounter('products_loaded');
      metricsCollector.setGauge(
          'products_available', _mockProducts.length.toDouble());

      span.setAttributes([
        otel.Attribute.fromInt('products.loaded_count', _mockProducts.length),
        otel.Attribute.fromDouble('api.response_time_ms', responseTimeMs),
      ]);

      span.addEvent('products_loaded_successfully');
      emit(ProductLoaded(_mockProducts));
    } catch (e) {
      stopwatch.stop();
      span.recordException(e);

      span.setStatus(otel.StatusCode.error, e.toString());

      metricsCollector.incrementCounter('product_load_errors');

      sessionTracker.trackAction('product_load_error', metadata: {
        'error': e.toString(),
      });

      emit(ProductError(e.toString()));
    } finally {
      span.end();
    }
  }

  Future<void> _onViewProduct(
      ViewProduct event, Emitter<ProductState> emit) async {
    final span = globalTracer.startSpan('product_viewed');

    try {
      // Track product view
      sessionTracker.trackAction('product_viewed', metadata: {
        'product_id': event.product.id,
        'product_name': event.product.name,
        'product_price': event.product.price,
        'product_category': event.product.category,
      });

      span.setAttributes([
        otel.Attribute.fromString('product.id', event.product.id),
        otel.Attribute.fromString('product.name', event.product.name),
        otel.Attribute.fromString('product.category', event.product.category),
        otel.Attribute.fromDouble('product.price', event.product.price),
      ]);

      span.addEvent('product_viewed');
      metricsCollector.incrementCounter('products_viewed');
    } finally {
      span.end();
    }
  }
}
