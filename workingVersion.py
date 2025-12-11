import tkinter as tk
from tkinter import ttk, messagebox, filedialog
import sqlite3
from PIL import Image, ImageTk # Requires 'pip install Pillow'
import os
import shutil

# --- Configuration ---
DB_NAME = "nursery.db"
ASSETS_DIR = "assets"

# -------------------------------
# File Setup and SQLite Database Setup
# -------------------------------

# Create assets directory if it doesn't exist for storing images
if not os.path.exists(ASSETS_DIR):
    os.makedirs(ASSETS_DIR)

conn = sqlite3.connect(DB_NAME)
cursor = conn.cursor()

# 1. Update Suppliers Table (No change, but keep it here for structure)
cursor.execute("""
CREATE TABLE IF NOT EXISTS suppliers (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT UNIQUE, 
    contact_person TEXT,
    email TEXT,
    phone TEXT,
    address TEXT
)
""")

# 2. Update Products Table: ADD 'image_path' column
cursor.execute("""
CREATE TABLE IF NOT EXISTS products (
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
    image_path TEXT, -- New Column for Requirement 1
    FOREIGN KEY(supplier_id) REFERENCES suppliers(id)
)
""")

# Add image_path column if it doesn't exist (for existing databases)
try:
    cursor.execute("SELECT image_path FROM products LIMIT 1")
except sqlite3.OperationalError:
    cursor.execute("ALTER TABLE products ADD COLUMN image_path TEXT")

# Keep other tables (orders, order_items) for completeness
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
# Global Variables and Helpers
# -------------------------------
root = tk.Tk()
root.title("Nursery Inventory Management")
root.geometry("1000x700")

# To store the path of the image selected in the modal
selected_image_path = "" 
search_var = tk.StringVar()
search_var.trace_add("write", lambda *args: show_inventory())

def clear_frame():
    """Destroys all widgets in the main content frame."""
    for widget in frame.winfo_children():
        widget.destroy()

def create_entry_row(container, label_text, row_index, default_value=""):
    """Helper to create a Label and Entry field pair."""
    tk.Label(container, text=label_text).grid(row=row_index, column=0, sticky="e", padx=5, pady=5)
    entry = tk.Entry(container)
    entry.grid(row=row_index, column=1, sticky="w", padx=5, pady=5)
    entry.insert(0, default_value)
    return entry

def copy_image_file(source_path):
    """Copies an image from source to the assets directory and returns the new relative path."""
    if not source_path:
        return ""
    
    filename = os.path.basename(source_path)
    destination_path = os.path.join(ASSETS_DIR, filename)
    
    # Use shutil.copy2 to copy file data and metadata
    try:
        shutil.copy2(source_path, destination_path)
        return destination_path
    except Exception as e:
        messagebox.showerror("Image Error", f"Failed to copy image: {e}")
        return ""

def load_image_for_display(path, size=(100, 100)):
    """Loads an image from a path, resizes it, and returns a Tkinter PhotoImage."""
    default_path = "default_plant.png" # You'd usually have a default image here

    # Use the path if it exists, otherwise check for a default image
    if not path or not os.path.exists(path):
        try:
            # Fallback to a placeholder image creation if no image is found
            img = Image.new('RGB', size, color = 'gray')
            draw = tk.ImageDraw(img) # This requires ImageDraw from PIL
            draw.text((10,10), "No Image", fill=(255,255,255))
            return ImageTk.PhotoImage(img)
        except Exception:
             # Basic placeholder if PIL draw isn't working
            return ImageTk.PhotoImage(Image.new('RGB', size, color='gray'))

    try:
        img = Image.open(path)
        img = img.resize(size, Image.Resampling.LANCZOS)
        return ImageTk.PhotoImage(img)
    except Exception as e:
        print(f"Error loading image {path}: {e}")
        return ImageTk.PhotoImage(Image.new('RGB', size, color='red'))


# -------------------------------
# Core View Functions
# -------------------------------

