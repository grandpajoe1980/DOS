from __future__ import annotations

import re
import os
import unittest
from pathlib import Path


ROOT = Path(os.environ.get("DOS_REPO_ROOT", Path(__file__).resolve().parents[1])).resolve()
SCANNED_SUFFIXES = {
    ".swift",
    ".py",
    ".yaml",
    ".yml",
    ".json",
    ".toml",
    ".plist",
    ".xcconfig",
    ".env",
}
EXCLUDED_PARTS = {".git", ".build", "build", "DerivedData", "__pycache__"}


def source_files() -> list[Path]:
    files: list[Path] = []
    for path in ROOT.rglob("*"):
        if not path.is_file() or (
            path.suffix not in SCANNED_SUFFIXES and not path.name.startswith(".env")
        ):
            continue
        if any(part in EXCLUDED_PARTS for part in path.parts):
            continue
        if path.stat().st_size > 2_000_000:
            continue
        files.append(path)
    return sorted(files)


class RepositoryHygieneTests(unittest.TestCase):
    def test_no_high_confidence_secrets_are_committed(self) -> None:
        patterns = {
            "private key": re.compile(r"-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----"),
            "AWS access key": re.compile(r"\bAKIA[0-9A-Z]{16}\b"),
            "GitHub token": re.compile(r"\b(?:ghp|gho|ghu|ghs|ghr)_[A-Za-z0-9]{30,}\b"),
            "Stripe live key": re.compile(r"\b(?:sk|rk)_live_[A-Za-z0-9]{16,}\b"),
            "assigned secret": re.compile(
                r"(?i)\b(?:api[_-]?key|client[_-]?secret|service[_-]?key|password|access[_-]?token|auth[_-]?token)\b\s*[:=]\s*[\"'][^\"'${<\s][^\"']{7,}[\"']"
            ),
        }
        findings: list[str] = []
        for path in source_files():
            text = path.read_text(encoding="utf-8", errors="replace")
            for label, pattern in patterns.items():
                for match in pattern.finditer(text):
                    line = text.count("\n", 0, match.start()) + 1
                    findings.append(f"{path.relative_to(ROOT)}:{line}: {label}")
        self.assertFalse(findings, "Potential committed secrets:\n" + "\n".join(findings))

    def test_production_swift_has_no_debug_markers(self) -> None:
        patterns = {
            "TODO/FIXME/HACK": re.compile(r"\b(?:TODO|FIXME|HACK)\b"),
            "console print": re.compile(r"\b(?:print|debugPrint)\s*\("),
            "fatalError": re.compile(r"\bfatalError\s*\("),
        }
        findings: list[str] = []
        source_root = ROOT / "DOS"
        if not source_root.exists():
            self.skipTest("DOS application source is not present in this worktree")
        for path in sorted(source_root.rglob("*.swift")):
            text = path.read_text(encoding="utf-8", errors="replace")
            for label, pattern in patterns.items():
                for match in pattern.finditer(text):
                    line = text.count("\n", 0, match.start()) + 1
                    findings.append(f"{path.relative_to(ROOT)}:{line}: {label}")
        self.assertFalse(findings, "Production debug markers:\n" + "\n".join(findings))

    def test_preview_service_is_not_reachable_from_production_composition(self) -> None:
        source_root = ROOT / "DOS"
        if not source_root.exists():
            self.skipTest("DOS application source is not present in this worktree")
        findings: list[str] = []
        for path in sorted(source_root.rglob("*.swift")):
            if path.name == "PreviewEventService.swift":
                continue
            text = path.read_text(encoding="utf-8", errors="replace")
            for match in re.finditer(r"\bPreviewEventService(?:\s*\(|\.)", text):
                line = text.count("\n", 0, match.start()) + 1
                findings.append(f"{path.relative_to(ROOT)}:{line}")
        self.assertFalse(
            findings,
            "PreviewEventService is reachable from production source:\n" + "\n".join(findings),
        )


if __name__ == "__main__":
    unittest.main()
