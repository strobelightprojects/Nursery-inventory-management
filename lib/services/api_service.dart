import 'package:http/http.dart' as http;
import 'dart:convert';

// Configuration from main.dart, centralized here
const String baseUrl = 'http://127.0.0.1:5000';

class ApiService {
  // --- 1. PLANT ENDPOINTS ---

  // GET /plants
  Future<List<dynamic>> fetchPlants({String? searchTerm}) async {
    String url = '$baseUrl/plants';
    if (searchTerm != null && searchTerm.isNotEmpty) {
      // Handles the search requirement
      url += '?search=$searchTerm';
    }
    
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load plants: ${response.statusCode}');
    }
  }

  // POST /plants (Add New Plant)
  Future<Map<String, dynamic>> addPlant(Map<String, dynamic> plantData) async {
    final response = await http.post(
      Uri.parse('$baseUrl/plants'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(plantData),
    );
    if (response.statusCode == 201) { // 201 Created
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to add plant: ${response.body}');
    }
  }

  // DELETE /plants/<id>
  Future<void> deletePlant(int id) async {
    final response = await http.delete(Uri.parse('$baseUrl/plants/$id'));
    if (response.statusCode != 200) {
      throw Exception('Failed to delete plant: ${response.body}');
    }
  }

  // --- 2. SUPPLIER ENDPOINTS ---

  // GET /suppliers
  Future<List<dynamic>> fetchSuppliers() async {
    final response = await http.get(Uri.parse('$baseUrl/suppliers'));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load suppliers: ${response.statusCode}');
    }
  }

  // --- 3. INVENTORY ENDPOINTS ---
  
  // POST /inventory/restock
  Future<Map<String, dynamic>> restockPlant(int productId, int quantity) async {
    final response = await http.post(
      Uri.parse('$baseUrl/inventory/restock'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'product_id': productId, 'quantity': quantity}),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to restock plant: ${response.body}');
    }
  }

  // --- 4. ORDER ENDPOINTS ---
  
  // GET /orders
  Future<List<dynamic>> fetchOrders() async {
    final response = await http.get(Uri.parse('$baseUrl/orders'));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load orders: ${response.statusCode}');
    }
  }
}
