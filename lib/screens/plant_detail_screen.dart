import 'package:flutter/material.dart';
import '../models/plant.dart';
import '../models/supplier.dart';
import '../services/api_service.dart';

class PlantDetailScreen extends StatefulWidget {
  // Null when adding a new plant
  final Plant? plant; 
  // CRITICAL: Callback to tell the parent screen (Inventory) to refresh
  final VoidCallback onPlantSaved; 

  const PlantDetailScreen({
    super.key, 
    this.plant,
    required this.onPlantSaved,
  });

  @override
  State<PlantDetailScreen> createState() => _PlantDetailScreenState();
}

class _PlantDetailScreenState extends State<PlantDetailScreen> {
  final _formKey = GlobalKey<FormState>();
  final ApiService _apiService = ApiService();
  
  // Controllers for form fields
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _categoryController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _restockQuantityController = TextEditingController();
  final TextEditingController _initialQuantityController = TextEditingController();

  // State for Supplier connection
  List<Supplier> _suppliers = []; // List to hold all suppliers
  int? _selectedSupplierId; // State for the selected supplier ID (int or null)
  bool _isLoadingSuppliers = true; // Loading state

  bool get isEditing => widget.plant != null;
  int _currentQuantity = 0; 

  @override
  void initState() {
    super.initState();
    _fetchSuppliers(); // Call the method to load suppliers

    // Pre-fill fields if in editing mode
    if (isEditing) {
      final p = widget.plant!;
      _nameController.text = p.name;
      _categoryController.text = p.category;
      _priceController.text = p.price.toStringAsFixed(2); 
      _currentQuantity = p.quantity; 
      
      // Initialize the selected supplier ID from the plant object
      _selectedSupplierId = p.supplierId;
    }
  }

