import re

with open(r'd:\E-player\docs\vlc_gap_analysis.md', 'r', encoding='utf-8') as f:
    text = f.read()

# Let's find each domain table
domains = ["Domain 1", "Domain 2", "Domain 3", "Domain 4"]
lines = text.splitlines()

current_domain = None
domain_rows = {}
all_rows = []

for line in lines:
    for d in domains:
        if d in line:
            current_domain = d
            domain_rows[current_domain] = []
            break
            
    if current_domain and line.startswith("| **"):
        parts = [p.strip() for p in line.split("|")[1:-1]]
        if len(parts) >= 4:
            feature = parts[0].replace("**", "")
            status_text = parts[3].replace("**", "")
            domain_rows[current_domain].append((feature, status_text))
            all_rows.append((current_domain, feature, status_text))

print("=== Domain Row Counts ===")
total = 0
status_counts = {}
for d, rows in domain_rows.items():
    print(f"{d}: {len(rows)} capabilities")
    total += len(rows)
    for f, s in rows:
        status_counts[s] = status_counts.get(s, 0) + 1

print(f"\nTotal Capabilities Across All 4 Domains: {total}")
print(f"Status Breakdown: {status_counts}")

print("\nList of all capabilities by domain:")
for d, rows in domain_rows.items():
    print(f"\n--- {d} ({len(rows)}) ---")
    for idx, (f, s) in enumerate(rows, 1):
        print(f"  {idx}. [{s}] {f}")
