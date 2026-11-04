import os
import sys
import re

sys.stdout.reconfigure(encoding='utf-8', errors='backslashreplace')

qt_plugin_path = r"C:\Program Files (x86)\VideoLAN\VLC\plugins\gui\libqt_plugin.dll"

patterns = [
    rb"MediaLibrary[A-Za-z0-9_]*",
    rb"FileBrowser[A-Za-z0-9_]*",
    rb"Directory[A-Za-z0-9_]*",
    rb"QFileSystem[A-Za-z0-9_]*",
    rb"QDirModel[A-Za-z0-9_]*",
    rb"QTreeView[A-Za-z0-9_]*",
    rb"StandardPaths[A-Za-z0-9_]*",
    rb"ServicesDiscovery[A-Za-z0-9_]*",
    rb"PLItem[A-Za-z0-9_]*",
    rb"PLModel[A-Za-z0-9_]*",
    rb"Playlist[A-Za-z0-9_]*",
    rb"[A-Za-z0-9_]*Watcher[A-Za-z0-9_]*",
    rb"[A-Za-z0-9_]*Rescan[A-Za-z0-9_]*",
    rb"[A-Za-z0-9_]*Preparse[A-Za-z0-9_]*",
    rb"directory://[A-Za-z0-9_/]*",
    rb"file://[A-Za-z0-9_/]*",
    rb"ml\.xspf"
]

print(f"Reading {qt_plugin_path}...")
with open(qt_plugin_path, "rb") as f:
    content = f.read()

print(f"File size: {len(content)} bytes")

matches = {}
for p in patterns:
    found = re.findall(p, content)
    unique = sorted(list(set(s.decode('latin1', errors='replace') for s in found)))
    matches[p.decode('latin1')] = unique

for pat, m_list in matches.items():
    print(f"\n=== Pattern: {pat} (Found {len(m_list)}) ===")
    for item in m_list[:25]:
        print(f"  {item}")
    if len(m_list) > 25:
        print(f"  ... and {len(m_list) - 25} more")
