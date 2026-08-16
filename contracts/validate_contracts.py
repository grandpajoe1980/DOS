#!/usr/bin/env python3
"""Validate the versioned Day of Service contracts and fixtures."""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path
from typing import Any, Iterable
from urllib.parse import urlsplit

import yaml
from jsonschema import Draft202012Validator, FormatChecker
from jsonschema.exceptions import FormatError
from openapi_spec_validator import validate as validate_openapi


ROOT = Path(__file__).resolve().parent
OPENAPI_PATH = ROOT / "openapi" / "v1.yaml"
MANIFEST_PATH = ROOT / "fixtures" / "manifest.json"
BASELINE_PATH = ROOT / "baseline" / "v1-contract-surface.json"
PROHIBITED_REQUEST_TENANT_FIELDS = {"organization_id", "tenant_id"}
STRICT_RESPONSE_ENUM_FIELDS = {
    "content_type",
    "event_feed_state",
    "kind",
    "method",
    "participant_type",
    "processing_state",
    "public_gallery_state",
    "role",
    "severity",
    "state",
    "team_mode",
}


def is_absolute_uri(value: str) -> bool:
    if any(character.isspace() or ord(character) < 0x20 for character in value):
        return False
    try:
        parsed = urlsplit(value)
    except ValueError:
        return False
    if re.fullmatch(r"[A-Za-z][A-Za-z0-9+.-]*", parsed.scheme) is None:
        return False
    if parsed.scheme.lower() in {"http", "https"}:
        return bool(parsed.netloc and parsed.hostname)
    return bool(parsed.path)


class ContractFormatChecker(FormatChecker):
    """Guarantee security-relevant URI validation without optional extras."""

    def check(self, instance: object, format: str) -> None:
        if format == "uri" and isinstance(instance, str) and not is_absolute_uri(instance):
            raise FormatError(f"{instance!r} is not an absolute URI", cause=None)
        super().check(instance, format)


CONTRACT_FORMAT_CHECKER = ContractFormatChecker()

REQUIRED_FIXTURES = {
    "announcement.invalid-all-registered-with-site.json",
    "announcement.invalid-assigned-site-missing-site.json",
    "announcement.invalid-assigned-site-with-role.json",
    "announcement.invalid-role-missing-role.json",
    "announcement.invalid-role-with-site.json",
    "error-authorization.valid.json",
    "error-capacity-race.valid.json",
    "error-media-race.valid.json",
    "legal-document.valid.json",
    "consent-evidence.valid.json",
    "media-processed-auto-feed.valid.json",
    "media-asset.invalid-unknown-enum.json",
    "media-feed.valid.json",
    "public-gallery.valid.json",
    "public-gallery.invalid-sensitive.json",
    "media-report-quarantine.valid.json",
    "media-report.invalid-email.json",
    "media-upload-authorization.invalid-uri.json",
    "public-occurrences.invalid-sensitive.json",
    "registration-create.invalid-tenant.json",
    "registration-create.invalid-display-name.json",
}


def load_json(path: Path) -> Any:
    with path.open(encoding="utf-8") as handle:
        return json.load(handle)


def load_spec() -> dict[str, Any]:
    with OPENAPI_PATH.open(encoding="utf-8") as handle:
        return yaml.safe_load(handle)


def resolve_pointer(document: Any, pointer: str) -> Any:
    if not pointer.startswith("#/"):
        raise ValueError(f"Only local JSON pointers are supported: {pointer}")
    current = document
    for token in pointer[2:].split("/"):
        token = token.replace("~1", "/").replace("~0", "~")
        current = current[token]
    return current


def dereference_local(value: Any, document: dict[str, Any]) -> Any:
    """Expand local component refs for acyclic contract fixture schemas."""
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


def component_name(ref: str) -> str | None:
    prefix = "#/components/schemas/"
    return ref[len(prefix) :] if ref.startswith(prefix) else None


def refs_in(value: Any) -> set[str]:
    refs: set[str] = set()
    if isinstance(value, dict):
        ref = value.get("$ref")
        if isinstance(ref, str):
            name = component_name(ref)
            if name:
                refs.add(name)
        for item in value.values():
            refs.update(refs_in(item))
    elif isinstance(value, list):
        for item in value:
            refs.update(refs_in(item))
    return refs


