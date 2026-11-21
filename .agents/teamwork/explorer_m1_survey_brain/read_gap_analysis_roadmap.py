import re

gap_file = r'D:\E-player\docs\vlc_gap_analysis.md'
with open(gap_file, 'r', encoding='utf-8', errors='ignore') as f:
    text = f.read()

# Find section 5 or Phase 3 / Phase 4
m = re.search(r'(## 5\..*)', text, re.DOTALL)
if m:
    sec5 = m.group(1)
    # print up to 200 lines
    for line in sec5.split('\n')[:180]:
        print(line)
else:
    print("Section 5 not found by regex")
