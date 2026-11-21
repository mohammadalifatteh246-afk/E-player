import sqlite3

db_path = r'C:\Users\Admin\.gemini\antigravity\conversations\09df4d08-68e2-48b9-a4fd-96c82d831424.db'
conn = sqlite3.connect(db_path)
cur = conn.cursor()
cur.execute("SELECT name FROM sqlite_master WHERE type='table';")
tables = cur.fetchall()
print("Tables in conversation db:", tables)
for t in tables:
    tname = t[0]
    cur.execute(f"PRAGMA table_info('{tname}');")
    print(f"Columns in {tname}:", [c[1] for c in cur.fetchall()])
    cur.execute(f"SELECT COUNT(*) FROM '{tname}';")
    print(f"Count in {tname}:", cur.fetchone()[0])
