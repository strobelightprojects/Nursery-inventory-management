import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'supplier_form_screen.dart'; 

// CRITICAL FIX: Use 'model' as a prefix for the Supplier data model
// This resolves the conflict with any other class named Supplier in this file's imports.
import '../models/supplier.dart' as model; 

class SupplierListScreen extends StatefulWidget {
  const SupplierListScreen({super.key});

  @override
  State<SupplierListScreen> createState() => _SupplierListScreenState();
}

class _SupplierListScreenState extends State<SupplierListScreen> {
  // Use model.Supplier for type definition (resolves ambiguous_import)
  late Future<List<model.Supplier>> _suppliersFuture; 
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _suppliersFuture = _fetchSuppliers();
  }

  // Use model.Supplier for return type
  Future<List<model.Supplier>> _fetchSuppliers() async {
    try {
      // ApiService fetchSuppliers returns List<model.Supplier>
      return await _apiService.fetchSuppliers();
    } catch (e) {
      // Re-throw the error so FutureBuilder can display it
      throw Exception('Failed to load suppliers: $e');
    }
  }

  // Use model.Supplier for the optional parameter type
  void _navigateToForm({model.Supplier? supplier}) async {
    // Navigates to the form for adding/editing a supplier
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SupplierFormScreen(supplier: supplier),
      ),
    );

    // If result is true (meaning data was changed), refresh the list.
    if (result == true) {
      setState(() {
        _suppliersFuture = _fetchSuppliers();
      });
    }
  }

  void _deleteSupplier(int supplierId) async {
    // Confirmation dialog before deleting
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Deletion'),
        content: const Text('Are you sure you want to delete this supplier? This may affect plants currently linked to them.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _apiService.deleteSupplier(supplierId);
        setState(() {
          _suppliersFuture = _fetchSuppliers();
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Supplier deleted successfully!')),
          );
        }
      } catch (e) {
        if (mounted) {
          // Display the error message returned from the API
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Suppliers'),
      ),
      // Use model.Supplier in FutureBuilder declaration
      body: FutureBuilder<List<model.Supplier>>(
        future: _suppliersFuture,
        builder: (context, snapshot) {
          // 1. ConnectionState.waiting handles the loading state
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          // 2. snapshot.hasError handles API and network errors
          } else if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text('Error: ${snapshot.error}', textAlign: TextAlign.center),
              ),
            );
          // 3. No Data handles an empty list
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No suppliers found. Tap + to add one!'));
          // 4. Data exists, build the list
          } else {
            final suppliers = snapshot.data!;
            return ListView.builder(
              itemCount: suppliers.length,
              itemBuilder: (context, index) {
                final supplier = suppliers[index]; 
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                  child: ListTile(
                    leading: const Icon(Icons.business, color: Colors.green),
                    title: Text(
                      supplier.name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(supplier.email),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Edit Button
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.green),
                          onPressed: () => _navigateToForm(supplier: supplier),
                        ),
                        // Delete Button
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _deleteSupplier(supplier.id),
                        ),
                      ],
                    ),
                    onTap: () => _navigateToForm(supplier: supplier),
                  ),
                );
              },
            );
          }
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToForm(),
        tooltip: 'Add Supplier',
        child: const Icon(Icons.add),
      ),
    );
  }
} 
