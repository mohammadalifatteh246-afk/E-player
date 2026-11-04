import os
import sys

sys.stdout.reconfigure(encoding='utf-8', errors='backslashreplace')
vlcrc_path = os.path.join(os.environ.get("APPDATA", ""), "vlc", "vlcrc")

with open(vlcrc_path, "r", encoding="utf-8", errors="replace") as f:
    text = f.read()

sections = ["playlist", "folder", "qt", "mediadirs", "filesystem", "directory"]
for sec in sections:
    target = f"[{sec}]"
    idx = text.find(target)
    if idx != -1:
        end_idx = text.find("\n[", idx + len(target))
        if end_idx == -1:
            end_idx = idx + 2000
        print(f"\n==================== SECTION {target} ====================")
        print(text[idx:min(idx + 3000, end_idx)])
