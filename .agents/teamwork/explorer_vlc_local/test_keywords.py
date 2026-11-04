import os
import sys

sys.stdout.reconfigure(encoding='utf-8', errors='backslashreplace')
vlc_dir = r"C:\Program Files (x86)\VideoLAN\VLC"

keywords = [b'media_library', b'media-library', b'medialibrary', b'sqlite', b'watcher', b'inotify', b'readdirectorychanges']
results = {k: [] for k in keywords}

for root, dirs, files in os.walk(vlc_dir):
    for f in files:
        if f.endswith('.dll') or f.endswith('.exe'):
            path = os.path.join(root, f)
            try:
                with open(path, 'rb') as fp:
                    content = fp.read().lower()
                    for k in keywords:
                        if k in content:
                            results[k].append(f)
            except Exception as e:
                pass

for k, matches in results.items():
    print(f"=== Keyword: {k.decode('latin1')} ({len(matches)}) ===")
    for m in set(matches):
        print(f"  {m}")
