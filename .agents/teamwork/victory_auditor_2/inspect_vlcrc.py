import os
import re

appdata = os.environ.get('APPDATA')
vlcrc_path = os.path.join(appdata, 'vlc', 'vlcrc')
print("Checking vlcrc at:", vlcrc_path)
print("Exists:", os.path.exists(vlcrc_path))

if os.path.exists(vlcrc_path):
    with open(vlcrc_path, 'r', encoding='utf-8', errors='ignore') as f:
        lines = f.readlines()
    print("Total lines in vlcrc:", len(lines))
    
    # Options in vlcrc look like:
    # # option-name (type)
    # or [#]option-name=value
    options = set()
    hotkeys = set()
    for line in lines:
        line = line.strip()
        # Option comments: # [option-name] or # option-name (type)
        m = re.match(r'^#\s*([a-zA-Z0-9_-]+)\s*\([a-z\s]+\)', line)
        if m:
            opt = m.group(1)
            options.add(opt)
            if opt.startswith('key-'):
                hotkeys.add(opt)
        else:
            m2 = re.match(r'^#?([a-zA-Z0-9_-]+)=', line)
            if m2:
                opt = m2.group(1)
                options.add(opt)
                if opt.startswith('key-'):
                    hotkeys.add(opt)

    print("Parsed options count:", len(options))
    print("Parsed hotkeys count:", len(hotkeys))
    
    # Check vlc-qt-interface.ini
    qt_ini = os.path.join(appdata, 'vlc', 'vlc-qt-interface.ini')
    print("\nChecking vlc-qt-interface.ini at:", qt_ini)
    print("Exists:", os.path.exists(qt_ini))
    if os.path.exists(qt_ini):
        print("Size:", os.path.getsize(qt_ini))
