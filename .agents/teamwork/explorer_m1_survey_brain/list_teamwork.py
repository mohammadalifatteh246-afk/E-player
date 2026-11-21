import os

teamwork_dir = r'D:\E-player\.agents\teamwork'
items = []
for root, dirs, files in os.walk(teamwork_dir):
    for f in files:
        full_path = os.path.join(root, f)
        rel_path = os.path.relpath(full_path, teamwork_dir)
        size = os.path.getsize(full_path)
        items.append((rel_path, size))

items.sort()
print(f"Total files in {teamwork_dir}: {len(items)}")
for rel, sz in items:
    print(f"{rel} ({sz} bytes)")
