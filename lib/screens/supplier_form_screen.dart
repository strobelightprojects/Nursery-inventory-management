import 'package:flutter/material.dart';
import '../services/api_service.dart';
// Use the prefix for the model, as we did in supplier_list_screen.dart
import '../models/supplier.dart' as model; 

class SupplierFormScreen extends StatefulWidget {
  // Use model.Supplier for type safety
  final model.Supplier? supplier; 

  // CRITICAL FIX: Removed the required 'onSupplierSaved' parameter
  const SupplierFormScreen({
    super.key,
    this.supplier,
  });

  @override
  State<SupplierFormScreen> createState() => _SupplierFormScreenState();
}

class _SupplierFormScreenState extends State<SupplierFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final ApiService _apiService = ApiService();

  // Controllers for form fields
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _contactController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();

  bool get isEditing => widget.supplier != null;

  @override
  void initState() {
    super.initState();
    // Pre-fill fields if in editing mode
    if (isEditing) {
      final s = widget.supplier!;
      _nameController.text = s.name;
      _emailController.text = s.email;
      _contactController.text = s.contactPerson ?? '';
      _phoneController.text = s.phone ?? '';
      _addressController.text = s.address ?? '';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _contactController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      // Create the payload map from the form data
      final Map<String, dynamic> supplierData = {
        'name': _nameController.text,
        'email': _emailController.text,
        'contact_person': _contactController.text.isEmpty ? null : _contactController.text,
        'phone': _phoneController.text.isEmpty ? null : _phoneController.text,
        'address': _addressController.text.isEmpty ? null : _addressController.text,
      };

      try {
        if (isEditing) {
          // Update existing supplier
          await _apiService.updateSupplier(widget.supplier!.id, supplierData);
        } else {
          // Add new supplier
          await _apiService.addSupplier(supplierData);
        }

        if (mounted) {
          // Notify the user of success
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Supplier ${isEditing ? "updated" : "added"} successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          // Signal success and refresh to the list screen (true tells it to refresh)
          Navigator.pop(context, true); 
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${e.toString().replaceFirst('Exception: ', '')}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Supplier' : 'Add New Supplier'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // Name Field (Required)
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Supplier Name *'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a name.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 15),

              // Email Field (Required)
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email *'),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter an email.';
                  }
                  // Basic email validation
                  if (!value.contains('@') || !value.contains('.')) {
                    return 'Please enter a valid email.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 15),

              // Contact Person Field
              TextFormField(
                controller: _contactController,
                decoration: const InputDecoration(labelText: 'Contact Person'),
              ),
              const SizedBox(height: 15),

              // Phone Field
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(labelText: 'Phone'),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 15),

              // Address Field
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(labelText: 'Address'),
                maxLines: 3,
              ),
              const SizedBox(height: 30),

              // Submit Button
              ElevatedButton.icon(
                onPressed: _submitForm,
                icon: Icon(isEditing ? Icons.save : Icons.add),
                label: Text(isEditing ? 'Save Changes' : 'Add Supplier'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  textStyle: const TextStyle(fontSize: 18),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 