def show_inventory():
    """Displays the main inventory list with search and details."""
    clear_frame()
    
    # Top Control Bar (Search and Buttons)
    control_frame = tk.Frame(frame); control_frame.pack(fill="x", pady=10, padx=10)
    
    tk.Label(control_frame, text="Inventory", font=("Arial", 20)).pack(side="left")
    
    # Search Bar (Requirement 2)
    tk.Entry(control_frame, textvariable=search_var, width=30, 
             font=("Arial", 12)).pack(side="left", padx=20, fill="x", expand=True)
    tk.Label(control_frame, text="Search Name:").pack(side="left")
    
    tk.Button(control_frame, text="Restock", bg="#4CAF50", fg="white", command=restock_product).pack(side="right", padx=5)
    tk.Button(control_frame, text="+ Add Product", bg="#4CAF50", fg="white", command=lambda: product_modal()).pack(side="right", padx=5)

    # Treeview Setup
    tree = ttk.Treeview(frame, columns=("ID", "Name", "Category", "SKU", "Price", "Stock", "Supplier"), show="headings")
    tree.heading("ID", text="ID"); tree.column("ID", width=0, stretch=tk.NO) # Hidden ID column
    tree.heading("Name", text="Name"); tree.heading("Category", text="Category")
    tree.heading("SKU", text="SKU"); tree.heading("Price", text="Price")
    tree.heading("Stock", text="Stock"); tree.heading("Supplier", text="Supplier")
    tree.pack(expand=True, fill="both", padx=10, pady=10)
    
    # Bind double click for detail/edit view
    tree.bind("<Double-1>", lambda event: show_product_details(tree.selection()[0], tree))

    # Fetch and filter data
    search_term = search_var.get().strip()
    
    query = """
        SELECT p.id, p.name, p.category, p.sku, p.price, p.quantity, s.name
        FROM products p LEFT JOIN suppliers s ON p.supplier_id = s.id
    """
    params = ()
    
    if search_term:
        query += " WHERE p.name LIKE ?"
        params = (f'%{search_term}%',)
        
    rows = cursor.execute(query, params).fetchall()
    
    for row in rows:
        tree.insert("", tk.END, iid=row[0], values=row)

    if not rows and not search_term:
        tk.Label(frame, text="No products found.", fg="gray").pack(pady=20)


def show_product_details(item_id, tree):
    """Displays a detailed view of a product, including its image."""
    product_id = tree.item(item_id, 'values')[0]
    
    details = cursor.execute("""
        SELECT p.id, p.name, p.category, p.description, p.sku, p.price, p.cost_price, 
               p.quantity, p.reorder_at, s.name, p.image_path
        FROM products p LEFT JOIN suppliers s ON p.supplier_id = s.id
        WHERE p.id = ?
    """, (product_id,)).fetchone()
    
    if not details: return

    # Unpack details
    (id, name, category, desc, sku, price, cost, quantity, reorder, supplier, image_path) = details
    
    detail_window = tk.Toplevel(root)
    detail_window.title(f"Details: {name}")

    # Image Display (Requirement 1)
    img_frame = tk.Frame(detail_window); img_frame.pack(pady=10)
    
    # Load and store the image reference globally or on the widget to prevent garbage collection
    detail_window.photo = load_image_for_display(image_path, size=(200, 200)) 
    img_label = tk.Label(img_frame, image=detail_window.photo)
    img_label.pack(side="left", padx=20)
    
    # Text Details
    info_frame = tk.Frame(img_frame); info_frame.pack(side="left", anchor="n")
    
    tk.Label(info_frame, text=f"Name: {name}", font=("Arial", 16, "bold")).pack(anchor="w")
    tk.Label(info_frame, text=f"Category: {category}").pack(anchor="w")
    tk.Label(info_frame, text=f"SKU: {sku}").pack(anchor="w")
    tk.Label(info_frame, text=f"Stock: {quantity} (Reorder at: {reorder})", fg="blue" if quantity <= reorder else "black").pack(anchor="w")
    tk.Label(info_frame, text=f"Price: ${price:.2f} | Cost: ${cost:.2f}").pack(anchor="w")
    tk.Label(info_frame, text=f"Supplier: {supplier or 'N/A'}").pack(anchor="w")
    
    tk.Label(detail_window, text="Description:", font=("Arial", 10, "underline")).pack(pady=5)
    tk.Label(detail_window, text=desc, wraplength=400, justify="left").pack(padx=20)

    # Control Buttons
    btn_frame = tk.Frame(detail_window); btn_frame.pack(pady=15)
    
    tk.Button(btn_frame, text="Edit Details", bg="#FFC107", fg="black", 
              command=lambda: [detail_window.destroy(), product_modal(id)]).pack(side="left", padx=10)
    
    tk.Button(btn_frame, text="Delete Product", bg="#F44336", fg="white", 
              command=lambda: delete_product(id, name, detail_window)).pack(side="left", padx=10)

