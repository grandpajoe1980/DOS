from __future__ import annotations

import copy
import importlib.util
import json
import re
import unittest
from pathlib import Path
from typing import Any

import yaml
from jsonschema import Draft202012Validator, FormatChecker


ROOT = Path(__file__).resolve().parents[1]
SPEC_PATH = ROOT / "contracts" / "openapi" / "v1.yaml"
REALTIME_SCHEMA_PATH = ROOT / "contracts" / "schemas" / "realtime-event.schema.json"
FIXTURES = ROOT / "tests" / "fixtures"
MUTATING_METHODS = {"post", "put", "patch", "delete"}


def load_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def resolve_pointer(document: Any, pointer: str) -> Any:
    if not pointer.startswith("#/"):
        raise ValueError(f"Only local pointers are supported: {pointer}")
    current = document
    for token in pointer[2:].split("/"):
        current = current[token.replace("~1", "/").replace("~0", "~")]
    return current


def dereference_local(value: Any, document: dict[str, Any]) -> Any:
    if isinstance(value, dict):
        if "$ref" in value and value["$ref"].startswith("#/"):
            resolved = dereference_local(resolve_pointer(document, value["$ref"]), document)
            siblings = {key: item for key, item in value.items() if key != "$ref"}
            if not siblings:
                return resolved
            if not isinstance(resolved, dict):
                raise TypeError("Cannot merge $ref siblings into a non-object schema")
            return {**resolved, **dereference_local(siblings, document)}
        return {key: dereference_local(item, document) for key, item in value.items()}
    if isinstance(value, list):
        return [dereference_local(item, document) for item in value]
    return value


def known_values(schema: dict[str, Any]) -> set[str]:
    values = schema.get("enum") or schema.get("x-known-values") or []
    return {str(value) for value in values}


def component_references(value: Any) -> set[str]:
    references: set[str] = set()
    if isinstance(value, dict):
        ref = value.get("$ref")
        prefix = "#/components/schemas/"
        if isinstance(ref, str) and ref.startswith(prefix):
            references.add(ref.removeprefix(prefix))
        for item in value.values():
            references.update(component_references(item))
    elif isinstance(value, list):
        for item in value:
            references.update(component_references(item))
    return references


def schema_nodes(value: Any):
    if isinstance(value, dict):
        yield value
        for item in value.values():
            yield from schema_nodes(item)
    elif isinstance(value, list):
        for item in value:
            yield from schema_nodes(item)


class ContractBoundaryTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.spec = yaml.safe_load(SPEC_PATH.read_text(encoding="utf-8"))
        cls.schemas = cls.spec["components"]["schemas"]
        cls.format_checker = FormatChecker()

    def validator(self, schema_name: str) -> Draft202012Validator:
        schema = dereference_local(self.schemas[schema_name], self.spec)
        return Draft202012Validator(schema, format_checker=self.format_checker)

    def assert_valid(self, schema_name: str, instance: Any) -> None:
        errors = list(self.validator(schema_name).iter_errors(instance))
        self.assertFalse(errors, "; ".join(error.message for error in errors))

    def assert_invalid(self, schema_name: str, instance: Any, message: str) -> None:
        errors = list(self.validator(schema_name).iter_errors(instance))
        self.assertTrue(errors, message)

    def operation(self, operation_id: str) -> tuple[str, str, dict[str, Any]]:
        for path, path_item in self.spec["paths"].items():
            for method, candidate in path_item.items():
                if isinstance(candidate, dict) and candidate.get("operationId") == operation_id:
                    return path, method.lower(), candidate
        self.fail(f"Missing operationId {operation_id}")

    def test_public_occurrence_fixture_is_valid(self) -> None:
        self.assert_valid(
            "PublicOccurrencePage",
            load_json(FIXTURES / "public-occurrence.valid.json"),
        )

    def test_public_dto_rejects_sensitive_or_internal_fields(self) -> None:
        base = load_json(FIXTURES / "public-occurrence.valid.json")
        forbidden_occurrence_fields = {
            "precise_operations_address": "123 Private Way",
            "organizer_email": "organizer@example.org",
            "minor_roster": ["dependent-1"],
            "storage_key": "tenant/private/original.jpg",
            "private_media_url": "https://private.example/original.jpg",
        }
        forbidden_site_fields = {
            "precise_operations_address": "123 Private Way",
            "emergency_contact": "+1-555-0100",
            "assigned_participant_ids": ["40000000-0000-4000-8000-000000000001"],
            "internal_arrival_notes": "Use staff-only rear entrance.",
        }
        for field, value in forbidden_occurrence_fields.items():
            with self.subTest(scope="occurrence", field=field):
                instance = copy.deepcopy(base)
                instance["data"][0][field] = value
                self.assert_invalid(
                    "PublicOccurrencePage",
                    instance,
                    f"Public occurrence accepted forbidden field {field}",
                )
        for field, value in forbidden_site_fields.items():
            with self.subTest(scope="site", field=field):
                instance = copy.deepcopy(base)
                instance["data"][0]["sites"][0][field] = value
                self.assert_invalid(
                    "PublicOccurrencePage",
                    instance,
                    f"Public site accepted forbidden field {field}",
                )

    def test_public_occurrence_is_published_only(self) -> None:
        instance = load_json(FIXTURES / "public-occurrence.valid.json")
        instance["data"][0]["state"] = "draft"
        self.assert_invalid(
            "PublicOccurrencePage",
            instance,
            "The public response contract accepted a draft occurrence",
        )

    def test_project_fixture_validator_enforces_formats(self) -> None:
        module_path = ROOT / "contracts" / "validate_contracts.py"
        module_spec = importlib.util.spec_from_file_location("dos_contract_validator", module_path)
        if module_spec is None or module_spec.loader is None:
            self.fail("Could not load contracts/validate_contracts.py")
        module = importlib.util.module_from_spec(module_spec)
        module_spec.loader.exec_module(module)

        checks = [
            ("#/components/schemas/UUID", "not-a-uuid", "uuid"),
            ("#/components/schemas/Timestamp", "not-a-date", "date-time"),
            (
                "#/components/schemas/MediaReportCreate",
                {"reason_code": "privacy", "contact_email": "not-an-email"},
                "email",
            ),
            (
                "#/components/schemas/MediaUploadAuthorization",
                {
                    "media_id": "10000000-0000-4000-8000-000000000001",
                    "upload_url": "not a uri",
                    "required_headers": {},
                    "expires_at": "2027-01-16T15:00:00Z",
                },
                "uri",
            ),
        ]
        for pointer, instance, format_name in checks:
            with self.subTest(format=format_name):
                entry = {"schema": {"openapi_pointer": pointer}}
                validator = module.validator_for_manifest_entry(entry, self.spec)
                self.assertTrue(
                    list(validator.iter_errors(instance)),
                    f"Project validator accepted malformed {format_name}",
                )

    def test_all_json_request_schemas_deny_tenant_overpost(self) -> None:
        request_schema_names: set[str] = set()
        for path_item in self.spec["paths"].values():
            for method, operation in path_item.items():
                if method.lower() not in MUTATING_METHODS or not isinstance(operation, dict):
                    continue
                request_body = operation.get("requestBody")
                if not request_body:
                    continue
                schema = request_body["content"]["application/json"]["schema"]
                ref = schema.get("$ref")
                self.assertIsNotNone(ref, f"Inline request schema is not quality-auditable: {operation.get('operationId')}")
                request_schema_names.add(ref.rsplit("/", 1)[-1])

        self.assertTrue(request_schema_names, "No mutation request schemas discovered")
        pending = list(request_schema_names)
        reachable_request_schemas: set[str] = set()
        while pending:
            schema_name = pending.pop()
            if schema_name in reachable_request_schemas:
                continue
            self.assertIn(schema_name, self.schemas, f"Mutation request references missing schema {schema_name}")
            if schema_name not in self.schemas:
                continue
            reachable_request_schemas.add(schema_name)
            pending.extend(component_references(self.schemas[schema_name]) - reachable_request_schemas)

        for schema_name in sorted(reachable_request_schemas):
            with self.subTest(schema=schema_name):
                for node in schema_nodes(self.schemas[schema_name]):
                    properties = node.get("properties")
                    if not isinstance(properties, dict):
                        continue
                    forbidden = {"organization_id", "tenant_id"} & set(properties)
                    self.assertFalse(
                        forbidden,
                        f"{schema_name} lets the client select tenant field(s): {sorted(forbidden)}",
                    )
                    self.assertIs(
                        node.get("additionalProperties"),
                        False,
                        f"{schema_name} has an open request object that permits tenant over-posting",
                    )

    def test_participant_input_requires_exactly_one_authoritative_identity(self) -> None:
        profile_id = "40000000-0000-4000-8000-000000000001"
        dependent_id = "50000000-0000-4000-8000-000000000001"
        self.assert_valid("ParticipantInput", {"profile_id": profile_id})
        self.assert_valid("ParticipantInput", {"dependent_id": dependent_id})
        self.assert_invalid(
            "ParticipantInput",
            {"profile_id": profile_id, "dependent_id": dependent_id},
            "ParticipantInput accepted both profile_id and dependent_id",
        )
        self.assert_invalid(
            "ParticipantInput",
            {},
            "ParticipantInput accepted neither profile_id nor dependent_id",
        )

    def test_legal_document_and_guardian_evidence_are_contractually_complete(self) -> None:
        legal_document_paths = []
        for path, path_item in self.spec["paths"].items():
            get = path_item.get("get") if isinstance(path_item, dict) else None
            text = f"{path} {get.get('operationId', '') if isinstance(get, dict) else ''}".lower()
            if get and "legal" in text and "document" in text:
                legal_document_paths.append(path)
        self.assertTrue(
            legal_document_paths,
            "No legal-document retrieval operation exists; clients cannot review the active text they accept",
        )

        evidence = self.schemas.get("ConsentEvidence")
        self.assertIsNotNone(evidence, "Missing ConsentEvidence schema")
        if evidence is None:
            return
        required = set(evidence.get("required", []))
        common = {
            "document_id",
            "document_version_label",
            "document_content_hash",
            "registration_participant_id",
            "signer_profile_id",
            "accepted_name",
            "accepted_at",
            "locale",
            "method",
        }
        self.assertTrue(
            common.issubset(required),
            f"ConsentEvidence is missing attributable/versioned fields: {sorted(common - required)}",
        )

        guardian_create = self.schemas.get("GuardianConsentCreate")
        self.assertIsNotNone(guardian_create, "Missing GuardianConsentCreate schema")
        if guardian_create is None:
            return
        guardian_required = set(guardian_create.get("required", []))
        guardian_fields = {
            "document_id",
            "document_version_label",
            "document_content_hash",
            "dependent_id",
            "registration_participant_id",
            "relationship",
            "accepted_name",
            "locale",
            "method",
        }
        self.assertTrue(
            guardian_fields.issubset(guardian_required),
            f"Guardian consent is missing attributable authority fields: {sorted(guardian_fields - guardian_required)}",
        )
        self.assertIn("relationship", required, "Persisted consent evidence loses guardian authority")

    def test_safety_share_recipient_bounds_and_scope_are_explicit(self) -> None:
        base = {
            "occurrence_id": "10000000-0000-4000-8000-000000000001",
            "site_id": "30000000-0000-4000-8000-000000000001",
            "recipient_ids": ["40000000-0000-4000-8000-000000000001"],
            "expires_at": "2027-01-16T19:00:00Z",
            "purpose": "Event-day safety coordination",
        }
        self.assert_valid("SafetyShareCreate", base)
        for recipients, label in [([], "empty"), ([base["recipient_ids"][0]] * 2, "duplicate")]:
            with self.subTest(recipients=label):
                instance = copy.deepcopy(base)
                instance["recipient_ids"] = recipients
                self.assert_invalid(
                    "SafetyShareCreate",
                    instance,
                    f"SafetyShareCreate accepted {label} recipients",
                )
        instance = copy.deepcopy(base)
        instance["recipient_ids"] = [f"40000000-0000-4000-8000-{index:012d}" for index in range(21)]
        self.assert_invalid("SafetyShareCreate", instance, "SafetyShareCreate accepted more than 20 recipients")

        _, _, create_operation = self.operation("createSafetyShare")
        _, _, get_operation = self.operation("getSafetyShare")
        _, _, location_operation = self.operation("getSafetyShareLocation")
        schema = self.schemas["SafetyShareCreate"]
        self.assertTrue(
            {"occurrence_id", "site_id", "recipient_ids", "expires_at", "purpose"}.issubset(
                schema.get("required", [])
            ),
            "SafetyShareCreate does not bind occurrence, site, recipients, expiry, and purpose",
        )

        read_documentation = " ".join(
            response.get("description", "")
            for operation in [get_operation, location_operation]
            for response in operation.get("responses", {}).values()
        ).lower()
        self.assertIn(
            "authorized",
            read_documentation,
            "Safety Sharing reads do not require an explicitly authorized recipient",
        )
        self.assertRegex(
            read_documentation,
            r"active|current recipient",
            "Safety Sharing reads do not deny expired or removed recipient access",
        )

        creation_documentation = " ".join(
            str(value)
            for value in [
                create_operation.get("description", ""),
                *[
                    response.get("description", "")
                    for response in create_operation.get("responses", {}).values()
                ],
                schema.get("description", ""),
                schema["properties"]["expires_at"].get("description", ""),
                schema["properties"]["recipient_ids"].get("description", ""),
            ]
        ).lower()
        missing_creation_rules = []
        if not re.search(r"adult[- ]only|adult sharer|minor(?:s)? (?:cannot|may not|must not|denied)", creation_documentation):
            missing_creation_rules.append("adult-only/minor denial")
        if "authorized" not in creation_documentation or "occurrence" not in creation_documentation:
            missing_creation_rules.append("same-occurrence authorized-recipient scope")
        if "future" not in creation_documentation:
            missing_creation_rules.append("future expiry")
        if not re.search(
            r"\bmax(?:imum)?\b.*\bduration\b|\bduration\b.*\bmax(?:imum)?\b",
            creation_documentation,
        ):
            missing_creation_rules.append("server-enforced maximum duration")
        self.assertFalse(
            missing_creation_rules,
            "Safety Sharing creation does not bind: " + ", ".join(missing_creation_rules),
        )

    def test_announcement_audience_is_conditionally_well_formed(self) -> None:
        occurrence_id = "10000000-0000-4000-8000-000000000001"
        site_id = "30000000-0000-4000-8000-000000000001"

        def announcement(audience: dict[str, Any]) -> dict[str, Any]:
            return {
                "occurrence_id": occurrence_id,
                "audience": audience,
                "title": "Schedule update",
                "body": "Please check your assignment.",
                "emergency": False,
            }

        valid = [
            {"kind": "all_registered"},
            {"kind": "assigned_site", "site_id": site_id},
            {"kind": "role", "role": "site_lead"},
        ]
        invalid = [
            {"kind": "assigned_site"},
            {"kind": "role"},
            {"kind": "all_registered", "site_id": site_id},
            {"kind": "assigned_site", "site_id": site_id, "role": "site_lead"},
            {"kind": "role", "role": "site_lead", "site_id": site_id},
        ]
        for audience in valid:
            with self.subTest(valid=audience):
                self.assert_valid("AnnouncementCreate", announcement(audience))
        for audience in invalid:
            with self.subTest(invalid=audience):
                self.assert_invalid(
                    "AnnouncementCreate",
                    announcement(audience),
                    f"AnnouncementCreate accepted ambiguous audience {audience}",
                )

    def test_idempotency_and_capacity_conflict_contracts(self) -> None:
        idempotency_ref = "#/components/parameters/IdempotencyKey"
        for path, path_item in self.spec["paths"].items():
            for method, operation in path_item.items():
                if method.lower() not in MUTATING_METHODS or not isinstance(operation, dict):
                    continue
                refs = {
                    parameter.get("$ref")
                    for parameter in operation.get("parameters", [])
                    if isinstance(parameter, dict)
                }
                self.assertIn(idempotency_ref, refs, f"{method.upper()} {path} lacks Idempotency-Key")

        self.assert_valid(
            "ErrorEnvelope",
            load_json(FIXTURES / "error-idempotency-conflict.valid.json"),
        )
        self.assert_valid(
            "ErrorEnvelope",
            load_json(FIXTURES / "error-capacity-conflict.valid.json"),
        )
        for operation_id in ["createRegistration", "submitRegistration", "confirmAssignment"]:
            with self.subTest(operation=operation_id):
                _, _, operation = self.operation(operation_id)
                self.assertIn("409", operation.get("responses", {}), f"{operation_id} lacks capacity/conflict response")

    def test_media_member_feed_and_public_gallery_are_separate(self) -> None:
        media_gets: list[tuple[str, dict[str, Any]]] = []
        for path, path_item in self.spec["paths"].items():
            operation = path_item.get("get") if isinstance(path_item, dict) else None
            if operation and "media" in operation.get("tags", []):
                media_gets.append((path, operation))

        member = [(path, operation) for path, operation in media_gets if operation.get("security") != []]
        public = [(path, operation) for path, operation in media_gets if operation.get("security") == []]
        self.assertTrue(member, "No authenticated event-member media feed GET operation exists")
        self.assertTrue(public, "No separate anonymous public-gallery media GET operation exists")
        self.assertTrue(
            any("occurrence" in path for path, _ in member),
            "Member media feed is not occurrence scoped",
        )

        media = self.schemas.get("MediaAsset")
        self.assertIsNotNone(media, "Missing MediaAsset schema")
        properties = media.get("properties", {})
        required = set(media.get("required", []))
        member_field = next(
            (field for field in ["event_feed_state", "member_feed_state"] if field in properties),
            None,
        )
        self.assertIsNotNone(member_field, "MediaAsset conflates visibility; missing event/member feed state")
        self.assertIn("public_gallery_state", properties, "MediaAsset conflates visibility; missing public_gallery_state")
        if member_field is None or "public_gallery_state" not in properties:
            return
        self.assertIn(member_field, required, f"MediaAsset does not require {member_field}")
        self.assertIn("public_gallery_state", required, "MediaAsset does not require public_gallery_state")

        member_values = known_values(dereference_local(properties[member_field], self.spec))
        public_values = known_values(
            dereference_local(properties.get("public_gallery_state", {}), self.spec)
        )
        self.assertIn("visible", member_values, "Member feed has no automatic visible state")
        self.assertTrue(
            any("quarantin" in value or "hidden" in value for value in member_values),
            "Member feed has no report-driven hidden/quarantined state",
        )
        self.assertIn("published", public_values, "Anonymous gallery has no explicit published state")
        self.assertNotEqual(member_values, public_values, "Member feed and public gallery reuse one lifecycle")

    def test_media_processing_and_report_semantics_are_binding(self) -> None:
        _, _, completion = self.operation("completeMediaUpload")
        _, _, member_feed = self.operation("listEventMediaFeed")
        completion_text = " ".join(
            [
                completion.get("description", ""),
                *[response.get("description", "") for response in completion.get("responses", {}).values()],
                member_feed.get("description", ""),
                *[response.get("description", "") for response in member_feed.get("responses", {}).values()],
            ]
        ).lower()
        for term in ["adult", "event", "feed", "without moderator preapproval"]:
            self.assertIn(term, completion_text, f"Media completion contract does not state {term} behavior")
        self.assertTrue(
            "automatic" in completion_text or ("transitions" in completion_text and "visible" in completion_text),
            "Media completion contract does not bind successful processing to member-feed visibility",
        )

        processed_adult = {
            "id": "10000000-0000-4000-8000-000000000001",
            "organization_id": "20000000-0000-4000-8000-000000000001",
            "occurrence_id": "30000000-0000-4000-8000-000000000001",
            "site_id": None,
            "caption": "Volunteers at work",
            "processing_state": "ready",
            "event_feed_state": "visible",
            "public_gallery_state": "not_submitted",
            "created_at": "2027-01-16T15:00:00Z",
            "processed_at": "2027-01-16T15:01:00Z",
            "version": 1,
        }
        self.assert_valid("MediaAsset", processed_adult)

        _, _, report = self.operation("createMediaReport")
        report_text = " ".join(
            [
                report.get("description", ""),
                *[response.get("description", "") for response in report.get("responses", {}).values()],
            ]
        ).lower()
        self.assertIn("atomic", report_text, "Report contract does not guarantee an atomic visibility change")
        self.assertRegex(report_text, r"hid|quarantin", "Report contract does not immediately hide/quarantine media")
        self.assertNotRegex(report_text, r"\bmay\b", "Report visibility is optional instead of binding")

        report_response_schema = (
            report["responses"]["200"]["content"]["application/json"]["schema"]
        )
        report_receipt = dereference_local(report_response_schema, self.spec)
        report_required = set(report_receipt.get("required", []))
        self.assertTrue(
            {"quarantined_at", "event_feed_state", "public_gallery_state"}.issubset(report_required),
            "Report receipt lacks synchronous quarantine evidence",
        )
        feed_states = known_values(
            dereference_local(report_receipt["properties"]["event_feed_state"], self.spec)
        )
        gallery_states = known_values(
            dereference_local(report_receipt["properties"]["public_gallery_state"], self.spec)
        )
        self.assertNotIn("visible", feed_states, "A successful report can leave feed delivery visible")
        self.assertNotIn("published", gallery_states, "A successful report can leave gallery delivery published")
        self.assertTrue(
            feed_states <= {"quarantined", "removed"},
            f"Report receipt permits non-quarantine feed states: {sorted(feed_states)}",
        )
        self.assertTrue(
            gallery_states <= {"unpublished", "rejected", "removed"},
            f"Report receipt permits visible gallery states: {sorted(gallery_states)}",
        )

        _, _, upload = self.operation("createMediaUpload")
        upload_text = " ".join(
            [
                upload.get("description", ""),
                *[response.get("description", "") for response in upload.get("responses", {}).values()],
            ]
        ).lower()
        missing_upload_rules = []
        if not re.search(
            r"only[^.]{0,40}adult|adult[- ]only|adult (?:profile|uploader)|uploader[^.]{0,40}adult",
            upload_text,
        ):
            missing_upload_rules.append("adult-only authorization")
        if not re.search(
            r"minor(?:s)?[^.]{0,40}(?:cannot|may not|must not|are forbidden|denied)",
            upload_text,
        ):
            missing_upload_rules.append("explicit minor denial")
        self.assertFalse(
            missing_upload_rules,
            "Media upload operation does not bind: " + ", ".join(missing_upload_rules),
        )

    def test_realtime_rejects_every_sensitive_category(self) -> None:
        schema = load_json(REALTIME_SCHEMA_PATH)
        validator = Draft202012Validator(schema, format_checker=self.format_checker)
        base = load_json(FIXTURES / "realtime-event.valid.json")
        self.assertFalse(list(validator.iter_errors(base)), "Valid realtime fixture failed")

        forbidden = {
            "precise_location": {"latitude": 30.123456, "longitude": -91.123456},
            "latitude": 30.123456,
            "longitude": -91.123456,
            "contact_email": "person@example.org",
            "phone": "+1-555-0100",
            "consent_payload": {"signature": "name"},
            "incident_description": "Restricted incident narrative",
            "minor_data": {"name": "Dependent"},
            "dependent_id": "50000000-0000-4000-8000-000000000001",
            "media_url": "https://private.example/media.jpg",
            "storage_key": "tenant/private/original.jpg",
            "object_key": "tenant/private/original.jpg",
            "participant_name": "Private Person",
            "metadata": {"storage_key": "nested/private/object"},
        }
        for field, value in forbidden.items():
            with self.subTest(field=field):
                instance = copy.deepcopy(base)
                instance["payload"][field] = value
                self.assertTrue(
                    list(validator.iter_errors(instance)),
                    f"Realtime schema accepted sensitive field {field}",
                )

    def test_personal_and_tenant_export_job_contracts(self) -> None:
        personal_job = {
            "id": "70000000-0000-4000-8000-000000000001",
            "organization_id": None,
            "kind": "personal_data_export",
            "state": "queued",
            "created_at": "2027-01-16T12:00:00Z",
            "result_url": None,
            "result_expires_at": None,
            "version": 1,
        }
        self.assert_valid("Job", personal_job)

        tenant_job = {
            "id": "70000000-0000-4000-8000-000000000002",
            "organization_id": "10000000-0000-4000-8000-000000000001",
            "kind": "attendance_export",
            "state": "succeeded",
            "created_at": "2027-01-16T12:00:00Z",
            "result_url": "https://downloads.dayofservice.example/export.csv",
            "result_expires_at": "2027-01-17T12:00:00Z",
            "version": 2,
        }
        self.assert_valid("Job", tenant_job)

        invalid_job = copy.deepcopy(personal_job)
        invalid_job["organization_id"] = "not-a-uuid"
        self.assert_invalid("Job", invalid_job, "Job accepted invalid non-UUID organization_id")


if __name__ == "__main__":
    unittest.main()

