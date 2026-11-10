with open(r'd:\E-player\docs\vlc_gap_analysis.md', 'r', encoding='utf-8') as f:
    lines = f.readlines()

for idx, line in enumerate(lines, 1):
    if any(term in line.lower() for term in ['1,615', '111', 'plugins.dat', '764 exports', '316 public']):
        print(f"Line {idx}: {line.strip()}")
