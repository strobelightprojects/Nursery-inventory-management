from flask import Flask, jsonify, request
import sqlite3
import os
import json # Explicitly import if needed, though usually handled by Flask/sqlite3 conversion

# --- Configuration ---
DB_NAME = "nursery.db"
app = Flask(__name__)
# Prevents JSON keys from being sorted alphabetically, making output cleaner
app.config['JSON_SORT_KEYS'] = False 

# --- Basic Check ---
if not os.path.exists(DB_NAME):
    # This check runs when the API starts.
    print(f"ERROR: Database file '{DB_NAME}' not found. Please run your original app once to create it.")

# -------------------------------
# Database Connection Helper
# -------------------------------
def get_db_connection():
    """Returns a new SQLite connection with Foreign Keys enabled."""
    conn = sqlite3.connect(DB_NAME)
    # Allows fetching results by column name (e.g., row['name'])
    conn.row_factory = sqlite3.Row 
    # Must be ON for constraints to work
    conn.execute("PRAGMA foreign_keys = ON")
    return conn

# -------------------------------
# 1. PLANT CRUD ENDPOINTS
# -------------------------------

@app.route('/plants', methods=['GET'])
def get_plants():
    """Returns a list of all products (plants), supports optional search query."""
    try:
        conn = get_db_connection()
        
        # SQL query to join products and suppliers for a complete list
        plants = conn.execute("""
            SELECT p.*, s.name AS supplier_name
            FROM products p
            LEFT JOIN suppliers s ON p.supplier_id = s.id
        """).fetchall()
        
        conn.close()
        
        # Implement search filter based on query parameter from Flutter (e.g., /plants?search=rose)
        search_term = request.args.get('search', '').strip()
        plant_list = [dict(row) for row in plants]
        
        if search_term:
            plant_list = [p for p in plant_list if search_term.lower() in p['name'].lower()]
        
        return jsonify(plant_list), 200 # 200 OK
        
    except Exception as e:
        return jsonify({"error": str(e)}), 500 # 500 Internal Server Error

@app.route('/plants', methods=['POST'])
def add_plant():
    """Receives JSON data from Flutter to add a new plant."""
    data = request.json
    
    # Check for core required fields
    if not all(key in data for key in ['name', 'category', 'price', 'quantity']):
        return jsonify({"error": "Missing required fields: name, category, price, quantity."}), 400

    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        
        cursor.execute("""
            INSERT INTO products 
            (name, category, price, cost_price, quantity, reorder_at, supplier_id, image_path)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        """, (data.get('name'), data.get('category'), data.get('price'), data.get('cost_price'), 
              data.get('quantity'), data.get('reorder_at'), data.get('supplier_id'), 
              data.get('image_path')))
        
        conn.commit()
        conn.close()
        
        return jsonify({"message": "Plant added successfully", "id": cursor.lastrowid}), 201 # 201 Created
        
    except Exception as e:
        return jsonify({"error": f"Database error: {e}"}), 500

@app.route('/plants/<int:plant_id>', methods=['PUT'])
def update_plant(plant_id):
    """Receives JSON data to update an existing plant by ID."""
    data = request.json
    
    if not data:
        return jsonify({"error": "No update data provided"}), 400

    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        
        set_clauses = []
        params = []
        allowed_fields = ['name', 'category', 'description', 'sku', 'price', 'cost_price', 
                          'quantity', 'reorder_at', 'supplier_id', 'image_path']
                          
        for field in allowed_fields:
            if field in data:
                set_clauses.append(f"{field} = ?")
                params.append(data[field])

        if not set_clauses:
            return jsonify({"error": "No valid fields to update"}), 400

        query = f"UPDATE products SET {', '.join(set_clauses)} WHERE id = ?"
        params.append(plant_id)
        
        cursor.execute(query, tuple(params))
        conn.commit()
        
        if cursor.rowcount == 0:
            return jsonify({"error": "Plant not found"}), 404 # 404 Not Found
            
        conn.close()
        return jsonify({"message": "Plant updated successfully"}), 200
        
    except Exception as e:
        return jsonify({"error": f"Database error: {e}"}), 500