# -------------------------------
# Supplier CRUD (Requirement 3: Full CRUD)
# -------------------------------

def show_suppliers():
    """Displays the supplier list and binds double-click to edit."""
    clear_frame()
    header_frame = tk.Frame(frame)
    header_frame.pack(fill="x", pady=5, padx=10)

    tk.Label(header_frame, text="Suppliers", font=("Arial", 20)).pack(side="left")
    tk.Button(header_frame, text="+ Add Supplier", bg="#4CAF50", fg="white", command=lambda: supplier_modal()).pack(side="right", padx=5)

    tree = ttk.Treeview(frame, columns=("ID", "Name", "Contact Person", "Email", "Phone", "Address"), show="headings")
    tree.heading("ID", text="ID"); tree.column("ID", width=0, stretch=tk.NO) # Hidden ID column
    tree.heading("Name", text="Name"); tree.heading("Contact Person", text="Contact Person")
    tree.heading("Email", text="Email"); tree.heading("Phone", text="Phone"); tree.heading("Address", text="Address")
    tree.pack(expand=True, fill="both", padx=10, pady=10)

    # Bind double click for editing (Requirement 3)
    tree.bind("<Double-1>", lambda event: supplier_modal(tree.item(tree.selection()[0], 'values')[0]))

    rows = cursor.execute("SELECT id, name, contact_person, email, phone, address FROM suppliers").fetchall()
    for row in rows:
        tree.insert("", tk.END, values=row)

    if not rows:
        tk.Label(frame, text="No suppliers found.", fg="gray").pack(pady=20)


def delete_supplier(supplier_id, supplier_name, parent_window):
    """Deletes a supplier after confirmation."""
    # Check if supplier is linked to any products
    linked_products = cursor.execute("SELECT COUNT(*) FROM products WHERE supplier_id=?", (supplier_id,)).fetchone()[0]
    
    if linked_products > 0:
        messagebox.showerror("Cannot Delete", f"Supplier '{supplier_name}' is linked to {linked_products} products and cannot be deleted.")
        return

    if messagebox.askyesno("Confirm Delete", f"Are you sure you want to delete supplier: {supplier_name}?"):
        try:
            cursor.execute("DELETE FROM suppliers WHERE id=?", (supplier_id,))
            conn.commit()
            parent_window.destroy()
            show_suppliers()
        except Exception as e:
            messagebox.showerror("Error", f"Could not delete supplier: {e}")

# -------------------------------
# Modals (Add/Edit)
# -------------------------------