  // Method to fetch all available suppliers
  Future<void> _fetchSuppliers() async {
    print('--- DEBUG: Starting supplier fetch... ---');
    try {
      final fetchedSuppliers = await _apiService.fetchSuppliers();
      if (mounted) {
        setState(() {
          _suppliers = fetchedSuppliers; 
          _isLoadingSuppliers = false;
          print('--- DEBUG: SUCCESS! Fetched ${fetchedSuppliers.length} suppliers. ---');
        });
      }
    } catch (e) {
      print('--- DEBUG ERROR: FAILED to load suppliers: $e ---');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load suppliers: $e')),
        );
        setState(() {
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
    _initialQuantityController.dispose();
    _restockQuantityController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    _formKey.currentState!.save();

    final Map<String, dynamic> plantData = {
      'name': _nameController.text,
      'category': _categoryController.text,
      'price': double.tryParse(_priceController.text) ?? 0.0,
      'supplier_id': _selectedSupplierId, 
    };
    
    if (!isEditing) {
      plantData['quantity'] = int.tryParse(_initialQuantityController.text) ?? 0;
    }

    try {
      if (isEditing) {
        await _apiService.updatePlant(widget.plant!.id, plantData);
      } else {
        await _apiService.addPlant(plantData);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Plant ${isEditing ? "updated" : "added"} successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        widget.onPlantSaved(); 
        Navigator.pop(context); 
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving plant: ${e.toString().replaceFirst('Exception: ', '')}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _restockPlant() async {
    if (!isEditing) return;

    final quantityText = _restockQuantityController.text.trim();
    final quantity = int.tryParse(quantityText);

    if (quantity == null || quantity == 0) { 
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a valid restock quantity (whole number ≠ 0).')),
        );
      }
      return;
    }

    try {
      final Map<String, dynamic> result = await _apiService.restockPlant(widget.plant!.id, quantity);
      final int newQuantity = result['new_quantity'];

      if (mounted) {
        setState(() {
          _currentQuantity = newQuantity; 
          _restockQuantityController.clear(); 
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${quantity > 0 ? "Restocked" : "Removed"} ${quantity.abs()} units. New stock: $newQuantity units.'),
            backgroundColor: Colors.blue,
          ),
        );
        widget.onPlantSaved();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Restock Error: ${e.toString().replaceFirst('Exception: ', '')}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  void _deletePlant() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Deletion'),
        content: Text('Are you sure you want to delete ${widget.plant!.name}? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _apiService.deletePlant(widget.plant!.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Plant deleted successfully!')),
          );
          widget.onPlantSaved();
          Navigator.pop(context); 
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Delete Error: ${e.toString().replaceFirst('Exception: ', '')}')),
          );
        }
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    // Determine the title widget, wrapped in Hero if editing
    Widget titleWidget = Text(isEditing ? 'Edit ${widget.plant!.name}' : 'Add New Plant');
    
    if (isEditing) {
      titleWidget = Hero(
        // Match the tag used in InventoryScreen.dart
        tag: 'plant-name-${widget.plant!.id}', 
        child: titleWidget, 
      );
    }

    return Scaffold(
      appBar: AppBar(
        // Use the title widget defined above
        title: titleWidget,
        actions: isEditing ? [
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: _deletePlant,
            tooltip: 'Delete Plant',
          ),
        ] : null,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // --- Current Stock & Restock Section (Editing Mode Only) ---
              if (isEditing) ...[
                Card(
                  color: Colors.lightGreen.shade50,
                  elevation: 0,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Current Stock:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        Text(
                          '$_currentQuantity units',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _currentQuantity > 0 ? Colors.green.shade800 : Colors.red),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _restockQuantityController,
                        decoration: const InputDecoration(
                          labelText: 'Restock Quantity (e.g., 5 or -5)',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                            if (value != null && value.isNotEmpty) {
                              if (int.tryParse(value) == null) {
                                return 'Enter a whole number.';
                              }
                            }
                            return null;
                          },
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      height: 58,
                      child: ElevatedButton(
                        onPressed: _restockPlant,
                        child: const Text('Update Stock', style: TextStyle(fontSize: 16)),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 40),
                Text('Edit Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
                const SizedBox(height: 10),
              ],


              // --- Main Form Fields ---
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Plant Name *'),
                validator: (value) => (value == null || value.isEmpty) ? 'Enter a plant name.' : null,
              ),
              const SizedBox(height: 15),

              TextFormField(
                controller: _categoryController,
                decoration: const InputDecoration(labelText: 'Category (e.g., Tree, Shrub, Flower) *'),
                validator: (value) => (value == null || value.isEmpty) ? 'Enter a category.' : null,
              ),
              const SizedBox(height: 15),

              TextFormField(
                controller: _priceController,
                decoration: const InputDecoration(labelText: 'Price (\$)*'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value == null || double.tryParse(value) == null) {
                    return 'Enter a valid price.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 15),

              // --- SUPPLIER DROPDOWN FIELD (CRITICAL FIX APPLIED HERE) ---
              if (_isLoadingSuppliers)
                const Center(child: CircularProgressIndicator(strokeWidth: 2))
              else if (_suppliers.isEmpty)
                // 🛑 FIX: Show a message if loading is done but the list is empty
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16.0),
                  child: Text(
                    'Note: No suppliers found. Please add suppliers to the database.',
                    style: TextStyle(color: Colors.orange, fontStyle: FontStyle.italic),
                  ),
                )
              else
                // Show the dropdown only if suppliers are loaded AND present
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

              // Initial Quantity Field (Add Mode Only)
              if (!isEditing) ...[
                TextFormField(
                  controller: _initialQuantityController,
                  decoration: const InputDecoration(labelText: 'Initial Quantity *'),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || int.tryParse(value) == null || int.parse(value) < 0) {
                      return 'Enter a non-negative whole number for quantity.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 15),
              ],
              
              // Submit Button
              ElevatedButton.icon(
                onPressed: _submitForm,
                icon: Icon(isEditing ? Icons.save : Icons.add),
                label: Text(isEditing ? 'Save Details' : 'Create Plant Entry'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  backgroundColor: isEditing ? Colors.green.shade700 : Colors.green,
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