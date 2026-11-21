import sqlite3

db_path = r'C:\Users\Admin\.gemini\antigravity\conversation_summaries.db'
conn = sqlite3.connect(db_path)
cur = conn.cursor()

query = """
SELECT conversation_id, title, preview, step_count, last_modified_time, parent_conversation_id, nesting_depth, workspace_uris
FROM conversation_summaries
WHERE last_modified_time >= '2026-11-12'
ORDER BY last_modified_time ASC;
"""

cur.execute(query)
rows = cur.fetchall()
print(f"Total conversations on Nov 12: {len(rows)}")
for r in rows:
    cid, title, preview, steps, mtime, parent, depth, w_uris = r
    print(f"[{mtime}] depth={depth} steps={steps} ID={cid} Parent={parent}")
    print(f"   Title: {title}")
    print(f"   Workspace: {w_uris}")
    if preview:
        print(f"   Preview: {preview.strip()[:160]}")
