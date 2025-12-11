import 'package:flutter/material.dart';
import 'screens/inventory_screen.dart'; // Use the new dedicated screen

// --- Configuration ---
// Removed baseUrl definition here; it is now in api_service.dart

void main() {
  runApp(const InventoryApp());
}

class InventoryApp extends StatelessWidget {
  const InventoryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nursery Inventory',
      theme: ThemeData(
        primarySwatch: Colors.green,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        useMaterial3: true,
      ),
      // The home is now the InventoryScreen
      home: const InventoryScreen(), 
    );
  }
}
