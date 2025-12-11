import 'package:http/http.dart' as http;
import 'dart:convert';
// Import all necessary Model files
import '../models/plant.dart';
import '../models/supplier.dart';
import '../models/order.dart';

// Configuration: The address where your Python API server is running
const String baseUrl = 'http://127.0.0.1:5000';

class ApiService {
  
  // --- UTILITY ---

  // Helper method to handle POST/PUT/DELETE requests with JSON body
  Future<http.Response> _sendJsonRequest(String url, String method, Map<String, dynamic>? data) async {
    final uri = Uri.parse(url);
    final headers = {'Content-Type': 'application/json'};
    final body = data != null ? jsonEncode(data) : null;

    switch (method.toUpperCase()) {
      case 'POST':
        return http.post(uri, headers: headers, body: body);
      case 'PUT':
        return http.put(uri, headers: headers, body: body);
      case 'DELETE':
        return http.delete(uri, headers: headers);
      default:
        throw Exception('Unsupported HTTP method: $method');
    }
  }

  // Helper to extract specific error message from the API response
  String _extractErrorMessage(http.Response response) {
    try {
      final errorJson = jsonDecode(response.body);
      return errorJson['error'] ?? 'Unknown API error (Status: ${response.statusCode})';
    } catch (_) {
      return 'Failed to process API response (Status: ${response.statusCode})';
    }
  }


  // --- 1. PLANT CRUD ENDPOINTS ---

  // GET /plants (includes optional search parameter)
  Future<List<Plant>> fetchPlants({String? searchTerm}) async {
    String url = '$baseUrl/plants';
    if (searchTerm != null && searchTerm.isNotEmpty) {
      url += '?search=${Uri.encodeQueryComponent(searchTerm)}';
    }
    
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      List jsonResponse = jsonDecode(response.body);
      // Maps raw JSON list to List<Plant>
      return jsonResponse.map((plantJson) => Plant.fromJson(plantJson)).toList();
    } else {
      throw Exception('Failed to load plants: ${_extractErrorMessage(response)}');
    }
  }

  // POST /plants (Add New Plant)
  Future<Map<String, dynamic>> addPlant(Map<String, dynamic> plantData) async {
    final response = await _sendJsonRequest('$baseUrl/plants', 'POST', plantData);
    if (response.statusCode == 201) { // 201 Created
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to add plant: ${_extractErrorMessage(response)}');
    }
  }

  // PUT /plants/<id> (Update Plant Details - excluding quantity)
  Future<void> updatePlant(int id, Map<String, dynamic> updateData) async {
    final response = await _sendJsonRequest('$baseUrl/plants/$id', 'PUT', updateData);
    if (response.statusCode != 200) {
      throw Exception('Failed to update plant: ${_extractErrorMessage(response)}');
    }
  }

  // DELETE /plants/<id>
  Future<void> deletePlant(int id) async {
    final response = await _sendJsonRequest('$baseUrl/plants/$id', 'DELETE', null);
    if (response.statusCode != 200) {
      throw Exception('Failed to delete plant: ${_extractErrorMessage(response)}');
    }
  }
  
  // --- 2. SUPPLIER CRUD ENDPOINTS ---

  // GET /suppliers
  Future<List<Supplier>> fetchSuppliers() async {
    final response = await http.get(Uri.parse('$baseUrl/suppliers'));
    if (response.statusCode == 200) {
      List<dynamic> data = json.decode(response.body);
      // Maps raw JSON list to List<Supplier>
      return data.map((json) => Supplier.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load suppliers: ${_extractErrorMessage(response)}');
    }
  }
  
  // POST /suppliers (Add New Supplier)
  Future<Map<String, dynamic>> addSupplier(Map<String, dynamic> supplierData) async {
    final response = await _sendJsonRequest('$baseUrl/suppliers', 'POST', supplierData);
    if (response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to add supplier: ${_extractErrorMessage(response)}');
    }
  }

  // PUT /suppliers/<id> (Update Existing Supplier)
  Future<void> updateSupplier(int id, Map<String, dynamic> updateData) async {
    final response = await _sendJsonRequest('$baseUrl/suppliers/$id', 'PUT', updateData);
    if (response.statusCode != 200) {
      throw Exception('Failed to update supplier: ${_extractErrorMessage(response)}');
    }
  }

  // DELETE /suppliers/<id>
  Future<void> deleteSupplier(int id) async {
    final response = await _sendJsonRequest('$baseUrl/suppliers/$id', 'DELETE', null);
    if (response.statusCode != 200) {
      throw Exception('Failed to delete supplier: ${_extractErrorMessage(response)}');
    }
  }


  // --- 3. INVENTORY & RESTOCK ENDPOINTS ---
  
  // POST /inventory/restock (Used for updating stock quantity)
  Future<Map<String, dynamic>> restockPlant(int productId, int quantity) async {
    final response = await _sendJsonRequest(
      '$baseUrl/inventory/restock', 
      'POST', 
      {'product_id': productId, 'quantity': quantity}
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to restock plant: ${_extractErrorMessage(response)}');
    }
  }


  // --- 4. ORDER MANAGEMENT ENDPOINTS ---

  // GET /orders
  Future<List<Order>> fetchOrders() async {
    final response = await http.get(Uri.parse('$baseUrl/orders'));
    if (response.statusCode == 200) {
      List jsonResponse = jsonDecode(response.body);
      // Maps raw JSON list to List<Order>
      return jsonResponse.map((orderJson) => Order.fromJson(orderJson)).toList();
    } else {
      throw Exception('Failed to load orders: ${_extractErrorMessage(response)}');
    }
  }
  
  // POST /orders (Create New Order)
  Future<Map<String, dynamic>> createOrder(Map<String, dynamic> orderData) async {
    final response = await _sendJsonRequest('$baseUrl/orders', 'POST', orderData);
    if (response.statusCode == 201) { // 201 Created
      return jsonDecode(response.body);
    } else {
      // The API returns the specific error message (e.g., "Insufficient stock") in the body.
      throw Exception('Failed to place order: ${_extractErrorMessage(response)}');
    }
  }
  
  // DELETE /orders/<id> (Cancel Order and Revert Stock)
  Future<void> deleteOrder(int id) async {
    final response = await _sendJsonRequest('$baseUrl/orders/$id', 'DELETE', null);
    if (response.statusCode != 200) {
      throw Exception('Failed to delete order: ${_extractErrorMessage(response)}');
    }
  }
} 
