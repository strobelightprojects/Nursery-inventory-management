from flask import Flask, jsonify, request
import sqlite3
import os

# --- Configuration ---
DB_NAME = "nursery.db"
app = Flask(__name__)
app.config['JSON_SORT_KEYS'] = False 

# --- Ensure DB exists (You should run your initial application once to create it) ---
if not os.path.exists(DB_NAME):
    # This is a basic error handler for the API setup
    print(f"ERROR: Database file '{DB_NAME}' not found. Please create it first.")

# -------------------------------
# Database Connection Helper
# -------------------------------
def get_db_connection():
    """Returns a new SQLite connection with Foreign Keys enabled."""
    conn = sqlite3.connect(DB_NAME)
    conn.row_factory = sqlite3.Row # Allows fetching results by column name
    conn.execute("PRAGMA foreign_keys = ON")
    return conn

# -------------------------------
# 1. PLANT CRUD ENDPOINTS (GET and POST shown)
# -------------------------------

@app.route('/plants', methods=['GET'])
def get_plants():
    """Returns a list of all products (plants)."""
    try:
        conn = get_db_connection()
        plants = conn.execute("""
            SELECT p.*, s.name AS supplier_name
            FROM products p
            LEFT JOIN suppliers s ON p.supplier_id = s.id
        """).fetchall()
        conn.close()
        
        search_term = request.args.get('search', '').strip()
        plant_list = [dict(row) for row in plants]
        
        if search_term:
            plant_list = [p for p in plant_list if search_term.lower() in p['name'].lower()]
        
        return jsonify(plant_list), 200
        
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/plants', methods=['POST'])
def add_plant():
    """Receives JSON data to add a new plant."""
    data = request.json
    
    if not all(key in data for key in ['name', 'category', 'price', 'quantity']):
        return jsonify({"error": "Missing required fields."}), 400

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
        
        return jsonify({"message": "Plant added successfully", "id": cursor.lastrowid}), 201
        
    except Exception as e:
        return jsonify({"error": f"Database error: {e}"}), 500

# NOTE: Endpoints for PUT /plants/<id>, DELETE /plants/<id>, and all /suppliers CRUD are in the previous response and assumed to be in this file.

# -------------------------------
# RUN SERVER
# -------------------------------

if __name__ == '__main__':
    print("Starting Flask API server on http://127.0.0.1:5000")
    # Setting host='127.0.0.1' ensures it only listens locally
    app.run(debug=True, host='127.0.0.1', port=5000)
