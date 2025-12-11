import 'package:flutter/material.dart';
import '../models/order.dart';
import '../services/api_service.dart';
import 'order_form_screen.dart'; // The screen that places the order

class OrderListScreen extends StatefulWidget {
  const OrderListScreen({super.key});

  @override
  State<OrderListScreen> createState() => _OrderListScreenState();
}

class _OrderListScreenState extends State<OrderListScreen> {
  late Future<List<Order>> _ordersFuture;
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _ordersFuture = _fetchOrders();
  }

  Future<List<Order>> _fetchOrders() async {
    try {
      // ApiService now returns the strongly typed List<Order>
      return await _apiService.fetchOrders();
    } catch (e) {
      throw Exception('Failed to load orders: $e');
    }
  }

  // CRITICAL FIX: Removed the undefined 'onOrderCreated' parameter.
  // We use the return value (result) of Navigator.push instead.
  void _navigateToAddOrder() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const OrderFormScreen(),
      ),
    );

    // If result is 'true' (which OrderFormScreen sends on success), refresh the list.
    if (result == true) {
      setState(() {
        _ordersFuture = _fetchOrders();
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Order placed and list refreshed!')),
        );
      }
    }
  }

  void _deleteOrder(int orderId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Order Cancellation'),
        content: const Text(
            'Are you sure you want to cancel this order? Stock will be reverted to inventory.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep Order')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Cancel Order', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _apiService.deleteOrder(orderId);
        setState(() {
          _ordersFuture = _fetchOrders(); // Refresh the list
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Order cancelled and stock reverted successfully!')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
          );
        }
      }
    }
  }

  // Helper method to display detailed items of an order
  void _showOrderDetails(Order order) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Order #${order.id} Details'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: [
              Text('Customer: ${order.customerName}', style: const TextStyle(fontWeight: FontWeight.bold)),
              Text('Date: ${order.date.substring(0, 10)}'),
              const Divider(),
              const Text('Items:', style: TextStyle(fontWeight: FontWeight.bold)),
              ...order.items.map((item) => ListTile(
                    title: Text('${item.productName}'),
                    trailing: Text(
                      '${item.quantity} x \$${item.priceAtSale.toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    dense: true,
                  )),
              const Divider(),
              Text('TOTAL: \$${order.total.toStringAsFixed(2)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Customer Orders'),
      ),
      body: FutureBuilder<List<Order>>(
        future: _ordersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No orders found. Tap + to create a new one!'));
          } else {
            final orders = snapshot.data!.reversed.toList(); // Display newest first
            return ListView.builder(
              itemCount: orders.length,
              itemBuilder: (context, index) {
                final order = orders[index];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.green,
                      child: Text('#${order.id}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                    title: Text(order.customerName, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('Date: ${order.date.substring(0, 10)} | Items: ${order.items.length}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('\$${order.total.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                        IconButton(
                          icon: const Icon(Icons.cancel, color: Colors.red),
                          onPressed: () => _deleteOrder(order.id),
                        ),
                      ],
                    ),
                    onTap: () => _showOrderDetails(order),
                  ),
                );
              },
            );
          }
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToAddOrder,
        tooltip: 'Place New Order',
        child: const Icon(Icons.add),
      ),
    );
  }
}
