import os
import sys

sys.stdout.reconfigure(encoding='utf-8', errors='backslashreplace')
vlcrc_path = os.path.join(os.environ.get("APPDATA", ""), "vlc", "vlcrc")

with open(vlcrc_path, "r", encoding="utf-8", errors="replace") as f:
    for line_no, line in enumerate(f, 1):
        l_lower = line.lower()
        if "media-library" in l_lower or "medialibrary" in l_lower or "media_library" in l_lower or "library" in l_lower or "watcher" in l_lower or "rescan" in l_lower or "browse" in l_lower:
            print(f"L{line_no}: {line.strip()}")
