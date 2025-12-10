import tkinter as tk
from tkinter import ttk, messagebox
import sqlite3
import os


# -------------------------------
# SQLite Database Setup (Requirement 6: Local Data Storage)
# -------------------------------
DB_NAME = "nursery.db"
conn = sqlite3.connect(DB_NAME)
cursor = conn.cursor()

# NOTE: The tables below are adjusted for the minimum requirements, 
# removing unused columns like 'description', 'sku', 'cost_price', 'reorder_at'
# to simplify the application based on the "Must Have" list.

cursor.execute("""
CREATE TABLE IF NOT EXISTS suppliers (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL UNIQUE,
    contact_person TEXT,
    email TEXT,
    phone TEXT,
    address TEXT
)
""")

# Product table adjusted to match requirements (Name, Type, Price, Quantity, Supplier)
cursor.execute("""
CREATE TABLE IF NOT EXISTS products (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    category TEXT, -- Used for the required 'type' field
    price REAL,
    quantity INTEGER,
    supplier_id INTEGER,
    FOREIGN KEY(supplier_id) REFERENCES suppliers(id)
)
""")

# Order tables kept for original app structure, though not required by Section 2a
cursor.execute("""
CREATE TABLE IF NOT EXISTS orders (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    customer_name TEXT,
    total REAL,
    notes TEXT,
    date TEXT DEFAULT CURRENT_DATE
)
""")

cursor.execute("""
CREATE TABLE IF NOT EXISTS order_items (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    order_id INTEGER,
    product_id INTEGER,
    quantity INTEGER,
    FOREIGN KEY(order_id) REFERENCES orders(id),
    FOREIGN KEY(product_id) REFERENCES products(id)
)
""")

conn.commit()

# -------------------------------
# Utility Functions
# -------------------------------

def clear_frame():
    for widget in frame.winfo_children():
        widget.destroy()

def get_selected_product_id(tree):
    """Helper to get the hidden ID of a selected product."""
    selected_item = tree.focus()
    if not selected_item:
        messagebox.showerror("Selection Error", "Please select a plant record first.")
        return None
    # ID is stored as the first value (index 0)
    item_values = tree.item(selected_item, 'values')
    # Use the first element, which is the hidden ID from the treeview
    return item_values[0] 

def get_supplier_id_by_name(supplier_name):
    """Retrieves the ID of a supplier given their name."""
    if supplier_name == "None" or not supplier_name:
        return None
    result = cursor.execute("SELECT id FROM suppliers WHERE name=?", (supplier_name,)).fetchone()
    return result[0] if result else None

# -------------------------------
# Plant Management Functions (Requirement 1, 2, 3)
# -------------------------------

def show_inventory():
    """Requirement 3: Displays a clear view of the entire plant inventory."""
    clear_frame()
    
    header_frame = tk.Frame(frame)
    header_frame.pack(fill="x", pady=5, padx=10)
    
    tk.Label(header_frame, text="Plant Inventory", font=("Arial", 20)).pack(side="left")
    
    # Requirement 1: Delete Plant button
    tk.Button(header_frame, text="Delete Plant", bg="#C0392B", fg="white", 
              command=lambda: delete_product(tree)).pack(side="right", padx=5)
    
    # Requirement 2: Update stock quantity (via Edit modal)
    tk.Button(header_frame, text="Edit Plant / Update Stock", bg="#2980B9", fg="white", 
              command=lambda: edit_product_modal(tree)).pack(side="right", padx=5)
    
    # Requirement 1: Add Plant button
    tk.Button(header_frame, text="+ Add New Plant", bg="#27AE60", fg="white", 
              command=add_product_modal).pack(side="right", padx=5)

    # Treeview columns for Requirements 1 & 3
    # ID is hidden but necessary for CRUD operations
    tree = ttk.Treeview(frame, columns=("ID", "Name", "Type", "Price", "Stock", "Supplier"), show="headings")
    
    tree.heading("ID", text="ID")
    tree.heading("Name", text="Name")
    tree.heading("Type", text="Type")
    tree.heading("Price", text="Price")
    tree.heading("Stock", text="Quantity")
    tree.heading("Supplier", text="Supplier")

    # Configure columns
    tree.column("ID", width=0, stretch=tk.NO) # Hidden
    tree.column("Name", anchor=tk.W, width=150)
    tree.column("Type", anchor=tk.W, width=100)
    tree.column("Price", anchor=tk.E, width=80)
    tree.column("Stock", anchor=tk.E, width=80)
    tree.column("Supplier", anchor=tk.W, width=150)
    
    tree.pack(expand=True, fill="both", padx=10, pady=10)

    # Load data for the view
    rows = cursor.execute("""
        SELECT p.id, p.name, p.category, p.price, p.quantity, s.name 
        FROM products p LEFT JOIN suppliers s ON p.supplier_id = s.id
        ORDER BY p.name
    """).fetchall()
    
    for row in rows:
        # Insert the hidden ID first, then the display columns
        formatted_row = (row[0], row[1], row[2], f"${row[3]:.2f}", row[4], row[5] or "N/A")
        tree.insert("", tk.END, values=formatted_row)
    
    if not rows:
        tk.Label(frame, text="No plant records found.", fg="gray").pack(pady=20)


