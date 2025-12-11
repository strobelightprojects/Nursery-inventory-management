import 'package:flutter/material.dart';
import '../services/api_service.dart';

class PlantFormScreen extends StatefulWidget {
  final VoidCallback onPlantAdded; // Callback to refresh the main list

  const PlantFormScreen({super.key, required this.onPlantAdded});

  @override
  State<PlantFormScreen> createState() => _PlantFormScreenState();
}

class _PlantFormScreenState extends State<PlantFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final ApiService _apiService = ApiService();
  
  // Controllers for text fields
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _categoryController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _supplierIdController = TextEditingController(); // Simpler for now

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      try {
        final plantData = {
          'name': _nameController.text,
          'category': _categoryController.text,
          'price': double.parse(_priceController.text),
          'quantity': int.parse(_quantityController.text),
          'supplier_id': int.tryParse(_supplierIdController.text), // Handle optional/nullable
          // Other fields (cost_price, image_path, reorder_at) could be added here
        };

        await _apiService.addPlant(plantData);
        
        if (!mounted) return;
        
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Plant added successfully!')),
        );
        
        widget.onPlantAdded(); // Trigger the refresh callback
        Navigator.pop(context); // Go back to the inventory list
        
      } catch (e) {
        if (!mounted) return;
        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add plant: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add New Plant'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: <Widget>[
              // Name Field
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Plant Name'),
                validator: (value) => value!.isEmpty ? 'Please enter a name' : null,
              ),
              // Category Field
              TextFormField(
                controller: _categoryController,
                decoration: const InputDecoration(labelText: 'Category'),
                validator: (value) => value!.isEmpty ? 'Please enter a category' : null,
              ),
              // Price Field
              TextFormField(
                controller: _priceController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Price (\$)', hintText: '12.50'),
                validator: (value) => value!.isEmpty ? 'Please enter a price' : null,
              ),
              // Quantity Field
              TextFormField(
                controller: _quantityController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Quantity (Stock)'),
                validator: (value) => value!.isEmpty ? 'Please enter a quantity' : null,
              ),
              // Supplier ID Field (Will be a dropdown later)
              TextFormField(
                controller: _supplierIdController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Supplier ID (e.g., 1, 2)'),
              ),
              
              const SizedBox(height: 30),

              ElevatedButton.icon(
                onPressed: _submitForm,
                icon: const Icon(Icons.save),
                label: const Text('Save Plant Record'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  backgroundColor: Colors.green,
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
