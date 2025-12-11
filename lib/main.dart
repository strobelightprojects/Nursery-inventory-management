import 'package:flutter/material.dart';
import 'screens/inventory_screen.dart'; 
import 'screens/order_list_screen.dart'; // Import the new screen

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
      // Set the home to the new MainNavigator widget
      home: const MainNavigator(), 
    );
  }
}

// New Widget to handle bottom navigation
class MainNavigator extends StatefulWidget {
  const MainNavigator({super.key});

  @override
  State<MainNavigator> createState() => _MainNavigatorState();
}

class _MainNavigatorState extends State<MainNavigator> {
  int _selectedIndex = 0;

  // List of screens for the navigation bar
  static const List<Widget> _screens = <Widget>[
    InventoryScreen(), // Index 0: Plant Inventory
    OrderListScreen(),  // Index 1: Customer Orders
    // TODO: Add SupplierListScreen here at Index 2
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // The current screen is displayed here
      body: _screens.elementAt(_selectedIndex), 
      
      // Bottom Navigation Bar for switching views
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.grass),
            label: 'Inventory',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt),
            label: 'Orders',
          ),
          // TODO: Add Suppliers Item here
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.green[800],
        onTap: _onItemTapped,
      ),
    );
  }
}
