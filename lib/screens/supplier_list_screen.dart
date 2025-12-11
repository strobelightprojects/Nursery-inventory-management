import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'supplier_form_screen.dart'; // Import both the form and the Supplier model

// NOTE: The Supplier class is defined in supplier_form_screen.dart
// For this file to compile, ensure you have the Supplier class definition in the form screen.

class SupplierListScreen extends StatefulWidget {
  const SupplierListScreen({super.key});

  @override
  State<SupplierListScreen> createState() => _SupplierListScreenState();
}

class _SupplierListScreenState extends State<SupplierListScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _suppliers = [];
  bool _isLoading = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _fetchSuppliers();
  }

  Future<void> _fetchSuppliers() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });
    try {
      final data = await _apiService.fetchSuppliers();
      setState(() {
        _suppliers = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Connection Error: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  // Navigate to the ADD Supplier form
  void _navigateToAddSupplier() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SupplierFormScreen(
          onSupplierSaved: _fetchSuppliers, // Use onSupplierSaved now
        ),
      ),
    );
  }
  
  // Navigate to the EDIT Supplier form
  void _navigateToEditSupplier(Map<String, dynamic> supplierData) {
    // Convert the map data fetched from the API into the Supplier object 
    final supplier = Supplier.fromJson(supplierData); 
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SupplierFormScreen(
          onSupplierSaved: _fetchSuppliers, 
          supplier: supplier, // Pass the existing supplier data to trigger Edit Mode
        ),
      ),
    );
  }
  
  Future<void> _deleteSupplier(int id, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Deletion'),
          content: Text('Are you sure you want to delete supplier "$name"? This will fail if plants are still linked to them.'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      try {
        await _apiService.deleteSupplier(id);
        _fetchSuppliers(); // Refresh the list
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Supplier "$name" deleted successfully.')),
        );
      } catch (e) {
        if (!mounted) return;
        // The error will include the reason (e.g., "Supplier is linked to X products...")
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Deletion failed: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Suppliers'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh List',
            onPressed: _fetchSuppliers,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error.isNotEmpty
              ? Center(child: Text(_error, style: const TextStyle(color: Colors.red, fontSize: 16)))
              : ListView.builder(
                  itemCount: _suppliers.length,
                  itemBuilder: (context, index) {
                    final supplier = _suppliers[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      child: ListTile(
                        // Tap the ListTile to navigate to the Edit Form
                        onTap: () => _navigateToEditSupplier(supplier), 
                        leading: CircleAvatar(
                          backgroundColor: Colors.blue,
                          child: Text(supplier['id'].toString(), style: const TextStyle(color: Colors.white)),
                        ),
                        title: Text(supplier['name'] ?? 'N/A', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(
                          'Contact: ${supplier['contact_person'] ?? 'None'} | Email: ${supplier['email'] ?? 'N/A'}'
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _deleteSupplier(supplier['id'], supplier['name']),
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToAddSupplier,
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        tooltip: 'Add New Supplier',
        child: const Icon(Icons.person_add),
      ),
    );
  }
}
