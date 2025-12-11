import sqlite3
import json
from flask import Flask, jsonify, request, g
from datetime import datetime

# --- CONFIGURATION ---
DATABASE = 'inventory.db'
app = Flask(__name__)

# --- DATABASE CONNECTION UTILITIES ---

def get_db_connection():
    """Returns a new SQLite database connection with row factory for dictionary access."""
    conn = sqlite3.connect(DATABASE)
    conn.row_factory = sqlite3.Row
    return conn

@app.teardown_appcontext
def close_connection(exception):
    """Closes the database connection at the end of the request."""
    db = getattr(g, '_database', None)
    if db is not None:
        db.close()

def dict_factory(cursor, row):
    """Custom row factory to return rows as dictionaries."""
    d = {}
    for idx, col in enumerate(cursor.description):
        d[col[0]] = row[idx]
    return d

def init_db():
    """Initializes the database schema."""
    conn = get_db_connection()
    # Enable foreign key constraints
    conn.execute("PRAGMA foreign_keys = ON;")
    
    with conn:
        conn.executescript("""
            -- Suppliers Table
            CREATE TABLE IF NOT EXISTS suppliers (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                name TEXT NOT NULL UNIQUE,
                email TEXT NOT NULL UNIQUE,
                contact_person TEXT,
                phone TEXT,
                address TEXT
            );

            -- Products/Plants Table (Inventory)
            CREATE TABLE IF NOT EXISTS products (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                name TEXT NOT NULL UNIQUE,
                category TEXT NOT NULL,
                price REAL NOT NULL,
                quantity INTEGER NOT NULL DEFAULT 0 CHECK(quantity >= 0),
                supplier_id INTEGER,
                FOREIGN KEY (supplier_id) REFERENCES suppliers(id) ON DELETE SET NULL
            );

            -- Orders Table
            CREATE TABLE IF NOT EXISTS orders (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                customer_name TEXT NOT NULL,
                date TEXT NOT NULL,
                total REAL NOT NULL
            );

            -- Order Items Table (Many-to-Many for Order/Product)
            CREATE TABLE IF NOT EXISTS order_items (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                order_id INTEGER NOT NULL,
                product_id INTEGER NOT NULL,
                quantity INTEGER NOT NULL CHECK(quantity > 0),
                price_at_sale REAL NOT NULL,
                FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE,
                FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE RESTRICT
            );
        """)
    conn.close()

# Ensure database is initialized before running the app
with app.app_context():
    init_db()

# --- HELPER FUNCTIONS ---

def get_products_with_supplier_name(cursor, search_term=None):
    """Fetches all products, joining with supplier name, optionally filtered by search term."""
    query = """
        SELECT 
            p.*, 
            s.name AS supplier_name 
        FROM products p
        LEFT JOIN suppliers s ON p.supplier_id = s.id
    """
    params = []
    
    if search_term:
        search_term = f"%{search_term}%"
        query += " WHERE p.name LIKE ? OR p.category LIKE ? OR s.name LIKE ?"
        params = [search_term, search_term, search_term]

    cursor.row_factory = dict_factory
    products = cursor.execute(query, params).fetchall()
    return products

# --- 1. PLANT CRUD ENDPOINTS (Inventory) ---

@app.route('/plants', methods=['GET'])
def list_plants():
    conn = get_db_connection()
    search_term = request.args.get('search')
    
    try:
        products = get_products_with_supplier_name(conn, search_term)
        return jsonify(products)
    except Exception as e:
        return jsonify({"error": str(e)}), 500
    finally:
        conn.close()

