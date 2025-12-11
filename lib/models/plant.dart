import 'package:http/http.dart';

class Plant {
  final int id;
  final String name;
  final String category;
  final double price;
  final int quantity;
  
  // --- NEW FIELDS ADDED FOR SUPPLIER CONNECTION ---
  final int? supplierId;
  final String? supplierName;
  // ------------------------------------------------

  Plant({
    required this.id,
    required this.name,
    required this.category,
    required this.price,
    required this.quantity,
    this.supplierId, 
    required this.supplierName, 
  });

  factory Plant.fromJson(Map<String, dynamic> json) {
    return Plant(
      id: json['id'] as int,
      name: json['name'] as String,
      category: json['category'] as String,
      // Ensure price is converted correctly
      price: (json['price'] as num).toDouble(), 
      quantity: json['quantity'] as int,
      
      // --- JSON MAPPING FOR SUPPLIER ---
      supplierId: json['supplier_id'] as int?, 
      supplierName: json['supplier_name'] as String?, 
      // ---------------------------------
    );
  }

  // CRITICAL FIX: Removed 'id' from toJson() to prevent API conflicts 
  // during creation (POST) and to follow best practices for update (PUT).
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'category': category,
      'price': price,
      'quantity': quantity, // NOTE: Quantity is often handled separately by the API
      // Include supplierId when sending data back (e.g., for update or creation)
      'supplier_id': supplierId, 
    };
  }
} 