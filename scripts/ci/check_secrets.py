#!/usr/bin/env python3
"""Fail on common committed credential formats without printing secret values."""

from __future__ import annotations

import re
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SELF = Path(__file__).resolve()
MAX_TEXT_BYTES = 5 * 1024 * 1024

FORBIDDEN_NAMES = {
    ".env",
    "google-service-info.plist",
    "authkey.p8",
}
FORBIDDEN_SUFFIXES = {
    ".jks",
    ".keystore",
    ".mobileprovision",
    ".p12",
    ".p8",
    ".pem",
}

# Patterns are deliberately assembled so this scanner does not match its own
# source. Findings report only rule, path, and line—never the matched value.
PATTERNS = {
    "private-key": re.compile("-----BEGIN " + "(?:RSA |EC |OPENSSH )?PRIVATE KEY-----"),
    "aws-access-key": re.compile("A" + "KIA[0-9A-Z]{16}"),
    "github-token": re.compile("g" + r"h[pousr]_[A-Za-z0-9]{30,}"),
    "google-api-key": re.compile("A" + r"Iza[0-9A-Za-z_-]{35}"),
    "slack-token": re.compile("x" + r"ox[baprs]-[0-9A-Za-z-]{20,}"),
    "jwt": re.compile(r"eyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}"),
    "literal-secret-assignment": re.compile(
        r"(?i)(?:api[_-]?key|client[_-]?secret|password|service[_-]?role[_-]?key|"
        r"access[_-]?token)\s*[:=]\s*[\"'][^\"'${(<\s][^\"']{7,}[\"']"
    ),
}


def tracked_files() -> list[Path]:
    try:
        result = subprocess.run(
            ["git", "ls-files", "-z"],
            cwd=ROOT,
            check=True,
            capture_output=True,
        )
        return [ROOT / item.decode() for item in result.stdout.split(b"\0") if item]
    except (FileNotFoundError, subprocess.CalledProcessError):
        return [path for path in ROOT.rglob("*") if path.is_file() and ".git" not in path.parts]


def scan_paths(paths: list[Path], root: Path = ROOT) -> list[str]:
    findings: list[str] = []
    for path in paths:
        if path.resolve() == SELF or not path.exists():
            continue
        lower_name = path.name.lower()
        if lower_name in FORBIDDEN_NAMES or path.suffix.lower() in FORBIDDEN_SUFFIXES:
            findings.append(f"credential-file: {path.relative_to(root)}")
            continue
        if path.stat().st_size > MAX_TEXT_BYTES:
            continue
        try:
            text = path.read_text(encoding="utf-8")
        except (UnicodeDecodeError, OSError):
            continue
        for line_number, line in enumerate(text.splitlines(), start=1):
            for rule, pattern in PATTERNS.items():
                if pattern.search(line):
                    findings.append(f"{rule}: {path.relative_to(root)}:{line_number}")
    return findings


def main() -> int:
    findings = scan_paths(tracked_files())

    if findings:
        print("Potential credentials detected (values redacted):", file=sys.stderr)
        for finding in findings:
            print(f"- {finding}", file=sys.stderr)
        return 1
    print("Secret scan passed; no supported credential patterns were found.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