@app.route('/plants', methods=['POST'])
def add_plant():
    data = request.get_json()
    name = data.get('name')
    category = data.get('category')
    price = data.get('price')
    quantity = data.get('quantity')
    supplier_id = data.get('supplier_id')

    if not all([name, category, price, quantity is not None]):
        return jsonify({"error": "Missing required fields: name, category, price, and quantity."}), 400

    conn = get_db_connection()
    try:
        cursor = conn.cursor()
        cursor.execute(
            "INSERT INTO products (name, category, price, quantity, supplier_id) VALUES (?, ?, ?, ?, ?)",
            (name, category, price, quantity, supplier_id)
        )
        conn.commit()
        return jsonify({"id": cursor.lastrowid, "message": "Plant added successfully"}), 201
    except sqlite3.IntegrityError as e:
        return jsonify({"error": f"Data integrity error: {e}"}), 400
    except Exception as e:
        return jsonify({"error": str(e)}), 500
    finally:
        conn.close()

@app.route('/plants/<int:plant_id>', methods=['PUT'])
def update_plant(plant_id):
    data = request.get_json()
    conn = get_db_connection()
    
    # Only allow updating fields that are not quantity
    update_fields = {k: v for k, v in data.items() if k in ['name', 'category', 'price', 'supplier_id']}
    
    if not update_fields:
        return jsonify({"error": "No valid fields provided for update."}), 400

    set_clauses = [f"{k} = ?" for k in update_fields.keys()]
    set_clause_str = ", ".join(set_clauses)
    values = list(update_fields.values())
    values.append(plant_id)

    try:
        cursor = conn.cursor()
        cursor.execute(f"UPDATE products SET {set_clause_str} WHERE id = ?", values)
        if cursor.rowcount == 0:
            return jsonify({"error": "Plant not found"}), 404
        conn.commit()
        return jsonify({"message": "Plant updated successfully"}), 200
    except sqlite3.IntegrityError as e:
        return jsonify({"error": f"Data integrity error: {e}"}), 400
    except Exception as e:
        return jsonify({"error": str(e)}), 500
    finally:
        conn.close()

@app.route('/plants/<int:plant_id>', methods=['DELETE'])
def delete_plant(plant_id):
    conn = get_db_connection()
    try:
        cursor = conn.cursor()
        cursor.execute("DELETE FROM products WHERE id = ?", (plant_id,))
        if cursor.rowcount == 0:
            return jsonify({"error": "Plant not found"}), 404
        conn.commit()
        return jsonify({"message": "Plant deleted successfully"}), 200
    except sqlite3.IntegrityError:
        # This occurs if the product is still linked in order_items (though ON DELETE RESTRICT should handle this)
        return jsonify({"error": "Cannot delete plant. It is linked to existing orders."}), 409 
    except Exception as e:
        return jsonify({"error": str(e)}), 500
    finally:
        conn.close()


# --- 2. SUPPLIER CRUD ENDPOINTS ---

@app.route('/suppliers', methods=['GET'])
def list_suppliers():
    conn = get_db_connection()
    conn.row_factory = dict_factory
    suppliers = conn.execute('SELECT * FROM suppliers').fetchall()
    conn.close()
    return jsonify(suppliers)

@app.route('/suppliers', methods=['POST'])
def add_supplier():
    data = request.get_json()
    name = data.get('name')
    email = data.get('email')
    contact_person = data.get('contact_person')
    phone = data.get('phone')
    address = data.get('address')

    if not all([name, email]):
        return jsonify({"error": "Missing required fields: name, email."}), 400

    conn = get_db_connection()
    try:
        cursor = conn.cursor()
        cursor.execute(
            "INSERT INTO suppliers (name, email, contact_person, phone, address) VALUES (?, ?, ?, ?, ?)",
            (name, email, contact_person, phone, address)
        )
        conn.commit()
        return jsonify({"id": cursor.lastrowid, "message": "Supplier added successfully"}), 201
    except sqlite3.IntegrityError as e:
        return jsonify({"error": f"Data integrity error: {e}"}), 400
    except Exception as e:
        return jsonify({"error": str(e)}), 500
    finally:
        conn.close()

