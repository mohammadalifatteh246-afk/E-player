import os

base = r'D:\E-player\.agents\teamwork'
target_folders = [
    'orchestrator_1', 'orchestrator_2', 'orchestrator_3', 'orchestrator_4', 
    'orchestrator_5', 'orchestrator_remediation', 'victory_auditor', 
    'victory_auditor_2', 'auditor_victory_phase2', 'auditor_victory_phase2_final',
    'test_verifier_rea_ledger'
]

for tf in target_folders:
    dir_path = os.path.join(base, tf)
    if not os.path.exists(dir_path):
        print(f"Folder {tf} not found")
        continue
    print(f"\n==================== {tf} ====================")
    for fname in ['BRIEFING.md', 'handoff.md', 'PERSISTENT_REA_LEDGER.md', 'SCOPE.md']:
        fpath = os.path.join(dir_path, fname)
        if os.path.exists(fpath):
            size = os.path.getsize(fpath)
            print(f"--- {fname} ({size} bytes) ---")
            with open(fpath, 'r', encoding='utf-8', errors='replace') as f:
                content = f.read()
                # Print lines containing mission, conclusion, key findings
                lines = content.split('\n')
                head = lines[:35]
                print('\n'.join(head))
                if len(lines) > 35:
                    print("... [truncated] ...")
                    # find ## Conclusion or ## 4. Conclusion
                    for i, l in enumerate(lines):
                        if "Conclusion" in l or "Summary" in l or "Status" in l:
                            print(f"\n>>> Section near line {i}:")
                            print('\n'.join(lines[i:i+20]))
                            break
