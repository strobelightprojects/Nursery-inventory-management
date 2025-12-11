import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/plant.dart'; // Import Plant model for data

class OrderFormScreen extends StatefulWidget {
  final VoidCallback onOrderCreated;

  const OrderFormScreen({super.key, required this.onOrderCreated});

  @override
  State<OrderFormScreen> createState() => _OrderFormScreenState();
}

class _OrderFormScreenState extends State<OrderFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final ApiService _apiService = ApiService();

  // Controllers for form fields
  final TextEditingController _customerNameController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  
  // State for selecting a plant
  List<Plant> _availablePlants = [];
  Plant? _selectedPlant;
  bool _isLoading = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _fetchAvailablePlants();
  }

  // Fetch the inventory so the user can choose a product
  Future<void> _fetchAvailablePlants() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });
    try {
      final data = await _apiService.fetchPlants();
      setState(() {
        // Convert API response (List<dynamic>) to List<Plant> objects
        _availablePlants = data.map((json) => Plant.fromJson(json)).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load plants: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _submitOrder() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_selectedPlant == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a plant to order.')),
      );
      return;
    }

    try {
      final quantity = int.parse(_quantityController.text);
      
      // Structure the data according to the backend's POST /orders expectation
      final orderData = {
        'customer_name': _customerNameController.text,
        'notes': _notesController.text,
        'items': [
          {
            'product_id': _selectedPlant!.id,
            'quantity': quantity,
            'price': _selectedPlant!.price, // Use current plant price
          },
        ],
      };

      // Call the API's createOrder function (needs to be added to api_service.dart)
      // NOTE: We will add the `createOrder` method to `api_service.dart` below.
      await _apiService.createOrder(orderData); 
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order placed successfully! Stock updated.')),
      );
      
      widget.onOrderCreated(); // Notify the order list screen to refresh
      Navigator.pop(context); 
      
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to place order: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create New Order'),
        backgroundColor: Colors.blueGrey,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error.isNotEmpty
              ? Center(child: Text(_error, style: const TextStyle(color: Colors.red, fontSize: 16)))
              : Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: <Widget>[
                        // Customer Name
                        TextFormField(
                          controller: _customerNameController,
                          decoration: const InputDecoration(labelText: 'Customer Name'),
                          validator: (value) => value!.isEmpty ? 'Enter customer name' : null,
                        ),
                        
                        // Plant Selection Dropdown
                        DropdownButtonFormField<Plant>(
                          decoration: const InputDecoration(labelText: 'Select Plant'),
                          value: _selectedPlant,
                          items: _availablePlants.map((plant) {
                            return DropdownMenuItem<Plant>(
                              value: plant,
                              child: Text('${plant.name} (Stock: ${plant.quantity})'),
                            );
                          }).toList(),
                          onChanged: (Plant? newValue) {
                            setState(() {
                              _selectedPlant = newValue;
                              _quantityController.clear(); // Clear quantity when plant changes
                            });
                          },
                          validator: (value) => value == null ? 'Please select a plant' : null,
                        ),

                        // Quantity Input
                        TextFormField(
                          controller: _quantityController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Quantity to Order',
                            hintText: 'Max: ${_selectedPlant?.quantity ?? 0}',
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) return 'Enter quantity';
                            final qty = int.tryParse(value);
                            if (qty == null || qty <= 0) return 'Enter a valid quantity';
                            if (_selectedPlant != null && qty > _selectedPlant!.quantity) {
                              return 'Only ${_selectedPlant!.quantity} in stock';
                            }
                            return null;
                          },
                        ),
                        
                        // Notes
                        TextFormField(
                          controller: _notesController,
                          decoration: const InputDecoration(labelText: 'Order Notes (Optional)'),
                          maxLines: 3,
                        ),
                        
                        const SizedBox(height: 30),

                        ElevatedButton.icon(
                          onPressed: _submitOrder,
                          icon: const Icon(Icons.shopping_cart),
                          label: const Text('Place Order'),
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size.fromHeight(50),
                            backgroundColor: Colors.blueGrey,
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
