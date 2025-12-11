import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'plant_form_screen.dart'; // Used for both Add and Edit
import '../models/plant.dart'; // Used for type conversion

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _plants = [];
  bool _isLoading = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _fetchPlants();
  }

  Future<void> _fetchPlants() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });
    try {
      // NOTE: We will integrate search functionality here later if needed
      final data = await _apiService.fetchPlants(); 
      setState(() {
        _plants = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Connection Error: ${e.toString()}';
        _isLoading = false;
      });
    }
  }
  
  // Navigation to the Add Plant screen
  void _navigateToAddPlant() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PlantFormScreen(
          onPlantSaved: _fetchPlants, 
        ),
      ),
    );
  }
  
  // Navigation to the Edit Plant form
  void _navigateToEditPlant(Map<String, dynamic> plantData) {
    // Convert the map into a Plant object before passing it
    final plant = Plant.fromJson(plantData); 
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PlantFormScreen(
          onPlantSaved: _fetchPlants, 
          plant: plant, // Pass the existing plant data to enable Edit Mode
        ),
      ),
    );
  }

// Method to handle plant deletion
  Future<void> _deletePlant(int id, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Deletion'),
        content: Text('Are you sure you want to permanently delete "$name"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _apiService.deletePlant(id);
        _fetchPlants();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Plant deleted.')));
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete: ${e.toString()}')));
      }
    }
  }

// Method to handle restock action
  Future<void> _showRestockDialog(int id, String name, int currentQty) async {
    final quantityController = TextEditingController();
    
    final confirmed = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Restock "$name"'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Current Stock: $currentQty'),
            TextFormField(
              controller: quantityController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Quantity to Add'),
              validator: (value) {
                if (value == null || int.tryParse(value) == null || int.parse(value) <= 0) {
                  return 'Enter a positive number';
                }
                return null;
              },
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, null), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              final qty = int.tryParse(quantityController.text);
              if (qty != null && qty > 0) {
                Navigator.pop(context, qty);
              }
            }, 
            child: const Text('Restock', style: TextStyle(color: Colors.green))),
        ],
      ),
    );

    if (confirmed != null) {
      try {
        final result = await _apiService.restockPlant(id, confirmed);
        _fetchPlants();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Restocked! New Qty: ${result['new_quantity']}')));
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Restock failed: ${e.toString()}')));
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Plant Inventory'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add New Plant',
            onPressed: _navigateToAddPlant, 
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Inventory',
            onPressed: _fetchPlants,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error.isNotEmpty
              ? Center(child: Text(_error, style: const TextStyle(color: Colors.red, fontSize: 16)))
              : ListView.builder(
                  itemCount: _plants.length,
                  itemBuilder: (context, index) {
                    final plant = _plants[index];
                    return ListTile(
                      leading: const Icon(Icons.grass, color: Colors.green),
                      title: Text(plant['name'] ?? 'N/A', style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(
                          'Stock: ${plant['quantity']} | Price: \$${plant['price']} | Supplier: ${plant['supplier_name'] ?? 'None'}'),
                      
                      // Action Menu for CRUD Operations
                      trailing: PopupMenuButton<String>(
                        onSelected: (String action) {
                          if (action == 'edit') {
                            _navigateToEditPlant(plant);
                          } else if (action == 'restock') {
                            _showRestockDialog(plant['id'], plant['name'], plant['quantity']);
                          } else if (action == 'delete') {
                            _deletePlant(plant['id'], plant['name']);
                          }
                        },
                        itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                          const PopupMenuItem<String>(
                            value: 'edit',
                            child: Row(children: [Icon(Icons.edit, color: Colors.blue), SizedBox(width: 8), Text('Edit Details')]),
                          ),
                          const PopupMenuItem<String>(
                            value: 'restock',
                            child: Row(children: [Icon(Icons.inventory, color: Colors.green), SizedBox(width: 8), Text('Restock')]),
                          ),
                          const PopupMenuItem<String>(
                            value: 'delete',
                            child: Row(children: [Icon(Icons.delete, color: Colors.red), SizedBox(width: 8), Text('Delete Plant')]),
                          ),
                        ],
                      ),

                      // Tapping the tile also goes to edit
                      onTap: () => _navigateToEditPlant(plant), 
                    );
                  },
                ),
    );
  }
}