@app.route('/plants/<int:plant_id>', methods=['DELETE'])
def delete_plant(plant_id):
    """Deletes a plant by ID."""
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        
        cursor.execute("DELETE FROM products WHERE id = ?", (plant_id,))
        conn.commit()
        
        if cursor.rowcount == 0:
            return jsonify({"error": "Plant not found"}), 404
            
        conn.close()
        return jsonify({"message": "Plant deleted successfully"}), 200
        
    except Exception as e:
        return jsonify({"error": f"Database error: {e}"}), 500


# -------------------------------
# 2. SUPPLIER CRUD ENDPOINTS
# -------------------------------

@app.route('/suppliers', methods=['GET'])
def get_suppliers():
    """Returns a list of all suppliers."""
    try:
        conn = get_db_connection()
        suppliers = conn.execute("SELECT * FROM suppliers").fetchall()
        conn.close()
        
        return jsonify([dict(row) for row in suppliers]), 200
        
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/suppliers', methods=['POST'])
def add_supplier():
    """Receives JSON data to add a new supplier."""
    data = request.json
    
    if not all(key in data for key in ['name', 'email']):
        return jsonify({"error": "Missing required fields: name and email"}), 400

    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        
        cursor.execute("""
            INSERT INTO suppliers (name, contact_person, email, phone, address)
            VALUES (?, ?, ?, ?, ?)
        """, (data.get('name'), data.get('contact_person'), data.get('email'), 
              data.get('phone'), data.get('address')))
        
        conn.commit()
        conn.close()
        
        return jsonify({"message": "Supplier added successfully", "id": cursor.lastrowid}), 201
        
    except sqlite3.IntegrityError:
        return jsonify({"error": "Supplier name already exists."}), 409 # 409 Conflict
    except Exception as e:
        return jsonify({"error": f"Database error: {e}"}), 500

@app.route('/suppliers/<int:supplier_id>', methods=['DELETE'])
def delete_supplier(supplier_id):
    """Deletes a supplier by ID, checking for linked products."""
    try:
        conn = get_db_connection()
        
        # Check for linked products (Integrity Check)
        linked_products = conn.execute("SELECT COUNT(*) FROM products WHERE supplier_id=?", (supplier_id,)).fetchone()[0]
        if linked_products > 0:
            conn.close()
            return jsonify({"error": f"Supplier is linked to {linked_products} products and cannot be deleted."}), 409
            
        cursor = conn.cursor()
        cursor.execute("DELETE FROM suppliers WHERE id = ?", (supplier_id,))
        conn.commit()
        
        if cursor.rowcount == 0:
            conn.close()
            return jsonify({"error": "Supplier not found"}), 404
            
        conn.close()
        return jsonify({"message": "Supplier deleted successfully"}), 200
        
    except Exception as e:
        return jsonify({"error": f"Database error: {e}"}), 500


# -------------------------------
# 3. INVENTORY & RESTOCK ENDPOINTS
# -------------------------------

@app.route('/inventory/restock', methods=['POST'])
def restock_product():
    """Receives product_id and quantity to increase stock."""
    data = request.json
    product_id = data.get('product_id')
    quantity_to_add = data.get('quantity')
    
    if not all([product_id, quantity_to_add]):
        return jsonify({"error": "Missing product_id or quantity."}), 400

    try:
        quantity_to_add = int(quantity_to_add)
        if quantity_to_add <= 0:
            return jsonify({"error": "Quantity must be positive."}), 400

        conn = get_db_connection()
        cursor = conn.cursor()
        
        # 1. Update the quantity
        cursor.execute("""
            UPDATE products SET quantity = quantity + ? WHERE id = ?
        """, (quantity_to_add, product_id))
        
        if cursor.rowcount == 0:
            conn.close()
            return jsonify({"error": "Product not found."}), 404
            
        conn.commit()
        
        # 2. Fetch the new stock level to return to the client
        new_quantity = conn.execute("SELECT quantity FROM products WHERE id=?", (product_id,)).fetchone()[0]
        
        conn.close()
        return jsonify({
            "message": "Product restocked successfully.", 
            "new_quantity": new_quantity
        }), 200
        
    except ValueError:
        return jsonify({"error": "Quantity must be an integer."}), 400
    except Exception as e:
        return jsonify({"error": f"Database error during restock: {e}"}), 500


