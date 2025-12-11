import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/plant.dart';
import '../models/supplier.dart'; // IMPORTANT: Supplier model is needed for the list

class PlantFormScreen extends StatefulWidget {
  final VoidCallback onPlantSaved; // Callback to refresh the inventory list
  final Plant? plant; // Optional plant data for editing (null for new plant)

  const PlantFormScreen({super.key, required this.onPlantSaved, this.plant});

  @override
  State<PlantFormScreen> createState() => _PlantFormScreenState();
}

class _PlantFormScreenState extends State<PlantFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final ApiService _apiService = ApiService();
  
  // Controllers for form fields
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _categoryController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController(); // Used for initial stock (POST)

  // --- SUPPLIER STATE VARIABLES ---
  List<Supplier> _suppliers = [];
  int? _selectedSupplierId; // Holds the ID selected in the dropdown (or null)
  bool _isLoadingSuppliers = true; 
  // --------------------------------

  bool get isEditing => widget.plant != null;

  @override
  void initState() {
    super.initState();
    
    // 1. Pre-populate fields if in Edit Mode
    if (isEditing) {
      _nameController.text = widget.plant!.name;
      _categoryController.text = widget.plant!.category;
      _priceController.text = widget.plant!.price.toString();
      // Only set quantity controller text if editing (though it won't be used for updates)
      _quantityController.text = widget.plant!.quantity.toString(); 
      
      // Set the initial selected supplier ID from the plant data
      _selectedSupplierId = widget.plant!.supplierId; 
    }

    // 2. Start fetching the list of all suppliers
    _fetchSuppliers(); 
  }

  Future<void> _fetchSuppliers() async {
    // Adding debug prints back in case the issue reappears, for diagnosis.
    print('--- DEBUG: Starting supplier fetch... ---');
    try {
      final fetchedSuppliers = await _apiService.fetchSuppliers(); 
      if (mounted) {
        setState(() {
          _suppliers = fetchedSuppliers;
          _isLoadingSuppliers = false;
          print('--- DEBUG: Successfully fetched ${_suppliers.length} suppliers. ---');
        });
      }
    } catch (e) {
      print('--- DEBUG ERROR: Failed to load suppliers: $e ---');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load suppliers: $e')),
        );
        setState(() {
          // IMPORTANT: Set to false so the UI doesn't hang on a spinner
          _isLoadingSuppliers = false;
        });
      }
    }
  }
  
  @override
  void dispose() {
    _nameController.dispose();
    _categoryController.dispose();
    _priceController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    try {
      final plantData = {
        'name': _nameController.text,
        'category': _categoryController.text,
        // Parse the price to a double
        'price': double.tryParse(_priceController.text) ?? 0.0,
        
        // Send the selected supplier ID (will be null if 'None' is selected)
        'supplier_id': _selectedSupplierId, 
      };
      
      if (isEditing) {
        // UPDATE: Send PUT request
        await _apiService.updatePlant(widget.plant!.id, plantData);
      } else {
        // CREATE: Send POST request. Quantity is required for new plants.
        plantData['quantity'] = int.tryParse(_quantityController.text) ?? 0;
        await _apiService.addPlant(plantData);
      }

      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Plant ${isEditing ? "updated" : "added"} successfully!')),
      );
      
      // Notify the previous screen (InventoryScreen) to refresh
      widget.onPlantSaved(); 
      Navigator.pop(context); 
      
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save plant: ${e.toString().replaceFirst('Exception: ', '')}')),
      );
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
                decoration: const InputDecoration(labelText: 'Plant Name *'),
                validator: (value) => (value == null || value.isEmpty) ? 'Please enter a name' : null,
              ),
              const SizedBox(height: 15),

              // Category Field
              TextFormField(
                controller: _categoryController,
                decoration: const InputDecoration(labelText: 'Category *'),
                validator: (value) => (value == null || value.isEmpty) ? 'Please enter a category' : null,
              ),
              const SizedBox(height: 15),

              // Price Field
              TextFormField(
                controller: _priceController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Price (\$)*', hintText: '12.50'),
                validator: (value) {
                  if (value == null || double.tryParse(value) == null) {
                    return 'Please enter a valid price.';
                  }
                  return null;
                },
              ),
              
              const SizedBox(height: 15),

              // --- SUPPLIER DROPDOWN FIELD (WITH VISIBILITY FIX) ---
              if (_isLoadingSuppliers)
                const Center(child: CircularProgressIndicator(strokeWidth: 2))
              else if (_suppliers.isEmpty)
                // If loading is done but list is empty, display a message instead of a hidden dropdown.
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16.0),
                  child: Text(
                    'Note: No suppliers found in the database.',
                    style: TextStyle(color: Colors.orange, fontStyle: FontStyle.italic),
                  ),
                )
              else // If not loading AND suppliers are present, show the full dropdown
                DropdownButtonFormField<int>(
                  decoration: const InputDecoration(
                    labelText: 'Supplier (Optional)',
                    border: OutlineInputBorder(),
                  ),
                  value: _selectedSupplierId,
                  hint: const Text('Select a supplier'),
                  isExpanded: true,
                  items: [
                    // Option for "None" (value: null)
                    const DropdownMenuItem<int>(
                      value: null,
                      child: Text('None (Select to remove)'),
                    ),
                    // Map the list of fetched suppliers to DropdownMenuItems
                    ..._suppliers.map((supplier) {
                      return DropdownMenuItem<int>(
                        value: supplier.id,
                        child: Text(supplier.name),
                      );
                    }).toList(),
                  ],
                  onChanged: (int? newValue) {
                    setState(() {
                      _selectedSupplierId = newValue;
                    });
                  },
                ),
              // --- END SUPPLIER DROPDOWN ---
              
              const SizedBox(height: 15),

              // Quantity Field (Only required/editable in ADD mode)
              if (!isEditing) 
                TextFormField(
                  controller: _quantityController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Initial Quantity (Stock) *'),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Please enter a quantity';
                    if (int.tryParse(value) == null || int.parse(value) < 0) return 'Enter a non-negative whole number.';
                    return null;
                  }
                )
              else 
                // Display current stock when editing
                Padding(
                  padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
                  child: Text('Current Stock: ${widget.plant!.quantity}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              
              const SizedBox(height: 30),

              // Submit Button
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