import os
import re

app_root = r"d:\E-player\app"
doc_path = r"d:\E-player\docs\vlc_gap_analysis.md"

with open(doc_path, 'r', encoding='utf-8') as f:
    text = f.read()

# Look for mentions of files in sections 3 and 4
sec3_4 = text[text.find("## 3. E-Player"):text.find("## 5. Prioritized")]

file_matches = re.findall(r'`([a-zA-Z0-9_\-/]+\.dart)`', sec3_4)
unique_files = sorted(set(file_matches))

print(f"Files referenced in Section 3 and 4: {len(unique_files)}")
all_exist = True
for f in unique_files:
    # normalize path
    rel = f
    if rel.startswith('app/'):
        rel = rel[4:]
    full = os.path.join(app_root, rel.replace('/', '\\'))
    if not os.path.exists(full):
        # check under lib
        full_lib = os.path.join(app_root, 'lib', rel.replace('/', '\\'))
        if os.path.exists(full_lib):
            full = full_lib
        else:
            print(f"NOT FOUND: {f}")
            all_exist = False
            continue
    total_lines = len(open(full, 'r', encoding='utf-8', errors='ignore').readlines())
    print(f"VERIFIED: {f} (lines: {total_lines})")

if all_exist:
    print("\nALL files cited in Section 3 & 4 exist and are genuine!")