def reachable_components(
    roots: Iterable[str], schemas: dict[str, Any]
) -> set[str]:
    pending = list(roots)
    reached: set[str] = set()
    while pending:
        name = pending.pop()
        if name in reached:
            continue
        if name not in schemas:
            raise AssertionError(f"Unknown schema component reference: {name}")
        reached.add(name)
        pending.extend(refs_in(schemas[name]) - reached)
    return reached


def request_schema_roots(operation: dict[str, Any]) -> set[str]:
    roots: set[str] = set()
    for media_type in operation.get("requestBody", {}).get("content", {}).values():
        roots.update(refs_in(media_type.get("schema", {})))
    return roots


def response_schema_roots(operation: dict[str, Any]) -> set[str]:
    roots: set[str] = set()
    for response in operation.get("responses", {}).values():
        if "$ref" in response:
            continue
        schema = (
            response.get("content", {})
            .get("application/json", {})
            .get("schema", {})
        )
        roots.update(refs_in(schema))
    return roots


def nodes_in(value: Any):
    if isinstance(value, dict):
        yield value
        for item in value.values():
            yield from nodes_in(item)
    elif isinstance(value, list):
        for item in value:
            yield from nodes_in(item)


def resolved_enum(schema: Any, spec: dict[str, Any]) -> list[Any] | None:
    if not isinstance(schema, dict):
        return None
    if "$ref" in schema:
        schema = resolve_pointer(spec, schema["$ref"])
    enum = schema.get("enum")
    return list(enum) if isinstance(enum, list) else None


def schema_surface(schema: dict[str, Any], spec: dict[str, Any]) -> dict[str, Any]:
    properties = schema.get("properties", {})
    property_enums = {
        prop: values
        for prop, prop_schema in sorted(properties.items())
        if (values := resolved_enum(prop_schema, spec)) is not None
    }
    surface: dict[str, Any] = {
        "properties": sorted(properties),
        "required": sorted(schema.get("required", [])),
    }
    root_enum = resolved_enum(schema, spec)
    if root_enum is not None:
        surface["enum"] = root_enum
    if property_enums:
        surface["property_enums"] = property_enums
    return surface


def build_contract_surface(spec: dict[str, Any]) -> dict[str, Any]:
    schemas = spec["components"]["schemas"]
    operation_surface: dict[str, Any] = {}
    request_roots: set[str] = set()
    response_roots: set[str] = set()
    for path, method, operation in operations(spec):
        key = f"{method.upper()} {path}"
        operation_surface[key] = {"operation_id": operation["operationId"]}
        request_roots.update(request_schema_roots(operation))
        response_roots.update(response_schema_roots(operation))

    request_schemas = reachable_components(request_roots, schemas)
    response_schemas = reachable_components(response_roots, schemas)
    all_reached = request_schemas | response_schemas
    return {
        "surface_version": 1,
        "contract_version": spec["info"]["version"],
        "operations": dict(sorted(operation_surface.items())),
        "request_schemas": sorted(request_schemas),
        "response_schemas": sorted(response_schemas),
        "schemas": {
            name: schema_surface(schemas[name], spec)
            for name in sorted(all_reached)
        },
    }


