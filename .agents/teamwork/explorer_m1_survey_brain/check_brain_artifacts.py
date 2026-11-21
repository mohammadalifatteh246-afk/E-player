import os

brain_dir = r'C:\Users\Admin\.gemini\antigravity\brain'
eplayer_cids = [
    '09df4d08-68e2-48b9-a4fd-96c82d831424', # Hermes brainstorming (current parent root)
    '21c13783-ab88-4572-9d57-807956b46fec', # Orchestrator 6
    'b5b9479d-bf07-4e2e-8ec7-7cf2dff75f5e', # Phase 2 orchestrator root
    '63171882-8b91-4476-8781-8908629f8b43', # Phase 1 orchestrator root
    '3fffc39f-a708-49cc-8ccf-a81b9418de03', # Gap analysis orchestrator root
    '02329fad-d9b2-497b-9221-ee4d8cf756ee', # VLC reverse engineering
    '0523c175-22f0-4da9-8a3f-c0f1154df65a', # Hermes memory distillation
    'cfc27950-66d6-4efb-a9b0-7796b7589607'  # Crosswalk MCP integration resumed
]

for cid in eplayer_cids:
    cp = os.path.join(brain_dir, cid)
    if os.path.exists(cp):
        files = os.listdir(cp)
        print(f"\nBrain folder for {cid}: {len(files)} items")
        for f in files:
            full = os.path.join(cp, f)
            if os.path.isdir(full):
                print(f"  [DIR] {f} ({len(os.listdir(full))} items)")
            else:
                print(f"  [FILE] {f} ({os.path.getsize(full)} bytes)")
    else:
        print(f"\nBrain folder for {cid} not found on disk")
