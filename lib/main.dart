import 'package:flutter/material.dart';
import 'package:http/http.dart' as http; // Package for making network calls
import 'dart:convert'; // Package for decoding JSON data

// --- Configuration ---
// This is the local address where your Python API server is running
const String baseUrl = 'http://127.0.0.1:5000';

void main() {
  runApp(const InventoryApp());
}

class InventoryApp extends StatelessWidget {
  const InventoryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nursery Inventory',
      // Define a consistent visual theme
      theme: ThemeData(
        primarySwatch: Colors.green,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        useMaterial3: true,
      ),
      home: const PlantInventoryScreen(),
    );
  }
}

class PlantInventoryScreen extends StatefulWidget {
  const PlantInventoryScreen({super.key});

  @override
  State<PlantInventoryScreen> createState() => _PlantInventoryScreenState();
}

class _PlantInventoryScreenState extends State<PlantInventoryScreen> {
  List<dynamic> _plants = [];
  bool _isLoading = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _fetchPlants(); // Load the data immediately when the screen is created
  }

  // --- API Call to Python Backend ---
  Future<void> _fetchPlants() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      // 1. Send GET request to the Python API
      final response = await http.get(Uri.parse('$baseUrl/plants')); 

      if (response.statusCode == 200) {
        // 2. Success: Decode the JSON array returned by Python (e.g., [{"name": "Rose"}, ...])
        setState(() {
          _plants = jsonDecode(response.body);
          _isLoading = false;
        });
      } else {
        // 3. API returned an error status (e.g., 500 error from Flask)
        setState(() {
          _error = 'Failed to load plants. Status: ${response.statusCode}. Check Python console.';
          _isLoading = false;
        });
      }
    } catch (e) {
      // 4. Connection failed (Python API server not running or network issue)
      setState(() {
        _error = 'Connection Error: Is the Python API server running on $baseUrl?';
        _isLoading = false;
      });
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
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Inventory',
            onPressed: _fetchPlants, // Button to call the API again
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator()) // Shows a spinner while loading
          : _error.isNotEmpty
              ? Center(child: Text(_error, style: const TextStyle(color: Colors.red, fontSize: 16))) // Displays connection errors
              : ListView.builder(
                  itemCount: _plants.length,
                  itemBuilder: (context, index) {
                    final plant = _plants[index];
                    return ListTile(
                      leading: const Icon(Icons.grass, color: Colors.green),
                      title: Text(plant['name'] ?? 'N/A', style: const TextStyle(fontWeight: FontWeight.bold)),
                      // Display stock, price, and supplier data fetched from the JSON
                      subtitle: Text(
                          'Stock: ${plant['quantity']} | Price: \$${plant['price']} | Supplier: ${plant['supplier_name'] ?? 'None'}'),
                      trailing: Text('ID: ${plant['id']}'),
                      onTap: () {
                        // TODO: Implement navigation to a details/edit screen
                      },
                    );
                  },
                ),
    );
  }
}
