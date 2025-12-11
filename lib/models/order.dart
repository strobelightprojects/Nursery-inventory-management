import 'order_item.dart';

class Order {
  final int id;
  final String customerName;
  final String date;
  final double total;
  final List<OrderItem> items; // List of line items

  Order({
    required this.id,
    required this.customerName,
    required this.date,
    required this.total,
    required this.items,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    // Parse the nested list of items
    var itemsList = json['items'] as List;
    List<OrderItem> orderItems = itemsList.map((i) => OrderItem.fromJson(i)).toList();

    return Order(
      id: json['id'],
      customerName: json['customer_name'],
      date: json['date'],
      // Ensure the total is a double
      total: json['total'] is int ? json['total'].toDouble() : json['total'],
      items: orderItems,
    );
  }
}