def supplier_modal(supplier_id=None):
    """Modal for adding a new supplier or editing an existing one."""
    global selected_image_path
    
    top = tk.Toplevel(root)
    is_editing = supplier_id is not None
    top.title("Edit Supplier" if is_editing else "Add Supplier")
    
    current_data = {}
    if is_editing:
        current_data = cursor.execute("SELECT name, contact_person, email, phone, address FROM suppliers WHERE id=?", 
                                      (supplier_id,)).fetchone()
    
    # Input Fields
    name = create_entry_row(top, "Company Name", 0, current_data[0] if current_data else "")
    contact = create_entry_row(top, "Contact Person", 1, current_data[1] if current_data else "")
    email = create_entry_row(top, "Email", 2, current_data[2] if current_data else "")
    phone = create_entry_row(top, "Phone", 3, current_data[3] if current_data else "")
    
    tk.Label(top, text="Address").grid(row=4, column=0, sticky="e", padx=5, pady=5)
    address = tk.Text(top, height=3, width=30); address.grid(row=4, column=1, padx=5, pady=5)
    if current_data: address.insert("1.0", current_data[4])
        
    def save_supplier():
        """Handles both INSERT and UPDATE logic."""
        if is_editing:
            try:
                cursor.execute("""
                    UPDATE suppliers SET name=?, contact_person=?, email=?, phone=?, address=?
                    WHERE id=?
                """, (name.get(), contact.get(), email.get(), phone.get(), address.get("1.0", tk.END), supplier_id))
                conn.commit()
                messagebox.showinfo("Success", "Supplier updated successfully.")
            except sqlite3.IntegrityError:
                messagebox.showerror("Error", "Supplier name already exists.")
            except Exception as e:
                messagebox.showerror("Error", f"Failed to update supplier: {e}")
        else:
            try:
                cursor.execute("""
                    INSERT INTO suppliers (name, contact_person, email, phone, address)
                    VALUES (?, ?, ?, ?, ?)
                """, (name.get(), contact.get(), email.get(), phone.get(), address.get("1.0", tk.END)))
                conn.commit()
                messagebox.showinfo("Success", "Supplier added successfully.")
            except sqlite3.IntegrityError:
                messagebox.showerror("Error", "Supplier name already exists.")

        top.destroy()
        show_suppliers()

    # Buttons Frame
    btn_row = tk.Frame(top); btn_row.grid(row=5, column=0, columnspan=2, pady=10)
    
    tk.Button(btn_row, text="Save", bg="#4CAF50", fg="white", command=save_supplier).pack(side="left", padx=5)
    
    if is_editing:
        tk.Button(btn_row, text="Delete", bg="#F44336", fg="white", 
                  command=lambda: delete_supplier(supplier_id, name.get(), top)).pack(side="left", padx=5)


