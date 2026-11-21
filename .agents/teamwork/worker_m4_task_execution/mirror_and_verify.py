import hashlib
import os
import shutil
from pathlib import Path

def get_sha256(filepath: str) -> str:
    h = hashlib.sha256()
    with open(filepath, "rb") as f:
        while chunk := f.read(65536):
            h.update(chunk)
    return h.hexdigest()

def copy_and_verify(src: str, dst: str):
    dst_path = Path(dst)
    dst_path.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst)
    src_hash = get_sha256(src)
    dst_hash = get_sha256(dst)
    if src_hash != dst_hash:
        raise ValueError(f"Hash mismatch copying {src} -> {dst}: {src_hash} != {dst_hash}")
    return src_hash

def main():
    root = Path("D:/E-player")
    
    # 1. Skills
    skills = [
        "eplayer-flutter-video-arch",
        "eplayer-mpv-vlc-parity",
        "eplayer-native-neural-ffi",
        "eplayer-verification-guardrail",
    ]

    skill_destinations = [
        "D:/Agents workespaces/skills",
        "D:/Agents workespaces/Core Coding & Architecture Sector/skills",
        "D:/Agents workespaces/QA, Testing & Verification Sector/skills",
        "D:/overload/skills",
    ]

    print("=== Mirroring Hermes Skills ===")
    verified_skills = []
    for skill in skills:
        src = root / f"skills/{skill}/SKILL.md"
        src_hash = get_sha256(str(src))
        print(f"Skill: {skill} [SHA256: {src_hash}]")
        for dst_dir in skill_destinations:
            dst = Path(dst_dir) / f"{skill}/SKILL.md"
            copy_and_verify(str(src), str(dst))
            print(f"  -> Verified mirror: {dst}")
        verified_skills.append((skill, src_hash))

    # 2. Application & Test Deliverables
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

    mirror_roots = [
        "D:/Agents workespaces/E-player",
        "D:/Agents workespaces/Core Coding & Architecture Sector/E-player",
        "D:/Agents workespaces/QA, Testing & Verification Sector/E-player",
        "D:/overload/E-player",
    ]

    print("\n=== Mirroring Application Deliverables ===")
    verified_files = []
    for rel_path in deliverables:
        src = root / rel_path
        src_hash = get_sha256(str(src))
        print(f"File: {rel_path} [SHA256: {src_hash}]")
        for mroot in mirror_roots:
            dst = Path(mroot) / rel_path
            copy_and_verify(str(src), str(dst))
            print(f"  -> Verified mirror: {dst}")
        verified_files.append((rel_path, src_hash))

    # Also mirror skills to the E-player mirror roots
    for skill in skills:
        rel_path = f"skills/{skill}/SKILL.md"
        src = root / rel_path
        for mroot in mirror_roots:
            dst = Path(mroot) / rel_path
            copy_and_verify(str(src), str(dst))

    print("\n=== Comprehensive Cryptographic SHA256 Audit ===")
    total_checks = 0
    # Audit all skill copies
    for skill, expected_hash in verified_skills:
        for dst_dir in skill_destinations:
            dst = Path(dst_dir) / f"{skill}/SKILL.md"
            h = get_sha256(str(dst))
            assert h == expected_hash, f"PARITY FAILURE: {dst}"
            total_checks += 1
        for mroot in mirror_roots:
            dst = Path(mroot) / f"skills/{skill}/SKILL.md"
            h = get_sha256(str(dst))
            assert h == expected_hash, f"PARITY FAILURE: {dst}"
            total_checks += 1

    # Audit all deliverable copies
    for rel_path, expected_hash in verified_files:
        for mroot in mirror_roots:
            dst = Path(mroot) / rel_path
            h = get_sha256(str(dst))
            assert h == expected_hash, f"PARITY FAILURE: {dst}"
            total_checks += 1

    print(f"SUCCESS: 100% Parity Verified across {total_checks} mirrored files with zero mismatches.")

if __name__ == "__main__":
    main()
