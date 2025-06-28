import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:opentelemetry/api.dart' as otel;
import 'package:opentelemetry/sdk.dart' as sdk;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

// Global OpenTelemetry instances
late otel.Tracer globalTracer;
late MetricsCollector metricsCollector;
void kdebugPrint(String msg) {
  if (kDebugMode) {
    print(msg);
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize OpenTelemetry
  await initializeOpenTelemetry();

  runApp(MyApp());
}

Future<void> initializeOpenTelemetry() async {
  // Create resource with app and device information
  final resource = sdk.Resource([
    otel.Attribute.fromString('service.name', 'ecommerce-poc'),
    otel.Attribute.fromString('service.version', '1.0.0'),
    otel.Attribute.fromString('deployment.environment', 'development'),
    otel.Attribute.fromString('device.platform', Platform.operatingSystem),
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

  kdebugPrint('🚀 OpenTelemetry initialized successfully!');
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => AuthBloc()),
        BlocProvider(create: (_) => ProductBloc()),
        BlocProvider(create: (_) => CartBloc()),
        BlocProvider(create: (_) => CheckoutBloc()),
      ],
      child: MaterialApp(
        title: 'E-Commerce OpenTelemetry POC',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          useMaterial3: true,
        ),
        home: AuthWrapper(),
        routes: {
          '/products': (context) => ProductListScreen(),
          '/cart': (context) => CartScreen(),
          '/checkout': (context) => CheckoutScreen(),
          '/telemetry': (context) => TelemetryDebugScreen(),
        },
      ),
    );
  }
}

// Models
class User {
  final String id;
  final String email;
  final String name;
  final String demographics;

  User({
    required this.id,
    required this.email,
    required this.name,
    this.demographics = 'unknown',
  });
}

class Product {
  final String id;
  final String name;
  final double price;
  final String category;
  final String imageUrl;

  Product({
    required this.id,
    required this.name,
    required this.price,
    required this.category,
    required this.imageUrl,
  });
}

class CartItem {
  final Product product;
  int quantity;

  CartItem({required this.product, this.quantity = 1});
}

class Order {
  final String id;
  final List<CartItem> items;
  final double total;
  final DateTime timestamp;

  Order({
    required this.id,
    required this.items,
    required this.total,
    required this.timestamp,
  });
}

// OpenTelemetry Metrics Collector
class MetricsCollector {
  final Map<String, int> _counters = {};
  final Map<String, double> _gauges = {};
  final List<double> _responseTimesMs = [];

  void incrementCounter(String name) {
    _counters[name] = (_counters[name] ?? 0) + 1;
    kdebugPrint('📊 Counter $name: ${_counters[name]}');
  }

  void setGauge(String name, double value) {
    _gauges[name] = value;
    kdebugPrint('📈 Gauge $name: $value');
  }

  void recordResponseTime(double milliseconds) {
    _responseTimesMs.add(milliseconds);
    kdebugPrint('⏱️ Response time: ${milliseconds}ms');
  }

  double getConversionRate() {
    final viewed = _counters['products_viewed'] ?? 0;
    final orders = _counters['orders_completed'] ?? 0;
    return viewed > 0 ? (orders / viewed) * 100 : 0.0;
  }

  double getCartAbandonmentRate() {
    final cartUpdates = _counters['cart_updated'] ?? 0;
    final checkouts = _counters['checkout_initiated'] ?? 0;
    return cartUpdates > 0
        ? ((cartUpdates - checkouts) / cartUpdates) * 100
        : 0.0;
  }

