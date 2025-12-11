import 'package:flutter/material.dart';
import '../models/plant.dart';
import '../services/api_service.dart';
import 'plant_detail_screen.dart'; 

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final ApiService _apiService = ApiService();
  late Future<List<Plant>> _plantsFuture;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Initialize _plantsFuture by calling _fetchPlants without arguments
    _plantsFuture = _fetchPlants(); 
  }

  // Function to fetch plants, called by initState, search, and navigation
  Future<List<Plant>> _fetchPlants({String? searchTerm}) async {
    try {
      // If no search term is passed, use the current controller text
      final term = searchTerm ?? _searchController.text;
      return await _apiService.fetchPlants(searchTerm: term);
    } catch (e) {
      // Show an error on the screen
      throw Exception('Failed to load inventory: $e');
    }
  }

  void _onSearchChanged(String value) {
    setState(() {
      // This setState triggers a new Future with the search term
      _plantsFuture = _fetchPlants(searchTerm: value);
    });
  }

  void _navigateToDetail({Plant? plant}) async {
    // 🛑 Navigation Fix: Pass the required 'onPlantSaved' argument.
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PlantDetailScreen(
          plant: plant,
          
          // FIX: Pass the required 'onPlantSaved' argument.
          onPlantSaved: () {
            // This callback is executed when the detail screen is popped (after save/update/delete)
            // We use setState here to update _plantsFuture and refresh the list
            setState(() { 
              _plantsFuture = _fetchPlants(searchTerm: _searchController.text);
            });
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Plant Inventory'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56.0),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Search by name or category...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(8.0)),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.white70,
              ),
              onChanged: _onSearchChanged,
            ),
          ),
        ),
      ),
      body: FutureBuilder<List<Plant>>(
        future: _plantsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No plants found in inventory.'));
          } else {
            final plants = snapshot.data!;
            return ListView.builder(
              itemCount: plants.length,
              itemBuilder: (context, index) {
                final plant = plants[index];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                  child: ListTile(
                    title: Hero(
                      // 🚀 HERO FIX: Use the unique plant ID in the tag to prevent the
                      // "multiple heroes with the same tag" exception during transition.
                      tag: 'plant-name-${plant.id}', 
                      child: Text(
                        plant.name, 
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    subtitle: Text(
                      'Category: ${plant.category}\nStock: ${plant.quantity} units\nSupplier: ${plant.supplierName ?? 'N/A'}',
                    ),
                    trailing: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '\$${plant.price.toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                        ),
                        Text(
                          plant.quantity > 0 ? 'In Stock' : 'Out of Stock',
                          style: TextStyle(
                            fontSize: 12,
                            color: plant.quantity > 0 ? Colors.green.shade700 : Colors.red,
                          ),
                        ),
                      ],
                    ),
                    onTap: () => _navigateToDetail(plant: plant),
                  ),
                );
              },
            );
          }
        },
      ),
      floatingActionButton: FloatingActionButton(
        // When adding a new plant, 'plant' is null
        onPressed: () => _navigateToDetail(), 
        tooltip: 'Add New Plant',
        child: const Icon(Icons.add),
      ),
    );
  }
} 