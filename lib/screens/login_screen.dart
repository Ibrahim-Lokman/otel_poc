import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:otel_poc/blocs/auth_bloc/authentication_bloc.dart';
import 'package:otel_poc/screens/product_list_screen.dart';

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
  LoginScreenState createState() => LoginScreenState();
}

class LoginScreenState extends State<LoginScreen> {
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
