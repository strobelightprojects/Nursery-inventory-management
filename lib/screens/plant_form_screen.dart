import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/plant.dart'; // Make sure this model file exists and is up-to-date

class PlantFormScreen extends StatefulWidget {
  final VoidCallback onPlantSaved; // Used for both Add and Edit completion
  final Plant? plant; // Optional plant data for editing

  const PlantFormScreen({super.key, required this.onPlantSaved, this.plant});

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
  final TextEditingController _supplierIdController = TextEditingController(); 

  bool get isEditing => widget.plant != null;

  @override
  void initState() {
    super.initState();
    // Pre-populate fields if in Edit Mode
    if (isEditing) {
      _nameController.text = widget.plant!.name;
      _categoryController.text = widget.plant!.category;
      _priceController.text = widget.plant!.price.toString();
      _quantityController.text = widget.plant!.quantity.toString();
      _supplierIdController.text = widget.plant!.supplierId?.toString() ?? '';
    }
    // Note: In EDIT mode, we display the quantity but don't allow editing it here.
    // Stock changes are handled by the separate Restock function in InventoryScreen.
  }

  @override
  void dispose() {
    _nameController.dispose();
    _categoryController.dispose();
    _priceController.dispose();
    _quantityController.dispose();
    _supplierIdController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      try {
        final plantData = {
          'name': _nameController.text,
          'category': _categoryController.text,
          'price': double.parse(_priceController.text),
          // Quantity is only sent during POST (Add)
          'supplier_id': int.tryParse(_supplierIdController.text),
        };
        
        if (isEditing) {
          // Send PUT request to update details (name, category, price, supplier_id)
          await _apiService.updatePlant(widget.plant!.id, plantData);
        } else {
          // Send POST request to add a new plant. Must include quantity.
          plantData['quantity'] = int.parse(_quantityController.text); 
          await _apiService.addPlant(plantData);
        }

        if (!mounted) return;
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Plant ${isEditing ? "updated" : "added"} successfully!')),
        );
        
        widget.onPlantSaved(); 
        Navigator.pop(context); 
        
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save plant: $e')),
        );
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Plant Details' : 'Add New Plant'),
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
              // Quantity Field (Only required/editable in ADD mode)
              if (!isEditing) 
                TextFormField(
                  controller: _quantityController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Initial Quantity (Stock)'),
                  validator: (value) => value!.isEmpty ? 'Please enter a quantity' : null,
                )
              else 
                Padding(
                  padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
                  child: Text('Current Stock: ${widget.plant!.quantity}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              // Supplier ID Field
              TextFormField(
                controller: _supplierIdController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Supplier ID (e.g., 1, 2)'),
              ),
              
              const SizedBox(height: 30),

              ElevatedButton.icon(
                onPressed: _submitForm,
                icon: const Icon(Icons.save),
                label: Text(isEditing ? 'Update Plant Details' : 'Save New Plant'),
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