def add_product_modal():
    """Requirement 1: Modal for adding a new plant record."""
    def save_product():
        try:
            p_name = name.get().strip()
            p_type = plant_type.get().strip()
            p_price = float(price.get())
            p_quantity = int(quantity.get())
            s_name = supplier_var.get()
            s_id = get_supplier_id_by_name(s_name)

            if not p_name or not p_type or p_price is None or p_quantity is None:
                 messagebox.showerror("Validation Error", "Name, Type, Price, and Quantity are required.")
                 return

            cursor.execute("""
                INSERT INTO products (name, category, price, quantity, supplier_id) 
                VALUES (?, ?, ?, ?, ?)
            """, (p_name, p_type, p_price, p_quantity, s_id))
            conn.commit()
            messagebox.showinfo("Success", f"Plant '{p_name}' added successfully.")
            top.destroy()
            show_inventory()
        except ValueError:
            messagebox.showerror("Input Error", "Price and Quantity must be valid numbers.")
        except Exception as e:
            messagebox.showerror("Database Error", f"An error occurred: {e}")

    top = tk.Toplevel(root)
    top.title("Add New Plant Record")
    
    labels = ["Name:", "Type:", "Price ($):", "Quantity:", "Supplier:"]
    name = tk.Entry(top)
    plant_type = tk.Entry(top)
    price = tk.Entry(top)
    quantity = tk.Entry(top)
    
    supplier_names = ["None"] + [row[0] for row in cursor.execute("SELECT name FROM suppliers ORDER BY name").fetchall()]
    supplier_var = tk.StringVar(top)
    supplier_var.set(supplier_names[0])
    supplier_combo = ttk.Combobox(top, textvariable=supplier_var, values=supplier_names, state="readonly")
    
    entries = [name, plant_type, price, quantity, supplier_combo]

    for i, label_text in enumerate(labels):
        tk.Label(top, text=label_text, padx=5, pady=5).grid(row=i, column=0, sticky="e")
        entries[i].grid(row=i, column=1, padx=5, pady=5, sticky="ew")

    tk.Button(top, text="Save Plant", bg="#27AE60", fg="white", command=save_product).grid(row=len(labels), column=0, columnspan=2, pady=10)


