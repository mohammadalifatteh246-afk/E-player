import sqlite3
import re

def extract_strings_from_blob(blob):
    # Extract printable ascii / utf8 substrings
    strings = re.findall(rb'[\x20-\x7e\n\r\t]{4,}', blob)
    return [s.decode('latin1', errors='replace') for s in strings]

db_path = r'C:\Users\Admin\.gemini\antigravity\conversations\09df4d08-68e2-48b9-a4fd-96c82d831424.db'
conn = sqlite3.connect(db_path)
cur = conn.cursor()

cur.execute("SELECT idx, step_type, step_payload FROM steps ORDER BY idx ASC;")
rows = cur.fetchall()
print(f"Total steps: {len(rows)}")
for idx, stype, payload in rows:
    if payload:
        # Check if contains user messages or prompt
        text_blobs = extract_strings_from_blob(payload)
        for tb in text_blobs:
            if "muje" in tb or "Analyze" in tb or "Hermes" in tb or "Original User Request" in tb or "brainstorm" in tb.lower() or "overload" in tb:
                print(f"[Step {idx} | type {stype}]")
                print(tb[:300])
                print("-" * 40)
