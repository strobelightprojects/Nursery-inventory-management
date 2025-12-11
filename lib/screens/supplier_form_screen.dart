import 'package:flutter/material.dart';
import '../services/api_service.dart';

// Use a simple data model for the supplier data coming from API
class Supplier {
  final int? id;
  final String name;
  final String email;
  final String? contactPerson;
  final String? phone;
  final String? address;

  Supplier({
    this.id,
    required this.name,
    required this.email,
    this.contactPerson,
    this.phone,
    this.address,
  });
  
  // Factory to create from API response (Map<String, dynamic>)
  factory Supplier.fromJson(Map<String, dynamic> json) {
    return Supplier(
      id: json['id'] as int?,
      name: json['name'] as String,
      email: json['email'] as String,
      contactPerson: json['contact_person'] as String?,
      phone: json['phone'] as String?,
      address: json['address'] as String?,
    );
  }
}

class SupplierFormScreen extends StatefulWidget {
  final VoidCallback onSupplierSaved;
  final Supplier? supplier; // NEW: Optional supplier data for editing

  const SupplierFormScreen({super.key, required this.onSupplierSaved, this.supplier});

  @override
  State<SupplierFormScreen> createState() => _SupplierFormScreenState();
}

class _SupplierFormScreenState extends State<SupplierFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final ApiService _apiService = ApiService();
  
  // Controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _contactPersonController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();

  bool get isEditing => widget.supplier != null;

  @override
  void initState() {
    super.initState();
    // Pre-populate fields if in Edit Mode
    if (isEditing) {
      _nameController.text = widget.supplier!.name;
      _emailController.text = widget.supplier!.email;
      _contactPersonController.text = widget.supplier!.contactPerson ?? '';
      _phoneController.text = widget.supplier!.phone ?? '';
      _addressController.text = widget.supplier!.address ?? '';
    }
  }

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

        if (isEditing) {
          // CALL PUT ENDPOINT for Editing
          await _apiService.updateSupplier(widget.supplier!.id!, supplierData);
        } else {
          // CALL POST ENDPOINT for Adding
          await _apiService.addSupplier(supplierData);
        }
        
        if (!mounted) return;
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Supplier ${isEditing ? "updated" : "added"} successfully!')),
        );
        
        widget.onSupplierSaved(); 
        Navigator.pop(context); 
        
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save supplier: $e')),
        );
      }
    }
  }
  
  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _contactPersonController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Supplier (${widget.supplier!.id})' : 'Add New Supplier'),
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
                label: Text(isEditing ? 'Update Supplier' : 'Save Supplier'),
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
