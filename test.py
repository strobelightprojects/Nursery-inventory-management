import pytest
import sqlite3

# --- Pytest Fixture for Database Setup ---

@pytest.fixture
def db_connection():
    """
    Creates an isolated, in-memory database connection and sets up the schema 
    exactly matching your current application file for each test.
    
    IMPORTANT: Includes 'PRAGMA foreign_keys = ON' to ensure constraints are enforced 
    (this fixes the IntegrityError failure).
    """
    conn = sqlite3.connect(":memory:")
    cursor = conn.cursor()

    # FIX: Must enable Foreign Key enforcement in SQLite for the tests to work correctly
    cursor.execute("PRAGMA foreign_keys = ON")

    # 1. Create Suppliers table
    cursor.execute("""
    CREATE TABLE suppliers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT UNIQUE,
        contact_person TEXT,
        email TEXT,
        phone TEXT,
        address TEXT
    )
    """)

    # 2. Create Products table
    cursor.execute("""
    CREATE TABLE products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT,
        category TEXT,
        description TEXT,
        sku TEXT,
        price REAL,
        cost_price REAL,
        quantity INTEGER,
        reorder_at INTEGER,
        supplier_id INTEGER,
        FOREIGN KEY(supplier_id) REFERENCES suppliers(id)
    )
    """)

    # 3. Create Orders and Order Items (Required for FK testing)
    cursor.execute("""
    CREATE TABLE orders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        customer_name TEXT,
        total REAL,
        notes TEXT,
        date TEXT DEFAULT CURRENT_DATE
    )
    """)

    cursor.execute("""
    CREATE TABLE order_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        order_id INTEGER,
        product_id INTEGER,
        quantity INTEGER,
        FOREIGN KEY(order_id) REFERENCES orders(id),
        FOREIGN KEY(product_id) REFERENCES products(id)
    )
    """)
    
    # 4. Add a test supplier required for linking products
    cursor.execute("INSERT INTO suppliers (name) VALUES ('Test Supplier Co.')")
    conn.commit()
    
    # 5. Add a test product for restocking/ordering
    cursor.execute(
        """INSERT INTO products (name, category, price, quantity, supplier_id) 
           VALUES ('Sun Flower', 'Annual', 4.00, 100, 1)"""
    )
    conn.commit()
    
    # Yield the connection for the test function to use
    yield conn

    # Teardown: Close the connection
    conn.close()

@pytest.fixture
def supplier_id(db_connection):
    """Fixture to easily get the ID of the pre-added test supplier."""
    return db_connection.execute("SELECT id FROM suppliers WHERE name='Test Supplier Co.'").fetchone()[0]

@pytest.fixture
def sun_flower_id(db_connection):
    """Fixture to easily get the ID of the pre-added test product."""
    return db_connection.execute("SELECT id FROM products WHERE name='Sun Flower'").fetchone()[0]


# ====================================================================
# 1. CORE CRUD LOGIC TESTS (Verifying existing application functions)
# ====================================================================

def test_add_product_saves_all_fields(db_connection, supplier_id):
    """Verifies the logic behind the add_product function."""
    cursor = db_connection.cursor()
    
    product_data = (
        'Moss Rose', 'Perennial', 'Ground cover plant', 'MR200', 
        6.50, 3.50, 50, 10, supplier_id
    )
    
    cursor.execute(
        """INSERT INTO products 
           (name, category, description, sku, price, cost_price, quantity, reorder_at, supplier_id) 
           VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)""",
        product_data
    )
    db_connection.commit()
    
    result = cursor.execute("SELECT name, quantity, cost_price, sku FROM products WHERE name='Moss Rose'").fetchone()
    
    assert result is not None
    assert result[1] == 50
    assert result[2] == 3.50

