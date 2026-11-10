import os
import re

deliverable = r"d:\E-player\docs\vlc_gap_analysis.md"
print("Deliverable exists:", os.path.exists(deliverable))
if not os.path.exists(deliverable):
    exit(1)

size = os.path.getsize(deliverable)
with open(deliverable, "r", encoding="utf-8", errors="ignore") as f:
    text = f.read()

lines = text.splitlines()
print(f"File Size: {size} bytes")
print(f"Total Lines: {len(lines)}")

# Check major sections
sections = [
    "Executive Summary",
    "Comprehensive VLC Feature Inventory",
    "E-Player Baseline Architecture",
    "Comprehensive Gap Analysis Matrix",
    "Prioritized Feature Adoption Roadmap",
]

print("\n=== Major Sections Check ===")
for sec in sections:
    found = any(sec.lower() in line.lower() for line in lines)
    print(f"Section '{sec}': {'FOUND' if found else 'MISSING'}")

# Check 4 domains in Matrix
domains = [
    "CYPHER",
    "KRONOS",
    "AURA",
    "FORGE"
]
print("\n=== Analytical Domains in Matrix ===")
for dom in domains:
    found = any(f"Domain" in line and dom in line for line in lines)
    print(f"Domain '{dom}': {'FOUND' if found else 'MISSING'}")

# Parse matrix table rows
# Look for rows starting with | `CYPHER-` or `KRONOS-` or `AURA-` or `FORGE-` or similar IDs
matrix_items = []
current_domain = None
status_counts = {"Adopted": 0, "Partially Adopted": 0, "Missing": 0}

for line in lines:
    m = re.match(r'^\|\s*`([A-Z]+-\d+)`\s*\|\s*([^|]+)\|\s*([^|]+)\|\s*([^|]+)\|\s*([A-Za-z\s]+)\s*\|', line)
    if m:
        item_id = m.group(1)
        name = m.group(2).strip()
        status_raw = m.group(5).strip()
        
        status = "Unknown"
        if "Adopted" in status_raw and "Partially" not in status_raw:
            status = "Adopted"
        elif "Partially Adopted" in status_raw:
            status = "Partially Adopted"
        elif "Missing" in status_raw:
            status = "Missing"
            
        matrix_items.append((item_id, name, status))
        if status in status_counts:
            status_counts[status] += 1

print(f"\nTotal Matrix Capability Items Parsed: {len(matrix_items)}")
print(f"Status Breakdown: {status_counts}")

domain_counts = {}
for item_id, name, status in matrix_items:
    prefix = item_id.split("-")[0]
    domain_counts[prefix] = domain_counts.get(prefix, 0) + 1

print(f"Domain Breakdown: {domain_counts}")

# Check Roadmap phases
print("\n=== Roadmap Phases ===")
phases = [
    "Phase 1",
    "Phase 2",
    "Phase 3",
    "Phase 4",
]
for phase in phases:
    found = any(re.search(rf'###\s*5\.\d+\s*{phase}', line, re.IGNORECASE) for line in lines)
    print(f"Roadmap '{phase}': {'FOUND' if found else 'MISSING'}")
