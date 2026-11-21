import sqlite3
import os
import re

db_path = r'C:\Users\Admin\.gemini\antigravity\conversation_summaries.db'
conn = sqlite3.connect(db_path)
cur = conn.cursor()

keywords = ['hermes', 'spark', 'crosswalk', 'overload', 'workespaces', 'intel']
for kw in keywords:
    query = f"""
    SELECT conversation_id, title, preview, last_modified_time, step_count
    FROM conversation_summaries
    WHERE title LIKE '%{kw}%' OR preview LIKE '%{kw}%'
    ORDER BY last_modified_time DESC;
    """
    cur.execute(query)
    rows = cur.fetchall()
    print(f"\n=== Keyword: '{kw}' in conversation_summaries (Found {len(rows)}) ===")
    for r in rows[:10]:
        print(f"[{r[3]}] steps={r[4]} ID={r[0]}")
        print(f"   Title: {r[1]}")
        print(f"   Preview: {r[2][:120] if r[2] else ''}")
