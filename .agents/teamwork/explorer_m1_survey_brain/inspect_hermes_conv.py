import sqlite3
import re

def inspect_conv(cid, max_steps=50):
    db_path = f"C:\\Users\\Admin\\.gemini\\antigravity\\conversations\\{cid}.db"
    print(f"\n==================== Conv: {cid} ====================")
    conn = sqlite3.connect(db_path)
    cur = conn.cursor()
    cur.execute("SELECT idx, step_type, step_payload FROM steps ORDER BY idx ASC;")
    rows = cur.fetchall()
    print(f"Total steps: {len(rows)}")
    for idx, stype, payload in rows[:max_steps]:
        if payload:
            strings = re.findall(rb'[\x20-\x7e\n\r\t]{5,}', payload)
            for s in strings:
                text = s.decode('latin1', errors='replace')
                if any(w in text.lower() for w in ['hermes', 'crosswalk', 'spark', 'daily', 'intel', 'distill', 'mission', 'brief', 'workflow']):
                    print(f"  [Step {idx} type {stype}]: {text[:200]}")

inspect_conv("0523c175-22f0-4da9-8a3f-c0f1154df65a")
