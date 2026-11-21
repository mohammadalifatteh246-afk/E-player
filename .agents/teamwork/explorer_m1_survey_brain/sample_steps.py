import sqlite3
import json

db_path = r'C:\Users\Admin\.gemini\antigravity\conversations\09df4d08-68e2-48b9-a4fd-96c82d831424.db'
conn = sqlite3.connect(db_path)
cur = conn.cursor()

cur.execute("SELECT idx, step_type, status, step_format, SUBSTR(step_payload, 1, 200) FROM steps ORDER BY idx ASC LIMIT 10;")
for row in cur.fetchall():
    print(row)
