import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'plant_form_screen.dart'; // Import the new form screen

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
          onPlantAdded: _fetchPlants, // Pass callback to refresh list when done
        ),
      ),
    );
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
                      trailing: const Icon(Icons.edit),
                      onTap: () {
                        // TODO: Navigate to Edit Plant Screen
                      },
                    );
                  },
                ),
      // Floating Action Button to navigate to the Add Plant form
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToAddPlant,
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        tooltip: 'Add New Plant',
        child: const Icon(Icons.add),
      ),
    );
  }
}
