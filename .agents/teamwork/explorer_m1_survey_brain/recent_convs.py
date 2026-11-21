import sqlite3

db_path = r'C:\Users\Admin\.gemini\antigravity\conversation_summaries.db'
conn = sqlite3.connect(db_path)
cur = conn.cursor()

query = """
SELECT conversation_id, title, preview, step_count, last_modified_time, parent_conversation_id, nesting_depth
FROM conversation_summaries
WHERE (workspace_uris LIKE '%E-player%' OR preview LIKE '%E-player%' OR title LIKE '%E-player%' OR preview LIKE '%Phase%' OR preview LIKE '%VLC%')
  AND last_modified_time >= '2026-11-09'
ORDER BY last_modified_time ASC;
"""

cur.execute(query)
rows = cur.fetchall()
print(f"Total conversations since Nov 9: {len(rows)}")
for r in rows:
    cid, title, preview, steps, mtime, parent, depth = r
    print(f"[{mtime}] depth={depth} steps={steps} ID={cid} Parent={parent}")
    print(f"   Title: {title}")
    if preview:
        print(f"   Preview: {preview.strip()[:160]}")
