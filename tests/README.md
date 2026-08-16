# Independent quality harness

This directory contains adversarial contract and repository-hygiene tests owned by the quality team. The tests describe the intended v1 boundary; they are independent of `contracts/validate_contracts.py` and are expected to fail when a contract change violates that boundary.

Run from the repository root with Python 3.10 or newer:

```bash
python3 -m venv /tmp/dos-contract-test-venv
/tmp/dos-contract-test-venv/bin/python -m pip install --disable-pip-version-check -r contracts/requirements.txt
PYTHONDONTWRITEBYTECODE=1 /tmp/dos-contract-test-venv/bin/python -m unittest discover -s tests -p 'test_*.py' -v
```

The temporary virtual environment avoids writing dependencies into the repository. `PYTHONDONTWRITEBYTECODE=1` prevents test-generated `__pycache__` artifacts.

The harness covers:

- closed, published-only public DTOs;
- strict UUID/date/email/URI fixture validation;
- request tenant over-post denial;
- participant identity one-of rules;
- legal-document and guardian evidence contracts;
- Safety Sharing expiry and recipient scope;
- conditional announcement audiences;
- idempotency and capacity-conflict responses;
- distinct event-member media feed and anonymous public gallery behavior;
- immediate report quarantine and minor-upload denial;
- realtime sensitive-field denial;
- high-confidence secret, debug-marker, and preview-service reachability scans.

A failing test is a defect until the contract/implementation is corrected or the Architect records a superseding boundary decision and the quality owner updates the assertion.