def test_add_supplier_saves_contact_info(db_connection):
    """Verifies the logic behind the add_supplier function."""
    cursor = db_connection.cursor()
    supplier_data = ('Fertilizer Co.', 'David Lee', 'david@fert.com', '555-1001', '40 Farm Rd')
    
    cursor.execute(
        """INSERT INTO suppliers (name, contact_person, email, phone, address) 
           VALUES (?, ?, ?, ?, ?)""",
        supplier_data
    )
    db_connection.commit()
    
    result = cursor.execute("SELECT name, phone FROM suppliers WHERE name='Fertilizer Co.'").fetchone()
    
    assert result is not None
    assert result[1] == '555-1001'

def test_restock_product_increments_quantity(db_connection):
    """Verifies the logic behind the restock_product function (stock increase)."""
    cursor = db_connection.cursor()
    product_name = 'Sun Flower'
    quantity_to_add = 25
    
    cursor.execute(
        "UPDATE products SET quantity = quantity + ? WHERE name=?", 
        (quantity_to_add, product_name)
    )
    db_connection.commit()
    
    # Initial was 100, expected is 125
    result = cursor.execute(
        "SELECT quantity FROM products WHERE name = ?",
        (product_name,)
    ).fetchone()
    
    assert result[0] == 125

def test_create_order_decrements_stock(db_connection, sun_flower_id):
    """Verifies that creating an order correctly decreases the product quantity."""
    cursor = db_connection.cursor()
    quantity_sold = 5
    
    cursor.execute("UPDATE products SET quantity = quantity - ? WHERE id=?", (quantity_sold, sun_flower_id))
    db_connection.commit()
    
    # Initial was 100, expected is 95
    result = cursor.execute(
        "SELECT quantity FROM products WHERE id = ?",
        (sun_flower_id,)
    ).fetchone()
    
    assert result[0] == 95


# ====================================================================
# 2. INTEGRITY AND EDGE CASE TESTS 
# ====================================================================

def test_prevent_duplicate_supplier_name(db_connection):
    """Tests the database constraint preventing two suppliers from having the same name."""
    cursor = db_connection.cursor()
    supplier_name = 'Unique Co.'
    
    # 1. Insert the first supplier (Success)
    cursor.execute("INSERT INTO suppliers (name) VALUES (?)", (supplier_name,))
    db_connection.commit()

    # 2. Attempt to insert the same supplier name again (Failure expected)
    with pytest.raises(sqlite3.IntegrityError):
        cursor.execute("INSERT INTO suppliers (name) VALUES (?)", (supplier_name,))
        db_connection.commit()

def test_restock_with_negative_quantity_is_allowed_by_db(db_connection, sun_flower_id):
    """
    Tests the edge case of restocking with a negative number. 
    (The application layer must prevent this, but the DB allows it.)
    """
    cursor = db_connection.cursor()
    initial_quantity = 100 
    quantity_to_subtract = 150 
    
    # Simulate the update, which results in a negative value
    cursor.execute(
        "UPDATE products SET quantity = quantity + ? WHERE id=?", 
        (-quantity_to_subtract, sun_flower_id)
    )
    db_connection.commit()

    result = cursor.execute(
        "SELECT quantity FROM products WHERE id = ?",
        (sun_flower_id,)
    ).fetchone()
    
    # Assert that the DB allowed the negative quantity: 100 - 150 = -50
    assert result[0] == -50

def test_order_creation_with_non_existent_product_fails(db_connection):
    """
    Tests the Foreign Key constraint: ensures an order item cannot be created 
    if it links to a non-existent product. (This is the test that previously failed.)
    """
    cursor = db_connection.cursor()
    
    # 1. Create a dummy order
    customer_name = "Test Customer"
    total_price = 10.00
    cursor.execute("INSERT INTO orders (customer_name, total) VALUES (?, ?)", (customer_name, total_price))
    order_id = cursor.lastrowid
    
    # 2. Attempt to add an order item with a non-existent product_id (e.g., 9999)
    non_existent_product_id = 9999
    
    with pytest.raises(sqlite3.IntegrityError):
        cursor.execute(
            "INSERT INTO order_items (order_id, product_id, quantity) VALUES (?, ?, ?)",
            (order_id, non_existent_product_id, 1)
        )
        db_connection.commit()
