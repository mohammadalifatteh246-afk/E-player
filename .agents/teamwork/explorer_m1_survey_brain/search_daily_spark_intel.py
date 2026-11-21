import os

search_paths = [
    r'D:\E-player',
    r'C:\Users\Admin\.gemini',
    r'C:\Users\Admin\AppData\Local\hermes',
    r'D:\Agents workespaces',
    r'D:\overload'
]

target = 'daily-spark-intel'

print(f"Searching for '{target}'...")
for sp in search_paths:
    if not os.path.exists(sp):
        print(f"Path does not exist: {sp}")
        continue
    for root, dirs, files in os.walk(sp):
        # check filename or contents
        for f in files:
            if target in f.lower() or 'spark-intel' in f.lower():
                print(f"MATCH FILE: {os.path.join(root, f)}")
            elif f.endswith(('.md', '.py', '.json', '.yaml', '.yml', '.txt', '.dart')):
                try:
                    fpath = os.path.join(root, f)
                    with open(fpath, 'r', encoding='utf-8', errors='ignore') as fp:
                        content = fp.read()
                        if target in content.lower():
                            print(f"MATCH CONTENT in {fpath}")
                except Exception as e:
                    pass
print("Done searching.")
