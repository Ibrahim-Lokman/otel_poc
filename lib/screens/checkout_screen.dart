import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:otel_poc/blocs/cart_bloc/cart_bloc.dart';
import 'package:otel_poc/blocs/checkout_bloc/checkout_bloc.dart';

class CheckoutScreen extends StatelessWidget {
  const CheckoutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Checkout')),
      body: BlocConsumer<CheckoutBloc, CheckoutState>(
        listener: (context, state) {
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
                                : Text('Place Order',
                                    style: TextStyle(
                                        fontSize: 16, color: Colors.white)),
                          ),
                        ),
                        SizedBox(height: 8),
                        Center(
                          child: Text(
                            'Payment simulation: 70% success rate',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Loading overlay
                  if (checkoutState is CheckoutLoading)
                    Container(
                      color: const Color.fromARGB(31, 0, 0, 0),
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
