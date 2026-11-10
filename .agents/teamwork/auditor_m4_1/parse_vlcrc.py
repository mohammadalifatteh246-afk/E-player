import re

with open(r'd:\E-player\.agents\teamwork\explorer_aura_1\vlcrc_hotkeys_dump.txt', 'r', encoding='utf-8', errors='ignore') as f:
    lines = f.readlines()

config_options = set()
hotkeys = []
sections = set()

for line in lines:
    line = line.strip()
    # Sections like [qt], [mosaic]
    m_sec = re.search(r'\[([a-zA-Z0-9_-]+)\]', line)
    if m_sec:
        sections.add(m_sec.group(1))

    # Option lines like: "123: #key-play-pause=Space" or "#rmtosd-alpha=255"
    m_opt = re.search(r'#([a-zA-Z0-9_-]+)=', line)
    if m_opt:
        opt_name = m_opt.group(1)
        config_options.add(opt_name)
        if opt_name.startswith('key-') and not opt_name.startswith('global-key-'):
            hotkeys.append(opt_name)

print(f"Total lines: {len(lines)}")
print(f"Total sections: {len(sections)}")
print(f"Total unique config options: {len(config_options)}")
print(f"Total key-* hotkeys: {len(hotkeys)}")
print("Sample hotkeys (first 10):", hotkeys[:10])