  double getAverageResponseTime() {
    return _responseTimesMs.isEmpty
        ? 0.0
        : _responseTimesMs.reduce((a, b) => a + b) / _responseTimesMs.length;
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

        // Add user attributes to span
        span.setAttributes([
          otel.Attribute.fromString('user.id', user.id),
          otel.Attribute.fromString('user.name', user.name),
          otel.Attribute.fromString('user.demographics', user.demographics),
        ]);

        span.addEvent('login_success');
        metricsCollector.incrementCounter('login_success');

        emit(AuthSuccess(user));
        kdebugPrint('✅ Login Success: ${user.name} (${user.email})');
      } else {
        span.addEvent('login_failure', attributes: [
          otel.Attribute.fromString('failure.reason', 'invalid_credentials'),
        ]);
        metricsCollector.incrementCounter('login_failures');

        span.setStatus(otel.StatusCode.error, 'Invalid credentials');
        emit(AuthFailure('Invalid email or password'));
        kdebugPrint('❌ Login Failed: Invalid credentials for ${event.email}');
      }
    } catch (e) {
      span.recordException(e);
      span.setStatus(otel.StatusCode.error, e.toString());
      emit(AuthFailure('Login failed: $e'));
      kdebugPrint('❌ Login Exception: $e');
    } finally {
      span.end();
    }
  }

  Future<void> _onLogoutRequested(
      LogoutRequested event, Emitter<AuthState> emit) async {
    final span = globalTracer.startSpan('user_logout');

    try {
      span.addEvent('logout_initiated');
      await Future.delayed(Duration(milliseconds: 200));

      metricsCollector.incrementCounter('logout_success');
      span.addEvent('logout_success');

      emit(AuthInitial());
      kdebugPrint('✅ Logout Success');
    } finally {
      span.end();
    }
  }
}

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
      emit(ProductError(e.toString()));
    } finally {
      span.end();
    }
  }

  Future<void> _onViewProduct(
      ViewProduct event, Emitter<ProductState> emit) async {
    final span = globalTracer.startSpan('product_viewed');

    try {
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
  List<CartItem> _items = [];
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
      // Propagate context from any existing span
      final currentContext = otel.Context.current;
      final parentSpan = otel.spanFromContext(currentContext);
      if (parentSpan != null) {
        span.setAttributes([
          otel.Attribute.fromString('parent.operation', 'product_interaction'),
        ]);
      }

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

// Checkout BLoC
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

// Fixed CheckoutBloc with proper state emissions
class CheckoutBloc extends Bloc<CheckoutEvent, CheckoutState> {
  CheckoutBloc() : super(CheckoutInitial()) {
    on<InitiateCheckout>(_onInitiateCheckout);
    on<ProcessPayment>(_onProcessPayment);
  }

  Future<void> _onInitiateCheckout(
      InitiateCheckout event, Emitter<CheckoutState> emit) async {
    final span = globalTracer.startSpan('checkout_initiated');

    try {
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

            orderSpan.setAttributes([
              otel.Attribute.fromString('order.id', order.id),
              otel.Attribute.fromString(
                  'order.timestamp', order.timestamp.toIso8601String()),
            ]);

            orderSpan.addEvent('order_placed');
            metricsCollector.incrementCounter('orders_completed');

            // Emit success state
            emit(CheckoutSuccess(order));
            kdebugPrint('✅ Checkout Success - Order ID: ${order.id}');
          } finally {
            orderSpan.end();
          }
        } else {
          // Payment failure
          final error = 'Payment failed: Card declined';
          paymentSpan.recordException(Exception(error));
          paymentSpan.setStatus(otel.StatusCode.error, error);

          paymentSpan.addEvent('payment_failed', attributes: [
            otel.Attribute.fromString('failure.reason', 'card_declined'),
          ]);

          metricsCollector.incrementCounter('payments_failed');

          // Emit failure state
          emit(CheckoutFailure(error));
          kdebugPrint('❌ Checkout Failed: $error');
        }
      } finally {
        paymentSpan.end();
      }
    } catch (e) {
      parentSpan.recordException(e);
      parentSpan.setStatus(otel.StatusCode.error, e.toString());

      // Emit failure state for any exceptions
      emit(CheckoutFailure('Checkout failed: $e'));
      kdebugPrint('❌ Checkout Exception: $e');
    } finally {
      parentSpan.end();
    }
  }
}