def validate_request_tenant_exclusion(spec: dict[str, Any]) -> None:
    schemas = spec["components"]["schemas"]

    def inspect_schema_graph(
        schema: Any, operation_label: str, visited_components: set[str]
    ) -> None:
        if isinstance(schema, list):
            for item in schema:
                inspect_schema_graph(item, operation_label, visited_components)
            return
        if not isinstance(schema, dict):
            return

        properties = schema.get("properties", {})
        forbidden = PROHIBITED_REQUEST_TENANT_FIELDS & set(properties)
        if forbidden:
            raise AssertionError(
                f"Request schema graph for {operation_label} permits "
                f"server-derived tenant field(s): {', '.join(sorted(forbidden))}"
            )

        ref = schema.get("$ref")
        if isinstance(ref, str) and (name := component_name(ref)) is not None:
            if name not in schemas:
                raise AssertionError(f"Unknown schema component reference: {name}")
            if name not in visited_components:
                visited_components.add(name)
                inspect_schema_graph(schemas[name], operation_label, visited_components)

        for key, value in schema.items():
            if key != "$ref":
                inspect_schema_graph(value, operation_label, visited_components)

    for path, method, operation in operations(spec):
        label = f"{method.upper()} {path}"
        content = operation.get("requestBody", {}).get("content", {})
        for media_type in content.values():
            inspect_schema_graph(media_type.get("schema", {}), label, set())


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

    validate_request_tenant_exclusion(spec)
    schemas = spec["components"]["schemas"]

    if "display_name" in schemas["ParticipantInput"].get("properties", {}):
        raise AssertionError("ParticipantInput must resolve display_name server-side")

    for node in nodes_in(spec):
        if "x-known-values" in node:
            raise AssertionError("Response enums must use validating enum constraints")

    response_roots: set[str] = set()
    for _, _, operation in operations(spec):
        response_roots.update(response_schema_roots(operation))
    for name in sorted(reachable_components(response_roots, schemas)):
        for property_name, property_schema in schemas[name].get(
            "properties", {}
        ).items():
            if (
                property_name in STRICT_RESPONSE_ENUM_FIELDS
                and resolved_enum(property_schema, spec) is None
            ):
                raise AssertionError(
                    f"Response enum is not constrained: {name}.{property_name}"
                )

    for name in {
        "PublicSite",
        "PublicOccurrence",
        "PublicOccurrencePage",
        "MediaAsset",
        "MediaFeedItem",
        "MediaFeedPage",
        "PublicGalleryItem",
        "PublicGalleryPage",
        "MediaDeliveryAuthorization",
        "MediaReportReceipt",
    }:
        if schemas[name].get("additionalProperties") is not False:
            raise AssertionError(f"Public/media response schema is not closed: {name}")

    public_site_fields = set(schemas["PublicSite"]["properties"])
    if {"precise_operations_address", "object_key", "storage_key"} & public_site_fields:
        raise AssertionError("PublicSite exposes a sensitive location/storage field")
    gallery_fields = set(schemas["PublicGalleryItem"]["properties"])
    if {"object_key", "storage_key", "exif", "gps", "precise_location"} & gallery_fields:
        raise AssertionError("PublicGalleryItem exposes sensitive media metadata")
    if schemas["PublicOccurrence"]["properties"]["state"].get("enum") != ["published"]:
        raise AssertionError("Public occurrence responses must validate as published only")

    media_required = {
        "processing_state",
        "event_feed_state",
        "public_gallery_state",
    }
    if not media_required.issubset(schemas["MediaAsset"].get("required", [])):
        raise AssertionError("MediaAsset must separate processing/feed/gallery state")
    if "state" in schemas["MediaAsset"].get("properties", {}):
        raise AssertionError("MediaAsset must not collapse lifecycle into one state")

    report_operation = spec["paths"]["/v1/media/{media_id}/reports"]["post"]
    report_response = report_operation["responses"].get("200", {})
    report_ref = (
        report_response.get("content", {})
        .get("application/json", {})
        .get("schema", {})
        .get("$ref")
    )
    if report_ref != "#/components/schemas/MediaReportReceipt":
        raise AssertionError("Media reports must synchronously return quarantine evidence")

    safety_operation = spec["paths"]["/v1/safety-shares"]["post"]
    if safety_operation.get("x-authorization-policy") != {
        "authenticated_adult_profile_only": True,
        "dependent_or_minor_denied": True,
        "recipient_scope": "active_authorized_participant_in_same_occurrence",
    }:
        raise AssertionError("Safety Share creation authorization policy is incomplete")
    if safety_operation.get("x-expiry-policy") != {
        "future_relative_to": "server_received_at",
        "maximum_duration_seconds": 43200,
        "expiration_authority": "server",
    }:
        raise AssertionError("Safety Share creation expiry policy is incomplete")