# -------------------------------
# 4. ORDER MANAGEMENT ENDPOINTS
# -------------------------------

@app.route('/orders', methods=['POST'])
def create_order():
    """Creates a new order and decreases stock for ordered items."""
    data = request.json
    customer_name = data.get('customer_name')
    notes = data.get('notes', '')
    items = data.get('items') # List of {'product_id': 1, 'quantity': 5, 'price': 12.50}
    
    if not customer_name or not items:
        return jsonify({"error": "Missing customer name or order items."}), 400

    conn = get_db_connection()
    cursor = conn.cursor()
    total = 0

    try:
        # Start transaction to ensure stock and order insertion are atomic
        conn.begin() 
        
        # 1. Check stock and calculate total
        for item in items:
            product_id = item['product_id']
            quantity_ordered = item['quantity']
            item_price = item['price'] # Use the price sent by the client for the transaction record
            
            total += quantity_ordered * item_price
            
            # Check current stock
            stock_row = cursor.execute("SELECT quantity FROM products WHERE id=?", (product_id,)).fetchone()
            if not stock_row:
                conn.rollback()
                return jsonify({"error": f"Product ID {product_id} not found."}), 404

            current_stock = stock_row[0]
            if current_stock < quantity_ordered:
                conn.rollback()
                return jsonify({"error": f"Insufficient stock for product ID {product_id}. Available: {current_stock}"}), 409 # 409 Conflict

        # 2. Insert into orders table
        cursor.execute("""
            INSERT INTO orders (customer_name, total, notes)
            VALUES (?, ?, ?)
        """, (customer_name, total, notes))
        order_id = cursor.lastrowid

        # 3. Insert into order_items and update product stock
        for item in items:
            product_id = item['product_id']
            quantity_ordered = item['quantity']
            
            # Insert item detail
            cursor.execute("""
                INSERT INTO order_items (order_id, product_id, quantity)
                VALUES (?, ?, ?)
            """, (order_id, product_id, quantity_ordered))
            
            # Decrease stock
            cursor.execute("""
                UPDATE products SET quantity = quantity - ? WHERE id = ?
            """, (quantity_ordered, product_id))
        
        conn.commit()
        return jsonify({"message": "Order placed successfully.", "order_id": order_id, "total": total}), 201

    except Exception as e:
        conn.rollback()
        return jsonify({"error": f"Error creating order: {e}"}), 500
    finally:
        conn.close()


@app.route('/orders', methods=['GET'])
def get_orders():
    """Returns a list of all orders."""
    try:
        conn = get_db_connection()
        orders = conn.execute("SELECT * FROM orders ORDER BY date DESC").fetchall()
        
        order_list = []
        for order in orders:
            order_dict = dict(order)
            
            # Fetch order items for each order
            items = conn.execute("""
                SELECT oi.quantity, p.name 
                FROM order_items oi JOIN products p ON oi.product_id = p.id 
                WHERE oi.order_id = ?
            """, (order_dict['id'],)).fetchall()
            
            order_dict['items'] = [dict(item) for item in items]
            order_list.append(order_dict)
        
        conn.close()
        return jsonify(order_list), 200
        
    except Exception as e:
        return jsonify({"error": f"Database error fetching orders: {e}"}), 500
        
# -------------------------------
# RUN SERVER
# -------------------------------

if __name__ == '__main__':
    print("Starting Flask API server on http://127.0.0.1:5000")
    # Setting host='127.0.0.1' ensures it only listens locally
    app.run(debug=True, host='127.0.0.1', port=5000)