// UI Screens
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        if (state is AuthSuccess) {
          return ProductListScreen();
        }
        return LoginScreen();
      },
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController(text: 'test@test.com');
  final _passwordController = TextEditingController(text: '123456');

  // Available demo users
  final List<Map<String, String>> demoUsers = [
    {'email': 'test@test.com', 'password': '123456', 'name': 'Test User'},
    {
      'email': 'john@example.com',
      'password': 'password123',
      'name': 'John Doe'
    },
    {
      'email': 'sarah@example.com',
      'password': 'sarah2024',
      'name': 'Sarah Smith'
    },
    {'email': 'admin@store.com', 'password': 'admin123', 'name': 'Admin User'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Login - E-Commerce POC')),
      body: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthFailure) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.error),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(height: 50),
              Icon(Icons.shopping_cart, size: 80, color: Colors.blue),
              SizedBox(height: 30),
              TextField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                ),
              ),
              SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
                ),
                obscureText: true,
              ),
              SizedBox(height: 24),
              BlocBuilder<AuthBloc, AuthState>(
                builder: (context, state) {
                  return SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: state is AuthLoading
                          ? null
                          : () {
                              context.read<AuthBloc>().add(
                                    LoginRequested(
                                      _emailController.text,
                                      _passwordController.text,
                                    ),
                                  );
                            },
                      child: state is AuthLoading
                          ? CircularProgressIndicator(color: Colors.white)
                          : Text('Login', style: TextStyle(fontSize: 16)),
                    ),
                  );
                },
              ),
              SizedBox(height: 30),
              Text(
                'Demo Users:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              SizedBox(height: 10),
              ...demoUsers.map((user) => Card(
                    child: ListTile(
                      dense: true,
                      title: Text(user['name']!),
                      subtitle: Text('${user['email']} / ${user['password']}',
                          style: TextStyle(fontSize: 12)),
                      trailing: TextButton(
                        onPressed: () {
                          _emailController.text = user['email']!;
                          _passwordController.text = user['password']!;
                        },
                        child: Text('Use'),
                      ),
                    ),
                  )),
            ],
          ),
        ),
      ),
    );
  }
}

