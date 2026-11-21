import os

conv_dir = r'C:\Users\Admin\.gemini\antigravity\conversations'
if os.path.exists(conv_dir):
    files = os.listdir(conv_dir)
    print(f"Total entries in {conv_dir}: {len(files)}")
    for f in files[:20]:
        print(f"  {f}")
else:
    print(f"{conv_dir} does not exist!")
