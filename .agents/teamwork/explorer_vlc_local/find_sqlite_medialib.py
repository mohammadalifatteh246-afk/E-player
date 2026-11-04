import os
import sys

sys.stdout.reconfigure(encoding='utf-8', errors='backslashreplace')
vlc_dir = r"C:\Program Files (x86)\VideoLAN\VLC"

sqlite_found = []
medialib_found = []

for root, dirs, files in os.walk(vlc_dir):
    for f in files:
        if f.endswith('.dll') or f.endswith('.exe'):
            path = os.path.join(root, f)
            try:
                with open(path, 'rb') as fp:
                    content = fp.read()
                    if b'sqlite' in content.lower():
                        sqlite_found.append((f, path))
                    if b'medialibrary' in content.lower():
                        medialib_found.append((f, path))
            except Exception as e:
                pass

print(f"=== Files with 'sqlite' ({len(sqlite_found)}) ===")
for name, p in sqlite_found:
    print(f"  {name} -> {p}")

print(f"\n=== Files with 'medialibrary' ({len(medialib_found)}) ===")
for name, p in medialib_found:
    print(f"  {name} -> {p}")
