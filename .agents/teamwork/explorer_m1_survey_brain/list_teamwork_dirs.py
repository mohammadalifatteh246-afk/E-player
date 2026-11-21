import os

base = r'D:\E-player\.agents\teamwork'
dirs = [d for d in os.listdir(base) if os.path.isdir(os.path.join(base, d))]
dirs.sort()
print(f"Total agent folders: {len(dirs)}")
for d in dirs:
    subfiles = os.listdir(os.path.join(base, d))
    handoff = "handoff.md" in subfiles
    briefing = "BRIEFING.md" in subfiles
    dispatch = "DISPATCH.md" in subfiles
    print(f"{d:35} | files={len(subfiles):2} | handoff={handoff} | briefing={briefing} | dispatch={dispatch}")
