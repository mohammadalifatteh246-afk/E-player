import sqlite3
import re

db_path = r"C:\Users\Admin\.gemini\antigravity\conversations\cfc27950-66d6-4efb-a9b0-7796b7589607.db"
conn = sqlite3.connect(db_path)
cur = conn.cursor()

# Get step count and first few and last few steps
cur.execute("SELECT idx, step_type, step_payload FROM steps ORDER BY idx ASC LIMIT 10;")
first_steps = cur.fetchall()
print("--- First Steps ---")
for idx, stype, payload in first_steps:
    if payload:
        strings = re.findall(rb'[\x20-\x7e\n\r\t]{5,}', payload)
        for s in strings[:3]:
            print(f"[{idx} | {stype}] {s.decode('latin1', errors='replace')[:150]}")

cur.execute("SELECT idx, step_type, step_payload FROM steps ORDER BY idx DESC LIMIT 10;")
last_steps = cur.fetchall()
print("\n--- Last Steps ---")
for idx, stype, payload in reversed(last_steps):
    if payload:
        strings = re.findall(rb'[\x20-\x7e\n\r\t]{5,}', payload)
        for s in strings[:3]:
            print(f"[{idx} | {stype}] {s.decode('latin1', errors='replace')[:150]}")