def edit_product_modal(tree):
    """Requirement 2: Modal for updating a plant's details, including quantity."""
    
    product_id = get_selected_product_id(tree)
    if not product_id: return

    # Fetch current plant data
    current_data = cursor.execute("""
        SELECT p.name, p.category, p.price, p.quantity, s.name 
        FROM products p LEFT JOIN suppliers s ON p.supplier_id = s.id
        WHERE p.id=?
    """, (product_id,)).fetchone()
    
    if not current_data:
        messagebox.showerror("Error", "Could not retrieve plant details.")
        return

    c_name, c_type, c_price, c_quantity, c_supplier = current_data
    
    def save_update():
        try:
            p_name = name.get().strip()
            p_type = plant_type.get().strip()
            p_price = float(price.get())
            p_quantity = int(quantity.get()) # Requirement 2: The stock quantity update
            s_name = supplier_var.get()
            s_id = get_supplier_id_by_name(s_name)

            if not p_name or not p_type or p_price is None or p_quantity is None:
                 messagebox.showerror("Validation Error", "Name, Type, Price, and Quantity are required.")
                 return
            
            cursor.execute("""
                UPDATE products SET name=?, category=?, price=?, quantity=?, supplier_id=?
                WHERE id=?
            """, (p_name, p_type, p_price, p_quantity, s_id, product_id))
            conn.commit()
            messagebox.showinfo("Success", f"Plant '{p_name}' updated successfully. New Quantity: {p_quantity}")
            top.destroy()
            show_inventory()
        except ValueError:
            messagebox.showerror("Input Error", "Price and Quantity must be valid numbers.")
        except Exception as e:
            messagebox.showerror("Database Error", f"An error occurred: {e}")

    top = tk.Toplevel(root)
    top.title(f"Edit Plant: {c_name}")
    
    labels = ["Name:", "Type:", "Price ($):", "Quantity:", "Supplier:"]
    name = tk.Entry(top); name.insert(0, c_name)
    plant_type = tk.Entry(top); plant_type.insert(0, c_type)
    price = tk.Entry(top); price.insert(0, f"{c_price:.2f}")
    quantity = tk.Entry(top); quantity.insert(0, str(c_quantity))
    
    supplier_names = ["None"] + [row[0] for row in cursor.execute("SELECT name FROM suppliers ORDER BY name").fetchall()]
    supplier_var = tk.StringVar(top)
    supplier_var.set(c_supplier or "None")
    supplier_combo = ttk.Combobox(top, textvariable=supplier_var, values=supplier_names, state="readonly")
    
    entries = [name, plant_type, price, quantity, supplier_combo]

    for i, label_text in enumerate(labels):
        tk.Label(top, text=label_text, padx=5, pady=5).grid(row=i, column=0, sticky="e")
        entries[i].grid(row=i, column=1, padx=5, pady=5, sticky="ew")

    tk.Button(top, text="Save Changes", bg="#2980B9", fg="white", command=save_update).grid(row=len(labels), column=0, columnspan=2, pady=10)


def delete_product(tree):
    """Requirement 1: Function to delete an existing plant record."""
    product_id = get_selected_product_id(tree)
    if not product_id: return

    # Get the name for confirmation message
    item_values = tree.item(tree.focus(), 'values')
    product_name = item_values[1] 

    if messagebox.askyesno("Confirm Delete", f"Are you sure you want to permanently delete plant '{product_name}'?"):
        try:
            # Also delete related order items to maintain database integrity
            cursor.execute("DELETE FROM order_items WHERE product_id=?", (product_id,))
            cursor.execute("DELETE FROM products WHERE id=?", (product_id,))
            conn.commit()
            messagebox.showinfo("Success", f"Plant '{product_name}' deleted successfully.")
            show_inventory()
        except Exception as e:
            messagebox.showerror("Database Error", f"Failed to delete product: {e}")

# -------------------------------
# Supplier Management Functions (Requirement 4)
# -------------------------------

def show_suppliers():
    """Requirement 4: Displays the supplier management view (add, view, delete)."""
    clear_frame()
    
    header_frame = tk.Frame(frame)
    header_frame.pack(fill="x", pady=5, padx=10)
    
    tk.Label(header_frame, text="Supplier Management", font=("Arial", 20)).pack(side="left")
    
    # Requirement 4: Delete Supplier button
    tk.Button(header_frame, text="Delete Supplier", bg="#C0392B", fg="white", 
              command=lambda: delete_supplier(tree)).pack(side="right", padx=5)
    
    # Requirement 4: Add Supplier button
    tk.Button(header_frame, text="+ Add Supplier", bg="#27AE60", fg="white", 
              command=add_supplier_modal).pack(side="right", padx=5)

    # Treeview for Suppliers
    tree = ttk.Treeview(frame, columns=("ID", "Name", "Contact Person", "Email", "Phone", "Address"), show="headings")
    
    tree.heading("ID", text="ID")
    tree.heading("Name", text="Name")
    tree.heading("Contact Person", text="Contact Person")
    tree.heading("Email", text="Email")
    tree.heading("Phone", text="Phone")
    tree.heading("Address", text="Address")
    
    tree.column("ID", width=0, stretch=tk.NO) # Hidden ID
    tree.column("Name", anchor=tk.W, width=150)
    tree.column("Contact Person", anchor=tk.W, width=150)
    tree.column("Email", anchor=tk.W, width=150)
    tree.column("Phone", anchor=tk.W, width=120)
    tree.column("Address", anchor=tk.W, width=250)
    
    tree.pack(expand=True, fill="both", padx=10, pady=10)

    # Load Data (Requirement 4: View)
    rows = cursor.execute("SELECT id, name, contact_person, email, phone, address FROM suppliers ORDER BY name").fetchall()
    for row in rows:
        tree.insert("", tk.END, values=row)
    
    if not rows:
        tk.Label(frame, text="No suppliers found.", fg="gray").pack(pady=20)