class ProductListScreen extends StatelessWidget {
  const ProductListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Products'),
        actions: [
          IconButton(
            icon: Icon(Icons.analytics),
            onPressed: () => Navigator.pushNamed(context, '/telemetry'),
          ),
          BlocBuilder<CartBloc, CartState>(
            builder: (context, state) {
              final itemCount = state is CartUpdated ? state.items.length : 0;
              return Stack(
                children: [
                  IconButton(
                    icon: Icon(Icons.shopping_cart),
                    onPressed: () => Navigator.pushNamed(context, '/cart'),
                  ),
                  if (itemCount > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        constraints:
                            BoxConstraints(minWidth: 16, minHeight: 16),
                        child: Text(
                          '$itemCount',
                          style: TextStyle(color: Colors.white, fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () => context.read<AuthBloc>().add(LogoutRequested()),
          ),
        ],
      ),
      body: BlocBuilder<ProductBloc, ProductState>(
        builder: (context, state) {
          if (state is ProductInitial) {
            context.read<ProductBloc>().add(LoadProducts());
            return Center(child: CircularProgressIndicator());
          }

          if (state is ProductLoading) {
            return Center(child: CircularProgressIndicator());
          }

          if (state is ProductError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error, size: 64, color: Colors.red),
                  SizedBox(height: 16),
                  Text('Error: ${state.error}'),
                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () =>
                        context.read<ProductBloc>().add(LoadProducts()),
                    child: Text('Retry'),
                  ),
                ],
              ),
            );
          }

          if (state is ProductLoaded) {
            return GridView.builder(
              padding: EdgeInsets.all(16),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.8,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: state.products.length,
              itemBuilder: (context, index) {
                final product = state.products[index];
                return Card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius:
                                BorderRadius.vertical(top: Radius.circular(8)),
                          ),
                          child: Center(
                            child: Text(
                              product.imageUrl,
                              style: TextStyle(fontSize: 48),
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.all(8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              product.name,
                              style: TextStyle(fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '\$${product.price.toStringAsFixed(2)}',
                              style: TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () {
                                  // Track product view
                                  context
                                      .read<ProductBloc>()
                                      .add(ViewProduct(product));
                                  // Add to cart
                                  context
                                      .read<CartBloc>()
                                      .add(AddToCart(product));

                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content:
                                          Text('Added ${product.name} to cart'),
                                      duration: Duration(seconds: 1),
                                    ),
                                  );
                                },
                                child: Text('Add to Cart'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          }

          return Container();
        },
      ),
    );
  }
}

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Shopping Cart')),
      body: BlocBuilder<CartBloc, CartState>(
        builder: (context, state) {
          if (state is! CartUpdated || state.items.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.shopping_cart_outlined,
                      size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('Your cart is empty'),
                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Continue Shopping'),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  itemCount: state.items.length,
                  itemBuilder: (context, index) {
                    final item = state.items[index];
                    return Card(
                      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: ListTile(
                        leading: Text(item.product.imageUrl,
                            style: TextStyle(fontSize: 32)),
                        title: Text(item.product.name),
                        subtitle:
                            Text('\$${item.product.price.toStringAsFixed(2)}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(Icons.remove),
                              onPressed: () {
                                if (item.quantity > 1) {
                                  context.read<CartBloc>().add(
                                        UpdateQuantity(
                                            item.product.id, item.quantity - 1),
                                      );
                                } else {
                                  context.read<CartBloc>().add(
                                        RemoveFromCart(item.product.id),
                                      );
                                }
                              },
                            ),
                            Text('${item.quantity}'),
                            IconButton(
                              icon: Icon(Icons.add),
                              onPressed: () {
                                context.read<CartBloc>().add(
                                      UpdateQuantity(
                                          item.product.id, item.quantity + 1),
                                    );
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  border: Border(top: BorderSide(color: Colors.grey[300]!)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total: \$${state.total.toStringAsFixed(2)}',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            context
                                .read<CheckoutBloc>()
                                .add(InitiateCheckout());
                            Navigator.pushNamed(context, '/checkout');
                          },
                          child: Text('Checkout'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// CheckoutScreen with debugging
class CheckoutScreen extends StatelessWidget {
  const CheckoutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Checkout')),
      body: BlocConsumer<CheckoutBloc, CheckoutState>(
        listener: (context, state) {
          // Debug output
          kdebugPrint('🔍 CheckoutScreen received state: ${state.runtimeType}');

          if (state is CheckoutSuccess) {
            // Clear cart after successful order
            context.read<CartBloc>().add(ClearCart());

            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (dialogContext) => AlertDialog(
                title: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green, size: 30),
                    SizedBox(width: 10),
                    Text('Order Successful! 🎉'),
                  ],
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Order ID: ${state.order.id.substring(0, 8)}...'),
                    SizedBox(height: 8),
                    Text('Total: \$${state.order.total.toStringAsFixed(2)}',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    SizedBox(height: 8),
                    Text('Thank you for your order!',
                        style: TextStyle(color: Colors.grey[600])),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(dialogContext).pop(); // Close dialog
                      Navigator.of(context).popUntil((route) => route.isFirst);
                    },
                    child: Text('Continue Shopping'),
                  ),
                ],
              ),
            );
          }

          if (state is CheckoutFailure) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.error, color: Colors.white),
                    SizedBox(width: 10),
                    Expanded(child: Text(state.error)),
                  ],
                ),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 3),
                action: SnackBarAction(
                  label: 'Try Again',
                  textColor: Colors.white,
                  onPressed: () {
                    // Get cart state and retry
                    final cartState = context.read<CartBloc>().state;
                    if (cartState is CartUpdated) {
                      context.read<CheckoutBloc>().add(
                            ProcessPayment(cartState.items, cartState.total),
                          );
                    }
                  },
                ),
              ),
            );
          }
        },
        builder: (context, checkoutState) {
          kdebugPrint(
              '🔍 CheckoutScreen builder state: ${checkoutState.runtimeType}');

          return BlocBuilder<CartBloc, CartState>(
            builder: (context, cartState) {
              if (cartState is! CartUpdated || cartState.items.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.shopping_cart_outlined,
                          size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('No items to checkout'),
                      SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text('Go Back'),
                      ),
                    ],
                  ),
                );
              }

              return Stack(
                children: [
                  Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Order Summary',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 16),
                        Expanded(
                          child: ListView.builder(
                            itemCount: cartState.items.length,
                            itemBuilder: (context, index) {
                              final item = cartState.items[index];
                              final itemTotal =
                                  item.product.price * item.quantity;
                              return Card(
                                child: ListTile(
                                  leading: Text(item.product.imageUrl,
                                      style: TextStyle(fontSize: 24)),
                                  title: Text(item.product.name),
                                  subtitle: Text('Qty: ${item.quantity}'),
                                  trailing:
                                      Text('\$${itemTotal.toStringAsFixed(2)}'),
                                ),
                              );
                            },
                          ),
                        ),
                        Divider(thickness: 2),
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Total:', style: TextStyle(fontSize: 18)),
                              Text(
                                '\$${cartState.total.toStringAsFixed(2)}',
                                style: TextStyle(
                                    fontSize: 20, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: checkoutState is CheckoutLoading
                                ? null
                                : () {
                                    kdebugPrint(
                                        '🔍 Place Order button pressed');
                                    context.read<CheckoutBloc>().add(
                                          ProcessPayment(
                                              cartState.items, cartState.total),
                                        );
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: checkoutState is CheckoutLoading
                                  ? Colors.grey
                                  : Theme.of(context).primaryColor,
                            ),
                            child: checkoutState is CheckoutLoading
                                ? Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                  Colors.white),
                                        ),
                                      ),
                                      SizedBox(width: 8),
                                      Text('Processing Payment...'),
                                    ],
                                  )
                                : Text('Place Order'),
                          ),
                        ),
                        SizedBox(height: 8),
                        Center(
                          child: Column(
                            children: [
                              Text(
                                'Payment simulation: 70% success rate',
                                style:
                                    TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                              Text(
                                'Current state: ${checkoutState.runtimeType}',
                                style:
                                    TextStyle(fontSize: 10, color: Colors.blue),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Loading overlay
                  if (checkoutState is CheckoutLoading)
                    Container(
                      color: Colors.black.withOpacity(0.3),
                      child: Center(
                        child: Card(
                          child: Padding(
                            padding: EdgeInsets.all(20),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircularProgressIndicator(),
                                SizedBox(height: 16),
                                Text('Processing your payment...'),
                                SizedBox(height: 8),
                                Text(
                                  'Please wait',
                                  style: TextStyle(
                                      color: Colors.grey, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class TelemetryDebugScreen extends StatelessWidget {
  const TelemetryDebugScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('OpenTelemetry Debug')),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '📊 Real-time Metrics',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 16),
                    _buildMetricTile('Conversion Rate',
                        '${metricsCollector.getConversionRate().toStringAsFixed(1)}%'),
                    _buildMetricTile('Cart Abandonment Rate',
                        '${metricsCollector.getCartAbandonmentRate().toStringAsFixed(1)}%'),
                    _buildMetricTile('Avg Response Time',
                        '${metricsCollector.getAverageResponseTime().toStringAsFixed(0)}ms'),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '🔢 Raw Metrics Data',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _formatMetrics(metricsCollector.getAllMetrics()),
                        style: TextStyle(fontFamily: 'monospace', fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '🔍 OpenTelemetry Features Demonstrated',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 16),
                    _buildFeatureTile('✅ Distributed Tracing',
                        'User journey spans across BLoCs'),
                    _buildFeatureTile('✅ Custom Events',
                        'login_attempt, product_viewed, cart_updated, etc.'),
                    _buildFeatureTile(
                        '✅ Error Tracking', 'Payment failures, network errors'),
                    _buildFeatureTile('✅ Custom Metrics',
                        'Conversion rate, abandonment rate, response times'),
                    _buildFeatureTile('✅ Context Propagation',
                        'Parent-child span relationships'),
                    _buildFeatureTile('✅ Resource Attributes',
                        'App version, device info, user demographics'),
                    _buildFeatureTile('✅ Span Processors',
                        'Batch and simple span processors'),
                    _buildFeatureTile('✅ Console Exporter',
                        'Check console for detailed span output'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricTile(String title, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: TextStyle(fontWeight: FontWeight.w500)),
          Text(value,
              style:
                  TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
        ],
      ),
    );
  }

  Widget _buildFeatureTile(String title, String description) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontWeight: FontWeight.bold)),
          Text(description,
              style: TextStyle(color: Colors.grey[600], fontSize: 12)),
          SizedBox(height: 8),
        ],
      ),
    );
  }

  String _formatMetrics(Map<String, dynamic> metrics) {
    return metrics.entries.map((e) => '${e.key}: ${e.value}').join('\n');
  }
}
