import hashlib
import os
import sys
from pathlib import Path

def sha256_file(filepath: Path) -> str:
    h = hashlib.sha256()
    with open(filepath, "rb") as f:
        while chunk := f.read(65536):
            h.update(chunk)
    return h.hexdigest()

def main():
    root = Path("D:/E-player")
    
    # Files to verify
    skills = [
        "eplayer-flutter-video-arch",
        "eplayer-mpv-vlc-parity",
        "eplayer-native-neural-ffi",
        "eplayer-verification-guardrail",
    ]
    
    deliverables = [
        "app/lib/features/subtitles/models/subtitle_result.dart",
        "app/lib/features/subtitles/data/opensubtitles_service.dart",
        "app/lib/features/network_stream/models/network_share.dart",
        "app/lib/features/network_stream/data/network_media_service.dart",
        "app/lib/features/cast/models/cast_device.dart",
        "app/lib/features/cast/data/cast_discovery_service.dart",
        "app/test/e2e/phase1_e2e_test.dart",
        "app/test/unit/phase3_subtitles_network_cast_test.dart",
        "app/test/e2e/phase3_e2e_test.dart",
        "docs/vlc_gap_analysis.md",
    ]
    
    skill_destinations = [
        Path("D:/Agents workespaces/skills"),
        Path("D:/Agents workespaces/Core Coding & Architecture Sector/skills"),
        Path("D:/Agents workespaces/QA, Testing & Verification Sector/skills"),
        Path("D:/overload/skills"),
    ]
    
    mirror_roots = [
        Path("D:/Agents workespaces/E-player"),
        Path("D:/Agents workespaces/Core Coding & Architecture Sector/E-player"),
        Path("D:/Agents workespaces/QA, Testing & Verification Sector/E-player"),
        Path("D:/overload/E-player"),
    ]
    
    total_checks = 0
    passed_checks = 0
    failed_checks = 0
    results = []

    print("================================================================================")
    print("INDEPENDENT FORENSIC CRYPTOGRAPHIC SHA256 PARITY AUDIT")
    print("================================================================================")

    # 1. Hermes Skills Parity
    for skill in skills:
        src = root / f"skills/{skill}/SKILL.md"
        if not src.exists():
            print(f"[ERROR] Source skill missing: {src}")
            failed_checks += 1
            continue
        src_hash = sha256_file(src)
        
        # Check skill destinations
        for dst_dir in skill_destinations:
            total_checks += 1
            dst = dst_dir / f"{skill}/SKILL.md"
            if not dst.exists():
                print(f"[FAIL] Missing target: {dst}")
                failed_checks += 1
                continue
            dst_hash = sha256_file(dst)
            if src_hash == dst_hash:
                passed_checks += 1
                results.append((str(dst), src_hash, dst_hash, "PASS"))
            else:
                failed_checks += 1
                results.append((str(dst), src_hash, dst_hash, "MISMATCH"))
                print(f"[MISMATCH] {dst}\n  src: {src_hash}\n  dst: {dst_hash}")

        # Check E-player mirror roots for skills
        for mroot in mirror_roots:
            total_checks += 1
            dst = mroot / f"skills/{skill}/SKILL.md"
            if not dst.exists():
                print(f"[FAIL] Missing target: {dst}")
                failed_checks += 1
                continue
            dst_hash = sha256_file(dst)
            if src_hash == dst_hash:
                passed_checks += 1
                results.append((str(dst), src_hash, dst_hash, "PASS"))
            else:
                failed_checks += 1
                results.append((str(dst), src_hash, dst_hash, "MISMATCH"))
                print(f"[MISMATCH] {dst}\n  src: {src_hash}\n  dst: {dst_hash}")

    # 2. Application & Test Deliverables Parity
    for rel_path in deliverables:
        src = root / rel_path
        if not src.exists():
            print(f"[ERROR] Source file missing: {src}")
            failed_checks += 1
            continue
        src_hash = sha256_file(src)
        
        for mroot in mirror_roots:
            total_checks += 1
            dst = mroot / rel_path
            if not dst.exists():
                print(f"[FAIL] Missing target: {dst}")
                failed_checks += 1
                continue
            dst_hash = sha256_file(dst)
            if src_hash == dst_hash:
                passed_checks += 1
                results.append((str(dst), src_hash, dst_hash, "PASS"))
            else:
                failed_checks += 1
                results.append((str(dst), src_hash, dst_hash, "MISMATCH"))
                print(f"[MISMATCH] {dst}\n  src: {src_hash}\n  dst: {dst_hash}")

    print(f"\nAudit Summary:")
    print(f"Total Targets Audited: {total_checks}")
    print(f"Passed (Exact SHA256 Match): {passed_checks}")
    print(f"Failed (Missing or Mismatch): {failed_checks}")
    
    if failed_checks == 0 and total_checks > 0:
        print("\nFORENSIC VERDICT: PARITY CLEAN (100% Bit-for-bit identical across all mirrors)")
        sys.exit(0)
    else:
        print("\nFORENSIC VERDICT: INTEGRITY VIOLATION (Desynchronization detected)")
        sys.exit(1)

if __name__ == "__main__":
    main()
