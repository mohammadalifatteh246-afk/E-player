import re

# Parse vlc-help.txt
with open(r'd:\E-player\vlc-help.txt', 'r', encoding='utf-8', errors='ignore') as f:
    help_text = f.read()

lines = help_text.splitlines()
print(f"Total lines in vlc-help.txt: {len(lines)}")

# Find options like --option or --no-option
# Or lines starting with "      --"
options = set()
for line in lines:
    m = re.match(r'^\s+--([a-zA-Z0-9_-]+)', line)
    if m:
        opt = m.group(1)
        if opt.startswith('no-'):
            opt = opt[3:]
        options.add(opt)

print(f"Unique CLI options parsed from vlc-help.txt: {len(options)}")

# Let's check hotkeys in vlc-help.txt or vlcrc
hotkeys = [opt for opt in options if 'key-' in opt or opt.startswith('key-')]
print(f"Hotkey options count: {len(hotkeys)}")

# Let's inspect explorer_cypher_1 findings on CLI options and hotkeys
with open(r'd:\E-player\.agents\teamwork\explorer_cypher_1\handoff.md', 'r', encoding='utf-8', errors='ignore') as f:
    cypher_handoff = f.read()

print("Cypher handoff mentions:")
for line in cypher_handoff.splitlines():
    if any(k in line.lower() for k in ['1615', '111', 'hotkey', 'cli option', '360', '316', '764']):
        print("  ", line)
