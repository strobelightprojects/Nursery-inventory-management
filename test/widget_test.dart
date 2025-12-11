// test/widget_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Import your main application file
import 'package:nursery_inventory_app/main.dart' as app; 

void main() {
  // Test to verify the main application loads without crashing and displays the main tabs.
  testWidgets('App loads and displays the main navigation tabs', (WidgetTester tester) async {
    
    // We assume the top-level widget in main.dart is named 'MainApp'.
    // If your widget is named 'MyApp', change 'app.MainApp' to 'app.MyApp'.
    // If your widget has a different name, use that name.
    
    // Build the app widget
    await tester.pumpWidget(const app.MainApp()); // <-- Using app.MainApp as a placeholder

    // Wait for the app to finish its initial rendering (especially important for FutureBuilders)
    await tester.pumpAndSettle();

    // Verify key titles expected on the MainTabScreen
    // These verify that your TabBar/BottomNavigationBar loaded correctly
    expect(find.text('Plant Inventory'), findsOneWidget);
    expect(find.text('Orders'), findsOneWidget);
    expect(find.text('Suppliers'), findsOneWidget);
    
    // Verify the presence of the Add button on the first (Inventory) screen.
    expect(find.byIcon(Icons.add), findsWidgets); 
  });
}