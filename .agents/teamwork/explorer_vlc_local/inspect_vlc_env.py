import os
import sys
import glob

sys.stdout.reconfigure(encoding='utf-8', errors='backslashreplace')

appdata = os.environ.get("APPDATA", "")
vlc_appdata = os.path.join(appdata, "vlc")

print("=== VLC APPDATA DIRECTORY ===")
if os.path.exists(vlc_appdata):
    for root, dirs, files in os.walk(vlc_appdata):
        for f in files:
            path = os.path.join(root, f)
            print(f"{path} ({os.path.getsize(path)} bytes)")
else:
    print("VLC AppData directory does not exist.")

ml_xspf = os.path.join(vlc_appdata, "ml.xspf")
if os.path.exists(ml_xspf):
    print("\n=== ml.xspf CONTENT ===")
    with open(ml_xspf, "r", encoding="utf-8", errors="replace") as f:
        print(f.read())

qt_ini = os.path.join(vlc_appdata, "vlc-qt-interface.ini")
if os.path.exists(qt_ini):
    print("\n=== vlc-qt-interface.ini KEY SECTIONS ===")
    with open(qt_ini, "r", encoding="utf-8", errors="replace") as f:
        lines = f.readlines()
        for line in lines:
            if any(k in line.lower() for k in ["file", "dir", "path", "medialibrary", "playlist", "tree", "browse", "rescan", "watch", "view", "column", "geometry"]):
                print(line.strip())

print("\n=== SEARCHING FOR SQLITE DATABASES IN APPDATA & LOCALAPPDATA ===")
localappdata = os.environ.get("LOCALAPPDATA", "")
for base in [vlc_appdata, os.path.join(localappdata, "vlc"), os.path.join(localappdata, "VideoLAN")]:
    if os.path.exists(base):
        for root, dirs, files in os.walk(base):
            for f in files:
                if f.endswith(('.db', '.sqlite', '.sqlite3', '.db-wal', '.db-shm')):
                    print(f"Found DB: {os.path.join(root, f)}")
