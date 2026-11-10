import os

cypher_dir = r"d:\E-player\.agents\teamwork\explorer_cypher_1"
for root, dirs, files in os.walk(cypher_dir):
    for file in files:
        path = os.path.join(root, file)
        try:
            with open(path, "r", encoding="utf-8", errors="ignore") as f:
                content = f.read()
            if "1615" in content or "1,615" in content:
                print(f"Found in {file}:")
                for line in content.splitlines():
                    if "1615" in line or "1,615" in line:
                        print("  ", line[:120])
        except Exception as e:
            pass
