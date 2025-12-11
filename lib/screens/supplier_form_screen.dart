import 'package:flutter/material.dart';
import '../services/api_service.dart';

class SupplierFormScreen extends StatefulWidget {
  final VoidCallback onSupplierAdded;

  const SupplierFormScreen({super.key, required this.onSupplierAdded});

  @override
  State<SupplierFormScreen> createState() => _SupplierFormScreenState();
}

class _SupplierFormScreenState extends State<SupplierFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final ApiService _apiService = ApiService();

  // Controllers for required and optional fields
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _contactPersonController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      try {
        final supplierData = {
          'name': _nameController.text,
          'email': _emailController.text,
          'contact_person': _contactPersonController.text.isEmpty ? null : _contactPersonController.text,
          'phone': _phoneController.text.isEmpty ? null : _phoneController.text,
          'address': _addressController.text.isEmpty ? null : _addressController.text,
        };

        await _apiService.addSupplier(supplierData);
        
        if (!mounted) return;
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Supplier added successfully!')),
        );
        
        widget.onSupplierAdded(); 
        Navigator.pop(context); 
        
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add supplier: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add New Supplier'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: <Widget>[
              // Name Field (Required)
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Supplier Name *'),
                validator: (value) => value!.isEmpty ? 'Please enter the supplier name' : null,
              ),
              // Email Field (Required)
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email *'),
                validator: (value) => value!.isEmpty ? 'Please enter an email' : null,
              ),
              // Contact Person
              TextFormField(
                controller: _contactPersonController,
                decoration: const InputDecoration(labelText: 'Contact Person'),
              ),
              // Phone
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Phone'),
              ),
              // Address
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(labelText: 'Address'),
                maxLines: 2,
              ),
              
              const SizedBox(height: 30),

              ElevatedButton.icon(
                onPressed: _submitForm,
                icon: const Icon(Icons.save),
                label: const Text('Save Supplier'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
