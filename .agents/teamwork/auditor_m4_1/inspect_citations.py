import re

with open(r'd:\E-player\docs\vlc_gap_analysis.md', 'r', encoding='utf-8') as f:
    text = f.read()

# Check Qt layout profiles
print("=== QT PROFILES & STRINGS IN VLC_GAP_ANALYSIS ===")
for line in text.splitlines():
    if any(k in line.lower() for k in ['qt layout', 'qt interface', 'libqt_plugin', 'ctrl+h', 'minimal view']):
        print("  ", line[:120])

# Check E-Player codebase citations (file paths with .dart)
print("\n=== E-PLAYER CODEBASE CITATIONS ===")
dart_citations = re.findall(r'([a-zA-Z0-9_\-/]+\.dart(?::\d+(?:-\d+)?)?)', text)
unique_dart = sorted(set(dart_citations))
print(f"Total unique dart file/line citations: {len(unique_dart)}")
for c in unique_dart[:20]:
    print("  ", c)
