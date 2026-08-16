#!/usr/bin/env python3
"""Validate the versioned Day of Service contracts and fixtures."""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any

import yaml
from jsonschema import Draft202012Validator
from openapi_spec_validator import validate as validate_openapi


ROOT = Path(__file__).resolve().parent
OPENAPI_PATH = ROOT / "openapi" / "v1.yaml"
MANIFEST_PATH = ROOT / "fixtures" / "manifest.json"


def load_json(path: Path) -> Any:
    with path.open(encoding="utf-8") as handle:
        return json.load(handle)


def resolve_pointer(document: Any, pointer: str) -> Any:
    if not pointer.startswith("#/"):
        raise ValueError(f"Only local JSON pointers are supported: {pointer}")
    current = document
    for token in pointer[2:].split("/"):
        token = token.replace("~1", "/").replace("~0", "~")
        current = current[token]
    return current


def dereference_local(value: Any, document: dict[str, Any]) -> Any:
    """Expand local component refs for fixture validation.

    Contract fixture schemas are intentionally acyclic. OpenAPI validation runs
    first and remains responsible for general reference correctness.
    """
    if isinstance(value, dict):
        if set(value) == {"$ref"} and value["$ref"].startswith("#/"):
            return dereference_local(resolve_pointer(document, value["$ref"]), document)
        return {key: dereference_local(item, document) for key, item in value.items()}
    if isinstance(value, list):
        return [dereference_local(item, document) for item in value]
    return value


def operations(spec: dict[str, Any]):
    methods = {"get", "post", "put", "patch", "delete", "options", "head"}
    for path, path_item in spec["paths"].items():
        for method, operation in path_item.items():
            if method.lower() in methods:
                yield path, method.lower(), operation


def validate_semantics(spec: dict[str, Any]) -> None:
    operation_ids: set[str] = set()
    idempotency_ref = "#/components/parameters/IdempotencyKey"
    for path, method, operation in operations(spec):
        operation_id = operation.get("operationId")
        if not operation_id:
            raise AssertionError(f"Missing operationId: {method.upper()} {path}")
        if operation_id in operation_ids:
            raise AssertionError(f"Duplicate operationId: {operation_id}")
        operation_ids.add(operation_id)

        if method in {"post", "put", "patch", "delete"}:
            refs = {
                parameter.get("$ref")
                for parameter in operation.get("parameters", [])
                if isinstance(parameter, dict)
            }
            if idempotency_ref not in refs:
                raise AssertionError(
                    f"Mutation lacks Idempotency-Key: {method.upper()} {path}"
                )

    create_components = [
        "RegistrationCreate",
        "ConsentCreate",
        "GuardianConsentCreate",
        "AttendanceEventCreate",
        "AnnouncementCreate",
        "SafetyShareCreate",
        "MediaUploadRequest",
        "MediaCompletion",
        "MediaModerationActionCreate",
        "MediaReportCreate",
        "ExportRequest",
    ]
    schemas = spec["components"]["schemas"]
    for component in create_components:
        properties = schemas[component].get("properties", {})
        if "organization_id" in properties:
            raise AssertionError(
                f"{component} must derive organization_id server-side"
            )


def validator_for_manifest_entry(
    entry: dict[str, Any], spec: dict[str, Any]
) -> Draft202012Validator:
    schema_ref = entry["schema"]
    if "openapi_pointer" in schema_ref:
        schema = resolve_pointer(spec, schema_ref["openapi_pointer"])
        return Draft202012Validator(dereference_local(schema, spec))

    schema_path = ROOT / schema_ref["file"]
    schema = load_json(schema_path)
    Draft202012Validator.check_schema(schema)
    return Draft202012Validator(schema)


def validate_fixtures(spec: dict[str, Any]) -> None:
    manifest = load_json(MANIFEST_PATH)
    for entry in manifest["fixtures"]:
        fixture_path = ROOT / "fixtures" / entry["path"]
        instance = load_json(fixture_path)
        validator = validator_for_manifest_entry(entry, spec)
        errors = sorted(validator.iter_errors(instance), key=lambda error: list(error.path))
        expected_valid = entry["valid"]
        if expected_valid and errors:
            details = "; ".join(error.message for error in errors)
            raise AssertionError(f"Expected valid fixture {fixture_path}: {details}")
        if not expected_valid and not errors:
            raise AssertionError(f"Expected invalid fixture {fixture_path}")


def main() -> None:
    with OPENAPI_PATH.open(encoding="utf-8") as handle:
        spec = yaml.safe_load(handle)
    validate_openapi(spec)
    validate_semantics(spec)
    validate_fixtures(spec)
    print("Validated OpenAPI v1, realtime schema, and all contract fixtures.")


if __name__ == "__main__":
    main()
