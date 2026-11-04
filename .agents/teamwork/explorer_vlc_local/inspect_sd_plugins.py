import os
import sys
import re

sys.stdout.reconfigure(encoding='utf-8', errors='backslashreplace')

plugins_to_check = [
    r"C:\Program Files (x86)\VideoLAN\VLC\plugins\services_discovery\libmediadirs_plugin.dll",
    r"C:\Program Files (x86)\VideoLAN\VLC\plugins\services_discovery\libwindrive_plugin.dll",
    r"C:\Program Files (x86)\VideoLAN\VLC\plugins\access\libfilesystem_plugin.dll",
    r"C:\Program Files (x86)\VideoLAN\VLC\plugins\misc\libaddonsfsstorage_plugin.dll"
]

for p in plugins_to_check:
    print(f"\n==========================================")
    print(f"FILE: {p}")
    if not os.path.exists(p):
        print("Not found")
        continue
    with open(p, "rb") as f:
        data = f.read()
    
    # Extract strings longer than 4 chars
    ascii_strings = [s.decode('latin1', errors='replace') for s in re.findall(rb"[A-Za-z0-9_/:.\-]{4,}", data)]
    # Filter for interesting strings
    interesting = [s for s in ascii_strings if any(k in s.lower() for k in ["dir", "folder", "media", "music", "video", "picture", "drive", "watch", "scan", "my ", "read", "file", "open", "browse", "user"])]
    print(f"Total ASCII strings: {len(ascii_strings)}, Matching interesting: {len(interesting)}")
    for s in interesting[:40]:
        print("  ", s)
