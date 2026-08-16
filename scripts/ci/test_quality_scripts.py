#!/usr/bin/env python3
"""Regression tests for repository quality-script failure detection."""

from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

import check_repository_policy
import check_secrets


class ActionPinParsingTests(unittest.TestCase):
    def test_valid_yaml_key_and_value_variants_are_inspected(self) -> None:
        sha = "a" * 40
        workflow = "\n".join(
            [
                f"uses: owner/plain@{sha}",
                f"- uses : owner/spaced@{sha}",
                f'- "uses": "owner/double@{sha}"',
                f"- 'uses': 'owner/single@{sha}'",
            ]
        )
        self.assertEqual(
            check_repository_policy.action_uses(workflow),
            [
                ("owner/plain", sha),
                ("owner/spaced", sha),
                ("owner/double", sha),
                ("owner/single", sha),
            ],
        )

    def test_unpinned_quoted_action_is_exposed(self) -> None:
        self.assertEqual(
            check_repository_policy.action_uses('- "uses": "owner/action@main"'),
            [("owner/action", "main")],
        )


class SecretSizeBoundaryTests(unittest.TestCase):
    def test_secret_after_two_megabytes_is_scanned(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            root = Path(temporary_directory)
            candidate = root / "large.txt"
            canary = "A" + "KIA1234567890ABCDEF"
            candidate.write_text(
                ("safe-padding\n" * 180_000) + canary + "\n",
                encoding="utf-8",
            )
            self.assertGreater(candidate.stat().st_size, 2 * 1024 * 1024)
            findings = check_secrets.scan_paths([candidate], root=root)
            self.assertTrue(
                any(finding.startswith("aws-access-key:") for finding in findings),
                findings,
            )


if __name__ == "__main__":
    unittest.main()
