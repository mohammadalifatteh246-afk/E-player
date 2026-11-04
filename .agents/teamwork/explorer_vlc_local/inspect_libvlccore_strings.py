import os
import sys
import re

sys.stdout.reconfigure(encoding='utf-8', errors='backslashreplace')
libvlccore_path = r"C:\Program Files (x86)\VideoLAN\VLC\libvlccore.dll"

with open(libvlccore_path, "rb") as f:
    data = f.read()

# Search for strings related to directory reading, input item, media library, and preparsing
keywords = [
    b"readdir", b"input_item", b"media-library", b"ml.xspf",
    b"ignore-filetypes", b"recursive", b"preparse", b"fetch-meta",
    b"directory://", b"file://"
]

for kw in keywords:
    matches = [m.start() for m in re.finditer(re.escape(kw), data, re.IGNORECASE)]
    print(f"\n=== Keyword: {kw.decode('latin1')} (Found {len(matches)}) ===")
    for idx in matches[:5]:
        start = max(0, idx - 60)
        end = min(len(data), idx + 80)
        snippet = data[start:end]
        # Clean printable ascii
        clean_str = "".join(chr(b) if 32 <= b <= 126 else f"\\x{b:02x}" for b in snippet)
        print(f"  @{idx}: {clean_str}")