def product_modal(product_id=None):
    """Modal for adding or editing a product, including image upload."""
    global selected_image_path
    
    top = tk.Toplevel(root)
    is_editing = product_id is not None
    top.title("Edit Product" if is_editing else "Add Product")
    
    selected_image_path = "" # Reset global path for a new session
    current_image_db_path = ""
    
    # Fetch current data if editing
    if is_editing:
        details = cursor.execute("""
            SELECT name, category, description, sku, price, cost_price, quantity, reorder_at, supplier_id, image_path
            FROM products WHERE id = ?
        """, (product_id,)).fetchone()
        
        supplier_name = cursor.execute("SELECT name FROM suppliers WHERE id=?", (details[8],)).fetchone() if details[8] else "None"
        current_image_db_path = details[9] if details[9] else ""
        selected_image_path = current_image_db_path # Start with existing path

    # Input Fields
    name_entry = create_entry_row(top, "Name", 0, details[0] if is_editing else "")
    category_entry = create_entry_row(top, "Category", 1, details[1] if is_editing else "")
    sku_entry = create_entry_row(top, "SKU", 3, details[3] if is_editing else "")
    price_entry = create_entry_row(top, "Price", 4, details[4] if is_editing else "")
    cost_entry = create_entry_row(top, "Cost Price", 5, details[5] if is_editing else "")
    quantity_entry = create_entry_row(top, "Quantity", 6, details[6] if is_editing else "0")
    reorder_entry = create_entry_row(top, "Reorder At", 7, details[7] if is_editing else "5")
    
    tk.Label(top, text="Description").grid(row=2, column=0, sticky="e", padx=5, pady=5)
    desc_text = tk.Text(top, height=3, width=30); desc_text.grid(row=2, column=1, padx=5, pady=5)
    if is_editing: desc_text.insert("1.0", details[2])

    # Supplier Dropdown
    tk.Label(top, text="Supplier").grid(row=8, column=0, sticky="e", padx=5, pady=5)
    supplier_names = ["None"] + [row[0] for row in cursor.execute("SELECT name FROM suppliers").fetchall()]
    supplier_combo = ttk.Combobox(top, values=supplier_names)
    supplier_combo.grid(row=8, column=1, padx=5, pady=5)
    supplier_combo.set(supplier_name[0] if is_editing and supplier_name else "None")

    # Image Upload (Requirement 1)
    tk.Label(top, text="Image").grid(row=9, column=0, sticky="e", padx=5, pady=5)
    image_frame = tk.Frame(top); image_frame.grid(row=9, column=1, sticky="w", padx=5, pady=5)
    
    image_display_label = tk.Label(image_frame)
    image_display_label.pack(side="left", padx=5)

    def select_image():
        """Opens file dialog and updates the display/global path."""
        global selected_image_path
        file_path = filedialog.askopenfilename(
            filetypes=[("Image files", "*.jpg *.jpeg *.png")]
        )
        if file_path:
            selected_image_path = file_path
            top.photo = load_image_for_display(file_path, size=(50, 50))
            image_display_label.config(image=top.photo)

    # Initial image display (if editing)
    if current_image_db_path:
        top.photo = load_image_for_display(current_image_db_path, size=(50, 50))
        image_display_label.config(image=top.photo)
    
    tk.Button(image_frame, text="Upload/Change Image", command=select_image).pack(side="left", padx=5)

    def save_product():
        """Handles both INSERT and UPDATE logic for products."""
        global selected_image_path
        
        # 1. Get supplier ID
        supplier_name = supplier_combo.get()
        supplier_id = None
        if supplier_name != "None":
            supplier_id_row = cursor.execute("SELECT id FROM suppliers WHERE name=?", (supplier_name,)).fetchone()
            supplier_id = supplier_id_row[0] if supplier_id_row else None

        # 2. Handle Image Copying
        final_image_path = current_image_db_path # Default to old path if nothing new is selected
        
        if selected_image_path and selected_image_path != current_image_db_path:
            # Only copy if a new path was selected
            final_image_path = copy_image_file(selected_image_path) 
        
        # 3. Save to DB
        if is_editing:
            cursor.execute("""
                UPDATE products SET name=?, category=?, description=?, sku=?, price=?, cost_price=?, 
                quantity=?, reorder_at=?, supplier_id=?, image_path=?
                WHERE id=?
            """, (name_entry.get(), category_entry.get(), desc_text.get("1.0", tk.END), sku_entry.get(), 
                  float(price_entry.get()), float(cost_entry.get()), int(quantity_entry.get()), 
                  int(reorder_entry.get()), supplier_id, final_image_path, product_id))
            messagebox.showinfo("Success", "Product updated.")
        else:
            cursor.execute("""
                INSERT INTO products (name, category, description, sku, price, cost_price, quantity, reorder_at, supplier_id, image_path)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """, (name_entry.get(), category_entry.get(), desc_text.get("1.0", tk.END), sku_entry.get(), 
                  float(price_entry.get()), float(cost_entry.get()), int(quantity_entry.get()), 
                  int(reorder_entry.get()), supplier_id, final_image_path))
            messagebox.showinfo("Success", "Product added.")
            
        conn.commit()
        top.destroy()
        show_inventory()

    tk.Button(top, text="Save", bg="#4CAF50", fg="white", command=save_product).grid(row=10, column=0, columnspan=2, pady=10)


def delete_product(product_id, product_name, parent_window):
    """Deletes a product after confirmation."""
    if messagebox.askyesno("Confirm Delete", f"Are you sure you want to delete product: {product_name}?"):
        cursor.execute("DELETE FROM products WHERE id=?", (product_id,))
        conn.commit()
        parent_window.destroy()
        show_inventory()


def restock_product():
    # Keep restock modal for completeness
    # ... (code omitted for brevity, assume this is the same as your previous version)
    pass


def create_order():
    # Keep create_order modal for completeness
    # ... (code omitted for brevity, assume this is the same as your previous version)
    pass


def show_orders():
    # Keep show_orders view for completeness
    # ... (code omitted for brevity, assume this is the same as your previous version)
    pass


# -------------------------------
# Main GUI Setup
# -------------------------------

# Navbar
menu = tk.Frame(root, bg="#f0f0f0")
tk.Button(menu, text="Inventory", width=20, command=show_inventory).pack(side="left")
tk.Button(menu, text="Orders", width=20, command=show_orders).pack(side="left")
tk.Button(menu, text="Suppliers", width=20, command=show_suppliers).pack(side="left")
menu.pack(fill="x")

frame = tk.Frame(root)
frame.pack(expand=True, fill="both")

# Start with Inventory Page
show_inventory()

root.mainloop()

# Clean up database connection on exit
conn.close()