@app.route('/suppliers/<int:supplier_id>', methods=['PUT'])
def update_supplier(supplier_id):
    data = request.get_json()
    conn = get_db_connection()
    
    update_fields = {k: v for k, v in data.items() if k in ['name', 'email', 'contact_person', 'phone', 'address']}
    
    if not update_fields:
        return jsonify({"error": "No valid fields provided for update."}), 400

    set_clauses = [f"{k} = ?" for k in update_fields.keys()]
    set_clause_str = ", ".join(set_clauses)
    values = list(update_fields.values())
    values.append(supplier_id)

    try:
        cursor = conn.cursor()
        cursor.execute(f"UPDATE suppliers SET {set_clause_str} WHERE id = ?", values)
        if cursor.rowcount == 0:
            return jsonify({"error": "Supplier not found"}), 404
        conn.commit()
        return jsonify({"message": "Supplier updated successfully"}), 200
    except sqlite3.IntegrityError as e:
        return jsonify({"error": f"Data integrity error: {e}"}), 400
    except Exception as e:
        return jsonify({"error": str(e)}), 500
    finally:
        conn.close()


@app.route('/suppliers/<int:supplier_id>', methods=['DELETE'])
def delete_supplier(supplier_id):
    conn = get_db_connection()
    try:
        cursor = conn.cursor()
        
        # Check if any products are linked to this supplier
        linked_products = cursor.execute("SELECT COUNT(*) FROM products WHERE supplier_id=?", (supplier_id,)).fetchone()[0]
        if linked_products > 0:
            return jsonify({"error": f"Cannot delete supplier. {linked_products} plants are still linked to this supplier. Please update or delete them first."}), 409

        cursor.execute("DELETE FROM suppliers WHERE id = ?", (supplier_id,))
        if cursor.rowcount == 0:
            return jsonify({"error": "Supplier not found"}), 404
        conn.commit()
        return jsonify({"message": "Supplier deleted successfully"}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500
    finally:
        conn.close()


# --- 3. INVENTORY & RESTOCK ENDPOINTS ---

@app.route('/inventory/restock', methods=['POST'])
def restock_plant():
    data = request.get_json()
    product_id = data.get('product_id')
    quantity = data.get('quantity')
    
    if not all([product_id, quantity is not None]):
        return jsonify({"error": "Missing required fields: product_id and quantity."}), 400
        
    if quantity <= 0:
        return jsonify({"error": "Quantity must be positive for restock."}), 400

    conn = get_db_connection()
    try:
        cursor = conn.cursor()
        cursor.execute(
            "UPDATE products SET quantity = quantity + ? WHERE id = ?",
            (quantity, product_id)
        )
        if cursor.rowcount == 0:
            return jsonify({"error": "Product not found"}), 404
            
        conn.commit()
        
        # Fetch the new quantity to confirm the update
        new_qty = cursor.execute("SELECT quantity FROM products WHERE id = ?", (product_id,)).fetchone()['quantity']
        
        return jsonify({"message": "Product restocked successfully", "new_quantity": new_qty}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500
    finally:
        conn.close()


# --- 4. ORDER MANAGEMENT ENDPOINTS ---

@app.route('/orders', methods=['POST'])
def create_order():
    data = request.get_json()
    customer_name = data.get('customer_name')
    items = data.get('items') # List of {'product_id': int, 'quantity': int}

    if not all([customer_name, items]):
        return jsonify({"error": "Missing required fields: customer_name and items."}), 400

    conn = get_db_connection()
    cursor = conn.cursor()
    total = 0
    order_items_data = []

    try:
        conn.begin() # Start transaction

        # 1. Validate stock and calculate total
        for item in items:
            product_id = item.get('product_id')
            quantity = item.get('quantity')
            
            if not product_id or not quantity or quantity <= 0:
                 conn.rollback()
                 return jsonify({"error": "Invalid product ID or quantity in order items."}), 400

            # Fetch product details and check stock
            product = cursor.execute("SELECT price, quantity FROM products WHERE id=?", (product_id,)).fetchone()
            
            if not product:
                conn.rollback()
                return jsonify({"error": f"Product with ID {product_id} not found."}), 404

            if product['quantity'] < quantity:
                conn.rollback()
                return jsonify({"error": f"Insufficient stock for product ID {product_id}. Available: {product['quantity']}, Requested: {quantity}"}), 400
                
            price_at_sale = product['price']
            line_total = price_at_sale * quantity
            total += line_total
            order_items_data.append({
                'product_id': product_id,
                'quantity': quantity,
                'price_at_sale': price_at_sale
            })

        # 2. Insert into orders table
        current_date = datetime.now().isoformat()
        cursor.execute(
            "INSERT INTO orders (customer_name, date, total) VALUES (?, ?, ?)",
            (customer_name, current_date, total)
        )
        order_id = cursor.lastrowid

        # 3. Insert into order_items table and update stock
        for item in order_items_data:
            cursor.execute(
                "INSERT INTO order_items (order_id, product_id, quantity, price_at_sale) VALUES (?, ?, ?, ?)",
                (order_id, item['product_id'], item['quantity'], item['price_at_sale'])
            )
            # Update stock by decrementing quantity
            cursor.execute(
                "UPDATE products SET quantity = quantity - ? WHERE id = ?",
                (item['quantity'], item['product_id'])
            )

        conn.commit()
        return jsonify({"id": order_id, "total": total, "message": "Order created successfully"}), 201

    except Exception as e:
        conn.rollback()
        return jsonify({"error": f"An unexpected error occurred: {e}"}), 500
    finally:
        conn.close()

@app.route('/orders', methods=['GET'])
def list_orders():
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.row_factory = dict_factory
    
    try:
        # Fetch all orders
        orders = cursor.execute("SELECT * FROM orders ORDER BY date DESC").fetchall()
        
        # Fetch items for each order
        for order in orders:
            order_items = cursor.execute("""
                SELECT 
                    oi.quantity, 
                    oi.price_at_sale, 
                    p.name, 
                    p.id as product_id
                FROM order_items oi
                JOIN products p ON oi.product_id = p.id
                WHERE oi.order_id = ?
            """, (order['id'],)).fetchall()
            
            order['items'] = order_items
            
        return jsonify(orders)
        
    except Exception as e:
        return jsonify({"error": str(e)}), 500
    finally:
        conn.close()

@app.route('/orders/<int:order_id>', methods=['DELETE'])
def delete_order(order_id):
    """Deletes an order, including its items, and reverts stock."""
    conn = get_db_connection()
    cursor = conn.cursor()
    
    try:
        # 1. Start Transaction
        conn.begin()
        
        # 2. Get order items to revert stock
        items = cursor.execute("SELECT product_id, quantity FROM order_items WHERE order_id=?", (order_id,)).fetchall()
        
        if not items:
            # Check if the order itself exists (in case it was created without items, though logic prevents this)
            order_exists = cursor.execute("SELECT COUNT(*) FROM orders WHERE id=?", (order_id,)).fetchone()[0]
            if order_exists == 0:
                conn.rollback()
                return jsonify({"error": "Order not found"}), 404

        # 3. Revert stock for each item
        for item in items:
            product_id = item['product_id']
            quantity_revert = item['quantity']
            
            cursor.execute("""
                UPDATE products SET quantity = quantity + ? WHERE id = ?
            """, (quantity_revert, product_id))
            
        # 4. Delete items from order_items table
        cursor.execute("DELETE FROM order_items WHERE order_id = ?", (order_id,))
        
        # 5. Delete order from orders table
        cursor.execute("DELETE FROM orders WHERE id = ?", (order_id,))
        
        conn.commit()
        return jsonify({"message": "Order deleted and stock reverted successfully"}), 200

    except Exception as e:
        conn.rollback()
        return jsonify({"error": f"Error deleting order: {e}"}), 500
    finally:
        conn.close()

# --- RUN SERVER ---

if __name__ == '__main__':
    # Running in debug mode for development
    app.run(debug=True)
