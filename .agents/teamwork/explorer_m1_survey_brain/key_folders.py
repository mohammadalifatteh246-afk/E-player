import os

base = r'D:\E-player\.agents\teamwork'
dirs = [d for d in os.listdir(base) if os.path.isdir(os.path.join(base, d))]

keywords = ['orch', 'auditor', 'victory', 'remediation', 'gate', 'survey', 'ledger', 'synthesis', 'preview']
matched = [d for d in dirs if any(k in d.lower() for k in keywords)]

print(f"Matched {len(matched)} key coordination folders:")
for d in sorted(matched):
    sub = os.listdir(os.path.join(base, d))
    handoff_sz = os.path.getsize(os.path.join(base, d, "handoff.md")) if "handoff.md" in sub else 0
    print(f"  {d:35} | files={len(sub):2} | handoff_size={handoff_sz}")
