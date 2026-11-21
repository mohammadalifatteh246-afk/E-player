import os
import hashlib
import sys

def sha256_file(filepath):
    h = hashlib.sha256()
    with open(filepath, 'rb') as f:
        while chunk := f.read(65536):
            h.update(chunk)
    return h.hexdigest()

def main():
    root = r"D:\E-player"

    skills = [
        "eplayer-flutter-video-arch",
        "eplayer-mpv-vlc-parity",
        "eplayer-native-neural-ffi",
        "eplayer-verification-guardrail",
    ]

    skill_destinations = [
        r"D:\Agents workespaces\skills",
        r"D:\Agents workespaces\Core Coding & Architecture Sector\skills",
        r"D:\Agents workespaces\QA, Testing & Verification Sector\skills",
        r"D:\overload\skills",
    ]

    deliverables = [
        r"app\lib\features\subtitles\models\subtitle_result.dart",
        r"app\lib\features\subtitles\data\opensubtitles_service.dart",
        r"app\lib\features\network_stream\models\network_share.dart",
        r"app\lib\features\network_stream\data\network_media_service.dart",
        r"app\lib\features\cast\models\cast_device.dart",
        r"app\lib\features\cast\data\cast_discovery_service.dart",
        r"app\test\e2e\phase1_e2e_test.dart",
        r"app\test\unit\phase3_subtitles_network_cast_test.dart",
        r"app\test\e2e\phase3_e2e_test.dart",
        r"docs\vlc_gap_analysis.md",
    ]

    mirror_roots = [
        r"D:\Agents workespaces\E-player",
        r"D:\Agents workespaces\Core Coding & Architecture Sector\E-player",
        r"D:\Agents workespaces\QA, Testing & Verification Sector\E-player",
        r"D:\overload\E-player",
    ]

    print("=== INDEPENDENT CRYPTOGRAPHIC SHA256 PARITY AUDIT ===")

    # 1. Audit Hermes Runtime Skills
    print("\n[Auditing Hermes Runtime Skills]")
    hermes_skills_dir = r"C:\Users\Admin\AppData\Local\hermes\skills"
    for skill in skills:
        src = os.path.join(root, "skills", skill, "SKILL.md")
        tgt = os.path.join(hermes_skills_dir, skill, "SKILL.md")
        src_h = sha256_file(src)
        tgt_h = sha256_file(tgt)
        assert src_h == tgt_h, f"Hermes mismatch for {skill}: {src_h} != {tgt_h}"
        print(f"  [HERMES OK] {skill} -> {src_h}")

    # 2. Audit Standalone Skills Mirrors (16 files)
    print("\n[Auditing Standalone Skills Destinations (16 files)]")
    checks = 0
    for skill in skills:
        src = os.path.join(root, "skills", skill, "SKILL.md")
        src_h = sha256_file(src)
        for dst_dir in skill_destinations:
            tgt = os.path.join(dst_dir, skill, "SKILL.md")
            assert os.path.exists(tgt), f"Missing skill file: {tgt}"
            tgt_h = sha256_file(tgt)
            assert src_h == tgt_h, f"Hash mismatch: {tgt}"
            checks += 1
            print(f"  [OK {checks}/16] {tgt} == {src_h}")

    # 3. Audit E-Player Root Skills Mirrors (16 files)
    print("\n[Auditing E-player Skills in Mirror Roots (16 files)]")
    for skill in skills:
        src = os.path.join(root, "skills", skill, "SKILL.md")
        src_h = sha256_file(src)
        for mroot in mirror_roots:
            tgt = os.path.join(mroot, "skills", skill, "SKILL.md")
            assert os.path.exists(tgt), f"Missing root skill file: {tgt}"
            tgt_h = sha256_file(tgt)
            assert src_h == tgt_h, f"Hash mismatch: {tgt}"
            checks += 1
            print(f"  [OK {checks}/32] {tgt} == {src_h}")

    # 4. Audit Deliverables Mirrors (40 files)
    print("\n[Auditing Application Deliverables in Mirror Roots (40 files)]")
    for rel_path in deliverables:
        src = os.path.join(root, rel_path)
        src_h = sha256_file(src)
        for mroot in mirror_roots:
            tgt = os.path.join(mroot, rel_path)
            assert os.path.exists(tgt), f"Missing deliverable: {tgt}"
            tgt_h = sha256_file(tgt)
            assert src_h == tgt_h, f"Hash mismatch: {tgt}"
            checks += 1
            print(f"  [OK {checks}/72] {tgt} == {src_h}")

    print("\n" + "=" * 60)
    print(f"INDEPENDENT PARITY VERIFICATION COMPLETE: 72/72 FILES (100% BIT-FOR-BIT SHA256 PARITY)")
    print("=" * 60)

if __name__ == '__main__':
    main()
