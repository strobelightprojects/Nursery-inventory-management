class OrderItem {
  final int productId;
  final String productName;
  final int quantity;
  final double priceAtSale;

  OrderItem({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.priceAtSale,
  });

  // Converts JSON from the Flask API (specifically the nested 'items' list)
  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      productId: json['product_id'],
      productName: json['name'] ?? 'Unknown Plant', // Name comes from the JOIN in Flask
      quantity: json['quantity'],
      // Ensure the price is a double
      priceAtSale: json['price_at_sale'] is int 
                   ? json['price_at_sale'].toDouble() 
                   : json['price_at_sale'],
    );
  }
}