#!/usr/bin/env python3
"""Scan for likely secret material. Prints rule IDs and file paths only — never matched values."""
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

SKIP_DIRS = {
    ".git",
    ".build",
    "DerivedData",
    "build",
    ".swiftpm",
    "xcuserdata",
}

# Rules: (rule_id, pattern). Patterns must not be printed with matches.
RULES: list[tuple[str, re.Pattern[str]]] = [
    ("github_pat", re.compile(r"ghp_[A-Za-z0-9]{20,}")),
    ("github_oauth", re.compile(r"gho_[A-Za-z0-9]{20,}")),
    ("github_user_pat", re.compile(r"github_pat_[A-Za-z0-9_]{20,}")),
    ("aws_access_key", re.compile(r"AKIA[0-9A-Z]{16}")),
    ("private_key_header", re.compile(r"-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----")),
    ("generic_api_key_assignment", re.compile(r"""(?i)(api[_-]?key|secret|password|token)\s*=\s*['\"][^'\"]{12,}['\"]""")),
    ("url_embedded_basic_auth", re.compile(r"https?://[^/\s:]+:[^/\s@]+@")),
]


def should_skip(path: Path) -> bool:
    parts = set(path.parts)
    if parts & SKIP_DIRS:
        return True
    if path.suffix in {".png", ".jpg", ".jpeg", ".gif", ".pdf", ".ico"}:
        return True
    return False


def main() -> int:
    findings: list[tuple[str, str]] = []
    for path in ROOT.rglob("*"):
        if not path.is_file() or should_skip(path):
            continue
        # Skip the plan doc intentionally? No — scan everything text-like.
        try:
            data = path.read_bytes()
        except OSError:
            continue
        if b"\0" in data[:1024]:
            continue
        try:
            text = data.decode("utf-8")
        except UnicodeDecodeError:
            continue

        rel = str(path.relative_to(ROOT))
        # Don't flag this scanner's own patterns as secrets
        if rel.endswith("Scripts/check_secrets.py"):
            continue

        for rule_id, pattern in RULES:
            if pattern.search(text):
                findings.append((rule_id, rel))

    if findings:
        print("check_secrets: FAILED")
        for rule_id, rel in sorted(set(findings)):
            print(f"  {rule_id}: {rel}")
        return 1

    print("check_secrets: OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