def validate_baseline_compatibility(spec: dict[str, Any]) -> None:
    if not BASELINE_PATH.exists():
        raise AssertionError(f"Missing compatibility baseline: {BASELINE_PATH}")
    baseline = load_json(BASELINE_PATH)
    current = build_contract_surface(spec)

    for key, baseline_operation in baseline["operations"].items():
        current_operation = current["operations"].get(key)
        if current_operation is None:
            raise AssertionError(f"Breaking contract change removed operation: {key}")
        if current_operation["operation_id"] != baseline_operation["operation_id"]:
            raise AssertionError(f"Breaking operationId change: {key}")

    request_names = set(baseline["request_schemas"])
    response_names = set(baseline["response_schemas"])
    for name, old in baseline["schemas"].items():
        new = current["schemas"].get(name)
        if new is None:
            raise AssertionError(f"Breaking contract change removed schema: {name}")
        old_properties = set(old.get("properties", []))
        new_properties = set(new.get("properties", []))
        if not old_properties.issubset(new_properties):
            removed = sorted(old_properties - new_properties)
            raise AssertionError(f"Breaking property removal from {name}: {removed}")

        old_required = set(old.get("required", []))
        new_required = set(new.get("required", []))
        if name in request_names and not new_required.issubset(old_required):
            added = sorted(new_required - old_required)
            raise AssertionError(f"Breaking required request fields added to {name}: {added}")
        if name in response_names and not old_required.issubset(new_required):
            removed = sorted(old_required - new_required)
            raise AssertionError(f"Breaking response guarantees removed from {name}: {removed}")

        if "enum" in old and not set(old["enum"]).issubset(new.get("enum", [])):
            raise AssertionError(f"Breaking enum value removal from {name}")
        for prop, old_values in old.get("property_enums", {}).items():
            new_values = new.get("property_enums", {}).get(prop, [])
            if not set(old_values).issubset(new_values):
                raise AssertionError(f"Breaking enum value removal from {name}.{prop}")


def validator_for_manifest_entry(
    entry: dict[str, Any], spec: dict[str, Any]
) -> Draft202012Validator:
    schema_ref = entry["schema"]
    if "openapi_pointer" in schema_ref:
        schema = resolve_pointer(spec, schema_ref["openapi_pointer"])
        schema = dereference_local(schema, spec)
    else:
        schema_path = ROOT / schema_ref["file"]
        schema = load_json(schema_path)
    Draft202012Validator.check_schema(schema)
    return Draft202012Validator(schema, format_checker=CONTRACT_FORMAT_CHECKER)


def validate_fixtures(spec: dict[str, Any]) -> None:
    manifest = load_json(MANIFEST_PATH)
    fixture_paths = [entry["path"] for entry in manifest["fixtures"]]
    if len(fixture_paths) != len(set(fixture_paths)):
        raise AssertionError("Fixture manifest contains duplicate paths")
    missing = REQUIRED_FIXTURES - set(fixture_paths)
    if missing:
        raise AssertionError(f"Required regression fixtures missing: {sorted(missing)}")

    for entry in manifest["fixtures"]:
        fixture_path = ROOT / "fixtures" / entry["path"]
        if not fixture_path.is_file():
            raise AssertionError(f"Fixture file does not exist: {fixture_path}")
        instance = load_json(fixture_path)
        validator = validator_for_manifest_entry(entry, spec)
        errors = sorted(
            validator.iter_errors(instance), key=lambda error: list(error.path)
        )
        expected_valid = entry["valid"]
        if expected_valid and errors:
            details = "; ".join(error.message for error in errors)
            raise AssertionError(f"Expected valid fixture {fixture_path}: {details}")
        if not expected_valid and not errors:
            raise AssertionError(f"Expected invalid fixture {fixture_path}")


def main() -> None:
    spec = load_spec()
    if sys.argv[1:] == ["--print-baseline"]:
        print(json.dumps(build_contract_surface(spec), indent=2, sort_keys=True))
        return
    if sys.argv[1:]:
        raise SystemExit("Usage: validate_contracts.py [--print-baseline]")

    validate_openapi(spec)
    validate_semantics(spec)
    validate_baseline_compatibility(spec)
    validate_fixtures(spec)
    operation_count = sum(1 for _ in operations(spec))
    fixture_count = len(load_json(MANIFEST_PATH)["fixtures"])
    print(
        "Validated OpenAPI v1, compatibility baseline, request tenant "
        f"exclusion, formats, and {fixture_count} fixtures across "
        f"{operation_count} operations."
    )


if __name__ == "__main__":
    main()
