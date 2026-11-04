import os
import sys

sys.stdout.reconfigure(encoding='utf-8', errors='backslashreplace')
vlcrc_path = os.path.join(os.environ.get("APPDATA", ""), "vlc", "vlcrc")

keywords = [
    "media-library", "medialibrary", "ml", "directory", "folder",
    "watcher", "rescan", "scan", "discover", "services-discovery",
    "services_discovery", "subdirs", "recursive", "file-caching",
    "playlist", "auto-preparse", "preparse", "fetch-meta", "art", "sqlite"
]

found = {}
with open(vlcrc_path, "r", encoding="utf-8", errors="replace") as f:
    current_comment = []
    for line in f:
        line_s = line.strip()
        if line_s.startswith("#"):
            current_comment.append(line_s)
            if len(current_comment) > 5:
                current_comment.pop(0)
        elif line_s:
            # option line or section
            for kw in keywords:
                if kw in line_s.lower() or any(kw in c.lower() for c in current_comment):
                    found[line_s] = list(current_comment)
            current_comment = []

print(f"Total matching config items: {len(found)}")
for opt, comments in list(found.items())[:40]:
    print("---")
    for c in comments[-3:]:
        print(c)
    print("SETTING:", opt)
