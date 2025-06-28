import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:otel_poc/blocs/auth_bloc/authentication_bloc.dart';
import 'package:otel_poc/blocs/cart_bloc/cart_bloc.dart';
import 'package:otel_poc/blocs/checkout_bloc/checkout_bloc.dart';
import 'package:otel_poc/blocs/product_bloc/product_bloc.dart';
import 'package:otel_poc/global_instances.dart';
import 'package:otel_poc/screens/cart_screen.dart';
import 'package:otel_poc/screens/checkout_screen.dart';
import 'package:otel_poc/screens/login_screen.dart';
import 'package:otel_poc/screens/product_list_screen.dart';
import 'package:otel_poc/screens/telemetry_debug_screen.dart';
// import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeOpenTelemetry();
  sessionTracker = SessionTracker();

  runApp(MyApp());
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
