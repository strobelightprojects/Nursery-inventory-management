import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'order_form_screen.dart'; // Screen to create new orders

class OrderListScreen extends StatefulWidget {
  const OrderListScreen({super.key});

  @override
  State<OrderListScreen> createState() => _OrderListScreenState();
}

class _OrderListScreenState extends State<OrderListScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _orders = [];
  bool _isLoading = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _fetchOrders();
  }

  // Fetches the list of orders from the API
  Future<void> _fetchOrders() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });
    try {
      final data = await _apiService.fetchOrders();
      setState(() {
        _orders = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Connection Error: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  // Navigation to the Order Form screen
  void _navigateToCreateOrder() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OrderFormScreen(
          onOrderCreated: _fetchOrders, // Pass callback to refresh list after new order is placed
        ),
      ),
    );
  }
  
  // Handles order deletion (cancellation) and stock reversion
  Future<void> _deleteOrder(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Order Cancellation'),
        content: const Text('Are you sure you want to cancel this order? Stock will be reverted to inventory.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Cancel Order', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _apiService.deleteOrder(id);
        _fetchOrders(); 
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Order cancelled and stock reverted.')));
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Cancellation failed: ${e.toString()}')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Customer Orders'),
        backgroundColor: Colors.blueGrey,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Orders',
            onPressed: _fetchOrders,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error.isNotEmpty
              ? Center(child: Text(_error, style: const TextStyle(color: Colors.red, fontSize: 16)))
              : ListView.builder(
                  itemCount: _orders.length,
                  itemBuilder: (context, index) {
                    final order = _orders[index];
                    // Format the total for display
                    final total = order['total'] != null ? '\$${order['total'].toStringAsFixed(2)}' : 'N/A';
                    
                    // Display the list of ordered items
                    final itemsSummary = (order['items'] as List<dynamic>?)
                        ?.map((item) => '${item['name']} x${item['quantity']}')
                        .join(', ') ?? 'No items';

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.blueGrey,
                          child: Text((index + 1).toString(), style: const TextStyle(color: Colors.white)),
                        ),
                        title: Text('Order for: ${order['customer_name']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Total: $total | Date: ${order['date']?.substring(0, 10) ?? 'N/A'}'),
                            Text('Items: $itemsSummary', style: const TextStyle(fontStyle: FontStyle.italic)),
                          ],
                        ),
                        isThreeLine: true,
                        trailing: IconButton( // Button to cancel (delete) the order
                          icon: const Icon(Icons.cancel, color: Colors.red),
                          onPressed: () => _deleteOrder(order['id']),
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navigateToCreateOrder,
        backgroundColor: Colors.blueGrey,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_shopping_cart),
        label: const Text('New Order'),
      ),
    );
  }
}
