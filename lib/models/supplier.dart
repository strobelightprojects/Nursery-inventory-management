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
      id: json['id'],
      name: json['name'],
      email: json['email'],
      contactPerson: json['contact_person'],
      phone: json['phone'],
      address: json['address'],
    );
  }

  // Converts a Dart Supplier object into a JSON map for sending to the API
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'email': email,
      'contact_person': contactPerson,
      'phone': phone,
      'address': address,
    };
  }
}