def add_supplier_modal():
    """Requirement 4: Modal for adding new supplier information."""
    # Renamed from 'add_supplier' to 'add_supplier_modal' for clarity
    def save_supplier():
        try:
            s_name = name.get().strip()
            s_contact = contact.get().strip()
            s_email = email.get().strip()
            s_phone = phone.get().strip()
            s_address = address.get("1.0", tk.END).strip()

            if not s_name:
                messagebox.showerror("Validation Error", "Supplier Name is required.")
                return

            cursor.execute("""
                INSERT INTO suppliers (name, contact_person, email, phone, address) 
                VALUES (?, ?, ?, ?, ?)
            """, (s_name, s_contact, s_email, s_phone, s_address))
            conn.commit()
            messagebox.showinfo("Success", f"Supplier '{s_name}' added successfully.")
            top.destroy()
            show_suppliers()
        except sqlite3.IntegrityError:
             messagebox.showerror("Error", "A supplier with this name already exists.")
        except Exception as e:
            messagebox.showerror("Database Error", f"An error occurred: {e}")

    top = tk.Toplevel(root)
    top.title("Add New Supplier")
    
    tk.Label(top, text="Company Name:").grid(row=0, column=0, sticky="e", padx=5, pady=5)
    name = tk.Entry(top); name.grid(row=0, column=1, padx=5, pady=5, sticky="ew")
    
    tk.Label(top, text="Contact Person:").grid(row=1, column=0, sticky="e", padx=5, pady=5)
    contact = tk.Entry(top); contact.grid(row=1, column=1, padx=5, pady=5, sticky="ew")
    
    tk.Label(top, text="Email:").grid(row=2, column=0, sticky="e", padx=5, pady=5)
    email = tk.Entry(top); email.grid(row=2, column=1, padx=5, pady=5, sticky="ew")
    
    tk.Label(top, text="Phone:").grid(row=3, column=0, sticky="e", padx=5, pady=5)
    phone = tk.Entry(top); phone.grid(row=3, column=1, padx=5, pady=5, sticky="ew")
    
    tk.Label(top, text="Address:").grid(row=4, column=0, sticky="e", padx=5, pady=5)
    address = tk.Text(top, height=3, width=30); address.grid(row=4, column=1, padx=5, pady=5, sticky="ew")

    tk.Button(top, text="Save Supplier", bg="#27AE60", fg="white", command=save_supplier).grid(row=5, column=0, columnspan=2, pady=10)


def delete_supplier(tree):
    """Requirement 4: Function to delete supplier information."""
    selected_item = tree.focus()
    if not selected_item:
        messagebox.showerror("Selection Error", "Please select a supplier record first.")
        return

    item_values = tree.item(selected_item, 'values')
    supplier_id = item_values[0]
    supplier_name = item_values[1]

    # Check for dependent plant records (prevents foreign key constraint errors)
    plant_count = cursor.execute("SELECT COUNT(*) FROM products WHERE supplier_id=?", (supplier_id,)).fetchone()[0]

    if plant_count > 0:
        messagebox.showerror("Error", f"Cannot delete '{supplier_name}'. It is currently linked to {plant_count} plant record(s).")
        return

    if messagebox.askyesno("Confirm Delete", f"Are you sure you want to delete supplier '{supplier_name}'?"):
        try:
            cursor.execute("DELETE FROM suppliers WHERE id=?", (supplier_id,))
            conn.commit()
            messagebox.showinfo("Success", f"Supplier '{supplier_name}' deleted successfully.")
            show_suppliers()
        except Exception as e:
            messagebox.showerror("Database Error", f"Failed to delete supplier: {e}")

# -------------------------------
# Order/Restock Functions (Kept for existing structure, though not required)
# -------------------------------
# NOTE: The restock_product function has been removed as Req 2 is now handled by edit_product_modal.
# NOTE: The add_product function has been renamed to add_product_modal for consistency.
# NOTE: The add_supplier function has been renamed to add_supplier_modal for consistency.

