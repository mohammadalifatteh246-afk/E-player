import os

base = r'D:\E-player\.agents\teamwork'
folders = [
    'orchestrator_2', 'orchestrator_3', 'orchestrator_4', 'orchestrator_5', 
    'orchestrator_remediation', 'victory_auditor', 'victory_auditor_2',
    'auditor_victory_phase2', 'auditor_victory_phase2_final'
]

for tf in folders:
    dir_path = os.path.join(base, tf)
    if not os.path.exists(dir_path):
        continue
    print(f"\n==================== {tf} ====================")
    for fname in ['BRIEFING.md', 'handoff.md', 'progress.md']:
        fpath = os.path.join(dir_path, fname)
        if os.path.exists(fpath):
            print(f"--- {fname} ({os.path.getsize(fpath)} bytes) ---")
            with open(fpath, 'r', encoding='utf-8', errors='replace') as f:
                lines = f.readlines()
                # print first 25 lines
                for l in lines[:25]:
                    print(l.rstrip())
                # print any conclusion or summary
                for i, l in enumerate(lines):
                    if any(k in l.lower() for k in ['## conclusion', '## 4. conclusion', 'verdict', 'outcome', 'phase 1', 'phase 2']):
                        print(f"   [Line {i}]: {l.strip()}")
                        for sub in lines[i+1:i+10]:
                            print(f"      {sub.strip()}")
                        break
