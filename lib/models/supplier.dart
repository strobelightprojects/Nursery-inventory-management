class Supplier {
  final int id;
  String name;
  String email;
  String? contactPerson;
  String? phone;
  String? address;

  Supplier({
    required this.id,
    required this.name,
    required this.email,
    this.contactPerson,
    this.phone,
    this.address,
  });

  // Converts JSON from the Flask API into a Dart Supplier object
  factory Supplier.fromJson(Map<String, dynamic> json) {
    return Supplier(
      // Ensure explicit type casting
      id: json['id'] as int,
      name: json['name'] as String,
      email: json['email'] as String,
      
      // Use null-aware casting for optional fields
      contactPerson: json['contact_person'] as String?,
      phone: json['phone'] as String?,
      address: json['address'] as String?,
    );
  }

  // Converts a Dart Supplier object into a JSON map for sending to the API
  Map<String, dynamic> toJson() {
    return {
      // The ID is included here only if you need to send it for an update/delete,
      // but is generally omitted for POST (create). Leaving it here is fine.
      'id': id,
      'name': name,
      'email': email,
      'contact_person': contactPerson,
      'phone': phone,
      'address': address,
    };
  }
}