def create_order():
    # ... (Order function remains the same as it's not a required change) ...
    def save_order():
        try:
            product_name = product.get()
            quantity_sold = int(quantity.get())

            if not product_name or quantity_sold <= 0:
                messagebox.showerror("Error", "Please select a product and enter a valid quantity.")
                return

            product_data = cursor.execute("SELECT id, price, quantity FROM products WHERE name=?", (product_name,)).fetchone()
            if not product_data:
                messagebox.showerror("Error", "Product not found.")
                return
            
            product_id, unit_price, current_stock = product_data

            if quantity_sold > current_stock:
                messagebox.showwarning("Stock Warning", f"Cannot sell {quantity_sold} of '{product_name}'. Only {current_stock} in stock.")
                return

            total_price = unit_price * quantity_sold
            
            # 1. Insert new order
            cursor.execute("INSERT INTO orders (customer_name, total, notes) VALUES (?, ?, ?)",
                            (customer_name.get(), total_price, notes.get("1.0", tk.END)))
            order_id = cursor.lastrowid
            
            # 2. Insert order item
            cursor.execute("INSERT INTO order_items (order_id, product_id, quantity) VALUES (?, ?, ?)",
                            (order_id, product_id, quantity_sold))
            
            # 3. Update stock (decrement quantity)
            cursor.execute("UPDATE products SET quantity = quantity - ? WHERE id=?", (quantity_sold, product_id))
            
            conn.commit()
            messagebox.showinfo("Success", f"Order {order_id} created successfully.")
            top.destroy()
            show_orders()
        except ValueError:
            messagebox.showerror("Input Error", "Quantity must be a valid number.")
        except Exception as e:
            messagebox.showerror("Database Error", f"An error occurred: {e}")

    top = tk.Toplevel(root)
    top.title("Create New Order")
    tk.Label(top, text="Customer").grid(row=0, column=0, sticky="e")
    customer_name = tk.Entry(top); customer_name.grid(row=0, column=1)
    tk.Label(top, text="Product").grid(row=1, column=0, sticky="e")
    product_names = [row[0] for row in cursor.execute("SELECT name FROM products").fetchall()]
    product = ttk.Combobox(top, values=product_names)
    product.grid(row=1, column=1)
    tk.Label(top, text="Quantity").grid(row=2, column=0, sticky="e")
    quantity = tk.Entry(top); quantity.grid(row=2, column=1)
    tk.Label(top, text="Notes").grid(row=3, column=0, sticky="e")
    notes = tk.Text(top, height=3, width=30); notes.grid(row=3, column=1)
    tk.Button(top, text="Create Order", bg="#4CAF50", fg="white", command=save_order).grid(row=4, column=0, columnspan=2, pady=10)

def show_orders():
    # ... (Order view function remains the same as it's not a required change) ...
    clear_frame()
    header_frame = tk.Frame(frame)
    header_frame.pack(fill="x", pady=5, padx=10)

    tk.Label(header_frame, text="Orders", font=("Arial", 20)).pack(side="left")
    tk.Button(header_frame, text="+ Create Order", bg="#4CAF50", fg="white", command=create_order).pack(side="right", padx=5)

    tree = ttk.Treeview(frame, columns=("ID", "Customer", "Date", "Total"), show="headings")
    for col in tree["columns"]:
        tree.heading(col, text=col)
    tree.pack(expand=True, fill="both", padx=10, pady=10)

    rows = cursor.execute("SELECT id, customer_name, date, total FROM orders").fetchall()
    for row in rows:
        tree.insert("", tk.END, values=row)

    if not rows:
        tk.Label(frame, text="No orders found.", fg="gray").pack(pady=20)


# -------------------------------
# GUI Setup
root.title("Plant Inventory Management System")
root.geometry("1000x650") # Slightly larger window for better layout

# Navbar (Renamed from 'menu' to 'nav' for clarity)
nav = tk.Frame(root, bg="#34495E")
nav.pack(fill="x")

tk.Button(nav, text="Inventory", fg="white", bg="#34495E", font=("Arial", 12), borderwidth=0, command=show_inventory).pack(side="left", padx=15, pady=10)
tk.Button(nav, text="Orders", fg="white", bg="#34495E", font=("Arial", 12), borderwidth=0, command=show_orders).pack(side="left", padx=15, pady=10)
tk.Button(nav, text="Suppliers", fg="white", bg="#34495E", font=("Arial", 12), borderwidth=0, command=show_suppliers).pack(side="left", padx=15, pady=10)


# Main Display Frame (Renamed from 'frame' to 'main_frame' but kept as 'frame' to minimize global changes)
frame = tk.Frame(root, bg="#ECF0F1")
frame.pack(expand=True, fill="both")

# -------------------------------
# Start with Inventory Page
show_inventory()

root.mainloop()

# Close the database connection when the application exits
if conn:
    conn.close()
