import sqlite3
import json

db_path = r'C:\Users\Admin\.gemini\antigravity\conversation_summaries.db'
conn = sqlite3.connect(db_path)
cur = conn.cursor()

query = """
SELECT conversation_id, title, preview, step_count, last_modified_time, workspace_uris, parent_conversation_id, nesting_depth, raw_summary
FROM conversation_summaries
WHERE workspace_uris LIKE '%E-player%' 
   OR preview LIKE '%E-player%' 
   OR title LIKE '%E-player%'
   OR preview LIKE '%E-Player%'
   OR title LIKE '%E-Player%'
   OR raw_summary LIKE '%E-player%'
   OR raw_summary LIKE '%E-Player%'
ORDER BY last_modified_time ASC;
"""

cur.execute(query)
rows = cur.fetchall()
print(f"Found {len(rows)} matching conversations:")
for r in rows:
    cid, title, preview, steps, mtime, w_uris, parent, depth, raw_summary = r
    print(f"\nID: {cid}")
    print(f"Time: {mtime} | Steps: {steps} | Depth: {depth} | Parent: {parent}")
    print(f"Title: {title}")
    print(f"Workspace: {w_uris}")
    print(f"Preview: {preview[:150] if preview else ''}")
    if raw_summary:
        print(f"Raw Summary: {raw_summary[:200]}")
