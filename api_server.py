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
    """Custom row factory to return rows as standard Python dictionaries."""
    d = {}
    for idx, col in enumerate(cursor.description):
        d[col[0]] = row[idx]
    return d

def init_db():
    """Initializes the database schema."""
    conn = get_db_connection()
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
            -- *** FIX: Removed CHECK(quantity >= 0) to allow negative stock ***
            CREATE TABLE IF NOT EXISTS products (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                name TEXT NOT NULL UNIQUE,
                category TEXT NOT NULL,
                price REAL NOT NULL,
                quantity INTEGER NOT NULL DEFAULT 0,
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
def get_plants():
    """Fetches all plants, including the supplier name via JOIN, with optional search."""
    search_term = request.args.get('search', '')
    
    query = """
    SELECT 
        p.id, p.name, p.category, p.price, p.quantity, p.supplier_id, s.name AS supplier_name 
    FROM products p
    LEFT JOIN suppliers s ON p.supplier_id = s.id
    WHERE p.name LIKE ? OR p.category LIKE ?
    """
    
    conn = get_db_connection()
    cursor = conn.cursor()
    
    # We set the row_factory to dict_factory for this query to ensure consistency
    cursor.row_factory = dict_factory
    
    # Execute query with search terms
    plants = cursor.execute(query, ('%' + search_term + '%', '%' + search_term + '%')).fetchall()
    conn.close()
    
    return jsonify(plants)

@app.route('/plants', methods=['POST'])
def add_plant():
    """Adds a new plant entry, including the supplier_id foreign key."""
    data = request.get_json()
    
    supplier_id = data.get('supplier_id') 

    if not data.get('name') or not data.get('category') or data.get('price') is None:
        return jsonify({'error': 'Missing required fields: name, category, or price.'}), 400

    query = """
    INSERT INTO products (name, category, price, quantity, supplier_id) 
    VALUES (?, ?, ?, ?, ?)
    """
    
    conn = get_db_connection()
    try:
        with conn:
            cursor = conn.cursor()
            cursor.execute(query, (
                data['name'], 
                data['category'], 
                data['price'], 
                data.get('quantity', 0), 
                supplier_id
            ))
            plant_id = cursor.lastrowid
            return jsonify({'message': 'Plant added successfully', 'id': plant_id}), 201
    except sqlite3.IntegrityError as e:
        return jsonify({'error': f'Data integrity error: {e}'}), 400
    except Exception as e:
        return jsonify({"error": str(e)}), 500
    finally:
        conn.close()


@app.route('/plants/<int:plant_id>', methods=['PUT'])
def update_plant(plant_id):
    """Updates an existing plant's details, including the supplier_id."""
    data = request.get_json()
    updates = []
    values = []

    fields = ['name', 'category', 'price', 'quantity', 'supplier_id'] 

    for field in fields:
        if field in data:
            updates.append(f"{field} = ?") 
            values.append(data[field])

    if not updates:
        return jsonify({'message': 'No fields provided for update'}), 200

    query = f"UPDATE products SET {', '.join(updates)} WHERE id = ?"
    values.append(plant_id) 

    conn = get_db_connection()
    try:
        with conn:
            cursor = conn.cursor()
            cursor.execute(query, tuple(values))
            if cursor.rowcount == 0:
                return jsonify({"error": "Plant not found"}), 404
            return jsonify({'message': 'Plant updated successfully'}), 200
    except sqlite3.IntegrityError as e:
        return jsonify({'error': f'Data integrity error: {e}'}), 400
    except Exception as e:
        return jsonify({"error": str(e)}), 500
    finally:
        conn.close()

@app.route('/plants/<int:plant_id>', methods=['DELETE'])
def delete_plant(plant_id):
    """Deletes a plant entry."""
    conn = get_db_connection()
    try:
        with conn:
            cursor = conn.cursor()
            cursor.execute("DELETE FROM products WHERE id = ?", (plant_id,))
            if cursor.rowcount == 0:
                return jsonify({"error": "Plant not found"}), 404
            return jsonify({"message": "Plant deleted successfully"}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500
    finally:
        conn.close() 

# --- 2. SUPPLIER CRUD ENDPOINTS ---

@app.route('/suppliers', methods=['GET'])
def list_suppliers():
    """Returns a list of all suppliers."""
    conn = get_db_connection()
    conn.row_factory = dict_factory
    try:
        suppliers = conn.execute('SELECT * FROM suppliers').fetchall()
        return jsonify(suppliers)
    except Exception as e:
        return jsonify({"error": str(e)}), 500
    finally:
        conn.close()

@app.route('/suppliers', methods=['POST'])
def add_supplier():
    """Adds a new supplier to the database."""
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
        with conn: # <--- Transaction handles commit/rollback
            cursor = conn.cursor()
            cursor.execute(
                "INSERT INTO suppliers (name, email, contact_person, phone, address) VALUES (?, ?, ?, ?, ?)",
                (name, email, contact_person, phone, address)
            )
            return jsonify({"id": cursor.lastrowid, "message": "Supplier added successfully"}), 201
    except sqlite3.IntegrityError as e:
        # Handles UNIQUE constraints (like name or email already existing)
        return jsonify({"error": f"Data integrity error: {e}"}), 400
    except Exception as e:
        return jsonify({"error": str(e)}), 500
    finally:
        conn.close()

@app.route('/suppliers/<int:supplier_id>', methods=['PUT'])
def update_supplier(supplier_id):
    """Updates an existing supplier's details."""
    data = request.get_json()
    conn = get_db_connection()
    
    update_fields = {k: v for k, v in data.items() if k in ['name', 'email', 'contact_person', 'phone', 'address']}
    
    if not update_fields:
        return jsonify({"error": "No valid fields provided for update."}), 400

    set_clauses = [f"{k} = ?" for k in update_fields.keys()]
    set_clause_str = ", ".join(set_clauses)
    values = list(update_fields.values())
    values.append(supplier_id) # The ID is the last parameter

    try:
        with conn:
            cursor = conn.cursor()
            cursor.execute(f"UPDATE suppliers SET {set_clause_str} WHERE id = ?", values)
            if cursor.rowcount == 0:
                return jsonify({"error": "Supplier not found"}), 404
            return jsonify({"message": "Supplier updated successfully"}), 200
    except sqlite3.IntegrityError as e:
        return jsonify({"error": f"Data integrity error: {e}"}), 400
    except Exception as e:
        return jsonify({"error": str(e)}), 500
    finally:
        conn.close()


@app.route('/suppliers/<int:supplier_id>', methods=['DELETE'])
def delete_supplier(supplier_id):
    """Deletes a supplier if no products are linked."""
    conn = get_db_connection()
    cursor = conn.cursor()
    
    try:
        with conn:
            # Check for linked products (crucial for foreign key integrity)
            linked_products = cursor.execute("SELECT COUNT(*) FROM products WHERE supplier_id=?", (supplier_id,)).fetchone()[0]
            if linked_products > 0:
                return jsonify({"error": f"Cannot delete supplier. {linked_products} plants are still linked. Please update or delete them first."}), 409

            cursor.execute("DELETE FROM suppliers WHERE id = ?", (supplier_id,))
            if cursor.rowcount == 0:
                return jsonify({"error": "Supplier not found"}), 404
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
        
    # 💥 FIX: Removed the check for quantity <= 0. Negative quantity is now allowed.
    # The frontend is now responsible for handling positive/negative intent (restock/write-off).

    conn = get_db_connection()
    try:
        with conn: # <--- Transaction handled by context manager
            cursor = conn.cursor()
            
            # This query handles both positive (restock: quantity + X) 
            # and negative (write-off: quantity + (-X)) quantities correctly.
            cursor.execute(
                "UPDATE products SET quantity = quantity + ? WHERE id = ?",
                (quantity, product_id)
            )
            if cursor.rowcount == 0:
                return jsonify({"error": "Product not found"}), 404
                
            # Fetch the new quantity to confirm the update
            cursor.row_factory = dict_factory
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
    
    # 💥 FIX: CRITICAL LINE TO ENSURE DICT ACCESS (product['quantity']) WORKS RELIABLY
    cursor.row_factory = dict_factory 
    
    total = 0
    order_items_data = []

    try:
        with conn: # <--- TRANSACTION BLOCK START
            # 1. Validate stock and calculate total
            for item in items:
                product_id = item.get('product_id')
                quantity = item.get('quantity')
                
                if not product_id or not quantity or quantity <= 0:
                    raise ValueError("Invalid product ID or quantity in order items.")

                # Fetch product details and check stock
                product = cursor.execute("SELECT price, quantity FROM products WHERE id=?", (product_id,)).fetchone()
                
                if not product:
                    raise LookupError(f"Product with ID {product_id} not found.")

                if product['quantity'] < quantity:
                    raise ValueError(f"Insufficient stock for product ID {product_id}. Available: {product['quantity']}, Requested: {quantity}")
                    
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
                
                # 🟢 STOCK DECREMENT: This is the logic that reduces the stock
                cursor.execute(
                    "UPDATE products SET quantity = quantity - ? WHERE id = ?",
                    (item['quantity'], item['product_id'])
                )

            # COMMIT is automatic upon exiting the 'with conn:' block successfully
            return jsonify({"id": order_id, "total": total, "message": "Order created successfully"}), 201

    except (ValueError, LookupError, sqlite3.IntegrityError) as e:
        # ROLLBACK is automatic if an exception is raised
        return jsonify({"error": f"Order creation failed: {e}"}), 400
    except Exception as e:
        # ROLLBACK is automatic for unexpected errors
        return jsonify({"error": f"An unexpected server error occurred: {e}"}), 500
    finally:
        conn.close() # Connection is closed after the transaction

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
    
    # We set the factory here to allow key-based access to the fetched item data
    cursor.row_factory = dict_factory

    try:
        with conn: # <--- TRANSACTION BLOCK START
            
            # 1. Get order items to revert stock
            items = cursor.execute("SELECT product_id, quantity FROM order_items WHERE order_id=?", (order_id,)).fetchall()
            
            # Check if the order itself exists
            order_exists = cursor.execute("SELECT COUNT(*) FROM orders WHERE id=?", (order_id,)).fetchone()['COUNT(*)']
            if order_exists == 0:
                raise LookupError("Order not found")

            # 2. Revert stock for each item
            for item in items:
                product_id = item['product_id']
                quantity_revert = item['quantity']
                
                # 🟢 STOCK REVERSION: This logic puts the stock back
                cursor.execute("""
                    UPDATE products SET quantity = quantity + ? WHERE id = ?
                """, (quantity_revert, product_id))
                
            # 3. Delete order from orders and order_items table (ON DELETE CASCADE handles order_items)
            cursor.execute("DELETE FROM orders WHERE id = ?", (order_id,))
            
            # COMMIT is automatic upon exiting the 'with conn:' block successfully
            return jsonify({"message": "Order deleted and stock reverted successfully"}), 200

    except LookupError as e:
        return jsonify({"error": str(e)}), 404
    except Exception as e:
        # ROLLBACK is automatic
        return jsonify({"error": f"Error deleting order: {e}"}), 500
    finally:
        conn.close()

# --- RUN SERVER ---

if __name__ == '__main__':
    app.run(debug=True) 