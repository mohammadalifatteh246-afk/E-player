import os

base = r'D:\E-player\.agents\teamwork'
for tf in ['orchestrator_3', 'orchestrator_4', 'orchestrator_5', 'orchestrator_remediation']:
    bpath = os.path.join(base, tf, 'BRIEFING.md')
    hpath = os.path.join(base, tf, 'handoff.md')
    print(f"=== {tf} ===")
    if os.path.exists(bpath):
        with open(bpath, 'r', encoding='utf-8', errors='replace') as f:
            for l in f.readlines()[:25]:
                print(l.rstrip())
    if os.path.exists(hpath):
        print(f"--- handoff.md ---")
        with open(hpath, 'r', encoding='utf-8', errors='replace') as f:
            for l in f.readlines()[:25]:
                print(l.rstrip())
    print("\n")
