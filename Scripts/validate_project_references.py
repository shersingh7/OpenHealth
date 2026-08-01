#!/usr/bin/env python3
"""Validate that production Swift/resources are referenced exactly once in the Xcode project."""
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PBX = ROOT / "OpenHealth.xcodeproj" / "project.pbxproj"

PRODUCTION_GLOBS = [
    "App/**/*.swift",
    "Core/**/*.swift",
    "Infrastructure/**/*.swift",
    "DesignSystem/**/*.swift",
    "Features/**/*.swift",
]

REQUIRED_RESOURCES = [
    "Assets.xcassets",
    "PrivacyInfo.xcprivacy",
]


def main() -> int:
    if not PBX.exists():
        print(f"ERROR: missing {PBX}")
        return 1

    text = PBX.read_text(encoding="utf-8")
    errors: list[str] = []

    # Collect production swift files
    files: list[Path] = []
    for pattern in PRODUCTION_GLOBS:
        files.extend(sorted(ROOT.glob(pattern)))
    files = [f for f in files if f.is_file()]

    if not files:
        errors.append("No production Swift files found")

    for f in files:
        name = f.name
        # File reference
        ref_count = len(re.findall(rf"path = {re.escape(name)};", text))
        if ref_count < 1:
            errors.append(f"Missing file reference: {f.relative_to(ROOT)}")
        # Sources membership: count only inside PBXSourcesBuildPhase (not PBXBuildFile decls)
        sources_section = re.search(
            r"/\* Begin PBXSourcesBuildPhase section \*/(.*?)/\* End PBXSourcesBuildPhase section \*/",
            text,
            re.S,
        )
        section_text = sources_section.group(1) if sources_section else ""
        src_count = section_text.count(f"/* {name} in Sources */")
        if src_count != 1:
            errors.append(
                f"Expected exactly 1 Sources membership for {f.relative_to(ROOT)}, found {src_count}"
            )

    # Entitlements must NOT be in Copy Bundle Resources
    if "OpenHealth.entitlements in Resources" in text:
        errors.append("OpenHealth.entitlements must not be in Copy Bundle Resources")

    # Entitlements should be code-sign setting
    if "CODE_SIGN_ENTITLEMENTS = Resources/OpenHealth.entitlements" not in text:
        errors.append("CODE_SIGN_ENTITLEMENTS must point to Resources/OpenHealth.entitlements")

    # No hard-coded development team
    if re.search(r"DEVELOPMENT_TEAM\s*=\s*[A-Z0-9]+;", text):
        errors.append("DEVELOPMENT_TEAM must not be hard-coded in shared project settings")

    for res in REQUIRED_RESOURCES:
        if f"/* {res} in Resources */" not in text and f"path = {res};" not in text:
            errors.append(f"Missing resource reference: {res}")

    # No second @main in project sources (widget)
    mains = []
    for f in files:
        content = f.read_text(encoding="utf-8", errors="replace")
        if re.search(r"@main\b", content):
            mains.append(str(f.relative_to(ROOT)))
    if len(mains) != 1:
        errors.append(f"Expected exactly one @main in production sources, found {mains}")

    if "TARGETED_DEVICE_FAMILY = \"1,2\"" not in text and "TARGETED_DEVICE_FAMILY = 1,2" not in text:
        # allow either quoting style
        if "TARGETED_DEVICE_FAMILY" not in text:
            errors.append("TARGETED_DEVICE_FAMILY missing (expect iPhone/iPad)")

    if errors:
        print("validate_project_references: FAILED")
        for e in errors:
            print(f"  - {e}")
        return 1

    print(f"validate_project_references: OK ({len(files)} Swift sources)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
