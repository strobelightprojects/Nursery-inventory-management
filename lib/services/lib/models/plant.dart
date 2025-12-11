class Plant {
  final int id;
  final String name;
  final String category;
  final double price;
  final int quantity;
  final String? supplierName; // Nullable as per API
  final int? supplierId;

  Plant({
    required this.id,
    required this.name,
    required this.category,
    required this.price,
    required this.quantity,
    this.supplierName,
    this.supplierId,
  });

  // Factory constructor to create a Plant object from the JSON map received from the API
  factory Plant.fromJson(Map<String, dynamic> json) {
    return Plant(
      id: json['id'] as int,
      name: json['name'] as String,
      category: json['category'] as String,
      // Handle potential number type differences (API returns number, Dart needs double/int)
      price: (json['price'] as num).toDouble(),
      quantity: json['quantity'] as int,
      supplierName: json['supplier_name'] as String?,
      supplierId: json['supplier_id'] as int?,
    );
  }
}
