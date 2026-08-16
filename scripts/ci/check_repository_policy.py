#!/usr/bin/env python3
"""Enforce lightweight repository and workflow safety policy."""

from __future__ import annotations

import re
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MAX_TRACKED_BYTES = 5 * 1024 * 1024
PINNED_ACTION = re.compile(r"^[0-9a-f]{40}$")
USES = re.compile(r"^\s*-?\s*uses:\s*([^@\s]+)@([^\s#]+)", re.MULTILINE)

REQUIRED = {
    ".github/CODEOWNERS",
    ".github/PULL_REQUEST_TEMPLATE.md",
    ".github/REVIEW_MAP.md",
    ".github/workflows/ci.yml",
    "Configuration/Base.xcconfig",
    "Configuration/Debug.xcconfig",
    "Configuration/Staging.xcconfig",
    "Configuration/Production.xcconfig",
    "DOS.xcodeproj/project.pbxproj",
    "DOS.xcodeproj/xcshareddata/xcschemes/DOS.xcscheme",
}

FORBIDDEN_PARTS = {".build", "DerivedData", "xcuserdata"}
FORBIDDEN_NAMES = {".DS_Store"}


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


def main() -> int:
    errors: list[str] = []
    for required in sorted(REQUIRED):
        if not (ROOT / required).is_file():
            errors.append(f"missing required foundation file: {required}")

    for path in tracked_files():
        if not path.exists():
            continue
        relative = path.relative_to(ROOT)
        if path.name in FORBIDDEN_NAMES or FORBIDDEN_PARTS.intersection(relative.parts):
            errors.append(f"generated/user-specific file is tracked: {relative}")
        if path.stat().st_size > MAX_TRACKED_BYTES:
            errors.append(f"tracked file exceeds 5 MiB: {relative}")

    for workflow in sorted((ROOT / ".github" / "workflows").glob("*.y*ml")):
        text = workflow.read_text(encoding="utf-8")
        if re.search(r"^\s*continue-on-error:\s*true\s*$", text, re.MULTILINE):
            errors.append(
                f"workflow may not suppress failed gates with continue-on-error: "
                f"{workflow.relative_to(ROOT)}"
            )
        for action, ref in USES.findall(text):
            if action.startswith("./"):
                continue
            if not PINNED_ACTION.fullmatch(ref):
                errors.append(
                    f"GitHub Action must be pinned to a 40-character commit: {action}@{ref} "
                    f"in {workflow.relative_to(ROOT)}"
                )

    production = ROOT / "Configuration" / "Production.xcconfig"
    if production.is_file():
        text = production.read_text(encoding="utf-8")
        match = re.search(r"^DOS_API_HOST\s*=\s*(\S+)\s*$", text, re.MULTILINE)
        if not match or not match.group(1).endswith(".invalid"):
            errors.append(
                "Production API host must remain fail-closed under .invalid until provisioning is approved"
            )

    if errors:
        print("Repository policy failed:", file=sys.stderr)
        for error in errors:
            print(f"- {error}", file=sys.stderr)
        return 1
    print("Repository policy passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
