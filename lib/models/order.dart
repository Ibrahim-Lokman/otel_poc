import 'package:otel_poc/models/cartitem.dart';

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
