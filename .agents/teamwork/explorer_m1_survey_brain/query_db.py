import sqlite3
import os
import glob
import json

db_path = r'C:\Users\Admin\.gemini\antigravity\conversation_summaries.db'
if not os.path.exists(db_path):
    print("Database not found directly at", db_path)
    # Search in C:\Users\Admin\.gemini\antigravity
    for r, d, fs in os.walk(r'C:\Users\Admin\.gemini\antigravity'):
        for f in fs:
            if f.endswith('.db'):
                print("Found DB:", os.path.join(r, f))
else:
    print("Connecting to", db_path)
    conn = sqlite3.connect(db_path)
    cur = conn.cursor()
    cur.execute("SELECT name FROM sqlite_master WHERE type='table';")
    tables = cur.fetchall()
    print("Tables:", tables)
    for t in tables:
        tname = t[0]
        cur.execute(f"PRAGMA table_info('{tname}');")
        cols = cur.fetchall()
        print(f"\n--- Table: {tname} ---")
        print("Columns:", [c[1] for c in cols])
        cur.execute(f"SELECT COUNT(*) FROM '{tname}';")
        print("Row count:", cur.fetchone()[0])
        cur.execute(f"SELECT * FROM '{tname}' LIMIT 3;")
        sample = cur.fetchall()
        print("Sample rows:")
        for row in sample:
            print(row[:5])
