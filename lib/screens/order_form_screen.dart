// lib/screens/order_form_screen.dart
import 'package:flutter/material.dart';
import '../models/plant.dart';
import '../services/api_service.dart';

// Helper class to manage a single item in the cart state
class CartItem {
  final Plant plant;
  int quantity;

  CartItem(this.plant, this.quantity);

  double get lineTotal => plant.price * quantity;
}

class OrderFormScreen extends StatefulWidget {
  const OrderFormScreen({super.key});

  @override
  State<OrderFormScreen> createState() => _OrderFormScreenState();
}

class _OrderFormScreenState extends State<OrderFormScreen> {
  final ApiService _apiService = ApiService();
  
  // NOTE: This future now correctly expects List<Plant>
  late Future<List<Plant>> _plantsFuture;
  
  final TextEditingController _customerNameController = TextEditingController();
  final List<CartItem> _cart = [];
  Plant? _selectedPlant;

  @override
  void initState() {
    super.initState();
    // Start fetching plants when the screen initializes
    _plantsFuture = _fetchPlants(); 
  }

  // Separate function to handle the fetch operation
  Future<List<Plant>> _fetchPlants() async {
    try {
      // The ApiService now returns the fully typed List<Plant>
      return await _apiService.fetchPlants(); 
    } catch (e) {
      // Re-throw the error to be caught by the FutureBuilder
      throw Exception('Failed to load plants for order: $e');
    }
  }

  @override
  void dispose() {
    _customerNameController.dispose();
    super.dispose();
  }

  double get _totalOrderAmount {
    return _cart.fold(0.0, (sum, item) => sum + item.lineTotal);
  }

  void _addItemToCart(Plant plant, int quantity) {
    setState(() {
      // Check if item is already in cart
      final existingItemIndex = _cart.indexWhere((item) => item.plant.id == plant.id);
      
      if (existingItemIndex >= 0) {
        // If exists, update quantity, ensuring it doesn't exceed stock
        if (_cart[existingItemIndex].quantity + quantity <= plant.quantity) {
             _cart[existingItemIndex].quantity += quantity;
        } else {
             _showSnackbar('Cannot add that many. Reached maximum stock for ${plant.name}.', Colors.orange);
        }
      } else {
        // If new, add to cart
        _cart.add(CartItem(plant, quantity));
      }
      _selectedPlant = null; // Reset selection after adding
    });
  }

  void _updateCartItemQuantity(int index, int newQuantity) {
    setState(() {
      if (newQuantity <= 0) {
        // Remove item if quantity is zero or less
        _cart.removeAt(index);
      } else if (newQuantity <= _cart[index].plant.quantity) {
        // Update quantity if it doesn't exceed available stock
        _cart[index].quantity = newQuantity;
      }
    });
  }

  Future<void> _submitOrder() async {
    if (_customerNameController.text.isEmpty) {
      _showSnackbar('Please enter a customer name.', Colors.red);
      return;
    }
    if (_cart.isEmpty) {
      _showSnackbar('The order is empty. Add plants to the cart.', Colors.red);
      return;
    }

    // Build the payload expected by the Flask API
    final List<Map<String, int>> itemsPayload = _cart.map((item) => {
      'product_id': item.plant.id,
      'quantity': item.quantity,
    }).toList();

    try {
      // The createOrder method expects a Map, so we build it here.
      await _apiService.createOrder({
        'customer_name': _customerNameController.text,
        'items': itemsPayload,
      });

      // On success: clear form and notify user
      setState(() {
        _customerNameController.clear();
        _cart.clear();
      });

      _showSnackbar('Order successfully placed!', Colors.green);
      // Pass 'true' to signal the list screen to refresh.
      if (mounted) Navigator.pop(context, true); 

    } catch (e) {
      // This catches the specific stock/database error from the API
      _showSnackbar('Error placing order: ${e.toString().replaceFirst('Exception: ', '')}', Colors.red);
    }
  }

  void _showSnackbar(String message, Color color) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: color),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Place New Order'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // 1. Customer Name Input
            TextField(
              controller: _customerNameController,
              decoration: const InputDecoration(
                labelText: 'Customer Name',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
            ),
            
            const SizedBox(height: 20),
            const Text('Add Items', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Divider(),

            // 2. Plant Selector and Quantity Input
            FutureBuilder<List<Plant>>(
              future: _plantsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return Center(child: Text('Error loading plants: ${snapshot.error}'));
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('No plants available to order.'));
                } else {
                  final plants = snapshot.data!;
                  return Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<Plant>(
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            labelText: 'Select Plant',
                          ),
                          value: _selectedPlant,
                          // The 'plants' list is already List<Plant>, so map works directly.
                          items: plants.map((plant) {
                            return DropdownMenuItem<Plant>(
                              value: plant,
                              child: Text('${plant.name} (Stock: ${plant.quantity})'),
                            );
                          }).toList(),
                          onChanged: (Plant? newValue) {
                            setState(() {
                              _selectedPlant = newValue;
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Add Item Button
                      SizedBox(
                        height: 58,
                        child: ElevatedButton(
                          onPressed: _selectedPlant == null 
                            ? null 
                            : () {
                                if (_selectedPlant!.quantity <= 0) {
                                  _showSnackbar('Cannot order. ${'${_selectedPlant!.name}'} is out of stock.', Colors.orange);
                                } else {
                                  _addItemToCart(_selectedPlant!, 1);
                                }
                              },
                          child: const Text('Add 1'),
                        ),
                      ),
                    ],
                  );
                }
              },
            ),

            const SizedBox(height: 30),
            const Text('Order Cart', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Divider(),

            // 3. Cart Display and Editor
            _cart.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.only(top: 20),
                      child: Text('Cart is empty.'),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _cart.length,
                    itemBuilder: (context, index) {
                      final item = _cart[index];
                      // Check the available stock on the item's plant object
                      final maxQuantity = item.plant.quantity;
                      final canAddMore = item.quantity < maxQuantity;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          title: Text('${item.plant.name} - \$${item.plant.price.toStringAsFixed(2)}'),
                          subtitle: Text('Total: \$${item.lineTotal.toStringAsFixed(2)}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Subtract Button
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                                onPressed: () => _updateCartItemQuantity(index, item.quantity - 1),
                              ),
                              Text('${item.quantity}', style: const TextStyle(fontWeight: FontWeight.bold)),
                              // Add Button (Stock check handled by max quantity)
                              IconButton(
                                icon: Icon(Icons.add_circle_outline, color: canAddMore ? Colors.green : Colors.grey),
                                onPressed: canAddMore
                                  ? () => _updateCartItemQuantity(index, item.quantity + 1)
                                  : null,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),

            const SizedBox(height: 30),

            // 4. Total and Submission Button
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('ORDER TOTAL:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Text('\$${_totalOrderAmount.toStringAsFixed(2)}', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green.shade800)),
                ],
              ),
            ),
            
            const SizedBox(height: 20),

            ElevatedButton.icon(
              onPressed: _submitOrder,
              icon: const Icon(Icons.send),
              label: const Text('Submit Order', style: TextStyle(fontSize: 18)),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 15),
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
