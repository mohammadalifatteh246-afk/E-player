import os
import re
import sys

sys.stdout.reconfigure(encoding='utf-8')

app_root = r"d:\E-player\app"
doc_path = r"d:\E-player\docs\vlc_gap_analysis.md"

with open(doc_path, 'r', encoding='utf-8') as f:
    text = f.read()

print("=== CHECKING QT PROFILES IN DOCUMENT ===")
for line in text.splitlines():
    if any(k in line.lower() for k in ['qt layout', 'qt interface', 'libqt_plugin', 'ctrl+h', 'minimal view', 'presentation modes']):
        # Replace unprintable characters if any
        clean_line = line.encode('ascii', errors='replace').decode('ascii')
        print("  ", clean_line[:120])

print("\n=== VERIFYING EMPIRICAL FILE SIZE OF LIBQT_PLUGIN.DLL ===")
qt_path = r"C:\Program Files (x86)\VideoLAN\VLC\plugins\gui\libqt_plugin.dll"
if os.path.exists(qt_path):
    sz = os.path.getsize(qt_path)
    print(f"libqt_plugin.dll exists: {sz} bytes ({sz / (1024*1024):.2f} MB)")
else:
    print("libqt_plugin.dll DOES NOT EXIST!")

print("\n=== EXTRACTING AND VERIFYING E-PLAYER DART CITATIONS ===")
# Pattern matches paths like lib/features/.../*.dart or app/lib/.../*.dart
pattern = r'(?:app/)?(lib/[a-zA-Z0-9_\-/]+\.dart)(?::(\d+)(?:-(\d+))?)?'
matches = re.findall(pattern, text)

print(f"Total raw Dart citations found: {len(matches)}")

files_checked = {}
for rel_path, start_line, end_line in matches:
    full_path = os.path.join(app_root, rel_path.replace('/', '\\'))
    if full_path not in files_checked:
        exists = os.path.exists(full_path)
        total_lines = 0
        if exists:
            with open(full_path, 'r', encoding='utf-8', errors='ignore') as f:
                total_lines = len(f.readlines())
        files_checked[full_path] = (exists, total_lines)

    exists, total_lines = files_checked[full_path]
    status = "EXISTS" if exists else "MISSING"
    line_info = f"lines {start_line}-{end_line}" if start_line else "no line"
    # Verify line bounds if specified
    line_valid = True
    if start_line and exists:
        s = int(start_line)
        e = int(end_line) if end_line else s
        if s > total_lines or e > total_lines:
            line_valid = False

    if not exists:
        print(f"FAILED (MISSING FILE): {rel_path}")
    elif not line_valid:
        print(f"WARNING (LINE OUT OF BOUNDS): {rel_path}:{start_line}-{end_line} (total lines: {total_lines})")

print(f"\nUnique Dart files cited: {len(files_checked)}")
missing_files = [f for f, (ex, _) in files_checked.items() if not ex]
print(f"Total missing files: {len(missing_files)}")
if missing_files:
    for mf in missing_files:
        print(f"  Missing: {mf}")
else:
    print("ALL cited Dart files EXIST in d:\\E-player\\app!")

print("\nSample of cited files and their actual total lines:")
for f, (ex, lines) in list(files_checked.items())[:15]:
    rel = os.path.relpath(f, app_root)
    print(f"  {rel}: {lines} lines (EXISTS: {ex})")
