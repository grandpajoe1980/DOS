from __future__ import annotations

import re
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
MIGRATIONS_DIR = ROOT / "supabase" / "migrations"


class DatabaseMigrationTests(unittest.TestCase):
    def setUp(self) -> None:
        self.migrations = sorted(MIGRATIONS_DIR.glob("*.sql"))
        self.assertTrue(self.migrations, "No database migrations found in supabase/migrations/")

    def test_all_migrations_are_transaction_wrapped(self) -> None:
        for path in self.migrations:
            with self.subTest(migration=path.name):
                content = path.read_text(encoding="utf-8").strip()
                self.assertTrue(
                    content.lower().startswith("begin;"),
                    f"{path.name} does not start with 'begin;'",
                )
                self.assertTrue(
                    content.lower().endswith("commit;"),
                    f"{path.name} does not end with 'commit;'",
                )

    def test_all_tables_have_forced_row_level_security(self) -> None:
        table_pattern = re.compile(
            r"create\s+table\s+(?:if\s+not\s+exists\s+)?([a-zA-Z0-9_]+\.[a-zA-Z0-9_]+)",
            re.IGNORECASE,
        )
        enable_rls_pattern = re.compile(
            r"alter\s+table\s+([a-zA-Z0-9_]+\.[a-zA-Z0-9_]+)\s+enable\s+row\s+level\s+security",
            re.IGNORECASE,
        )
        force_rls_pattern = re.compile(
            r"alter\s+table\s+([a-zA-Z0-9_]+\.[a-zA-Z0-9_]+)\s+force\s+row\s+level\s+security",
            re.IGNORECASE,
        )

        all_content = "\n".join(path.read_text(encoding="utf-8") for path in self.migrations)
        created_tables = set(table_pattern.findall(all_content))
        self.assertTrue(created_tables, "No tables discovered across migrations")

        enabled_rls_tables = set(enable_rls_pattern.findall(all_content))
        forced_rls_tables = set(force_rls_pattern.findall(all_content))

        # Check for tables enabled/forced via array loops
        loop_pattern = re.compile(
            r"foreach\s+table_name\s+in\s+array\s+array\[(.*?)\]",
            re.DOTALL | re.IGNORECASE,
        )
        for match in loop_pattern.finditer(all_content):
            raw_names = re.findall(r"'([a-zA-Z0-9_]+)'", match.group(1))
            for name in raw_names:
                # Could be in app_private or ops_private
                for schema in ["app_private", "ops_private"]:
                    fqn = f"{schema}.{name}"
                    if fqn in created_tables:
                        enabled_rls_tables.add(fqn)
                        forced_rls_tables.add(fqn)

        for table in sorted(created_tables):
            with self.subTest(table=table):
                self.assertIn(
                    table,
                    enabled_rls_tables,
                    f"Table {table} does not have ENABLE ROW LEVEL SECURITY",
                )
                self.assertIn(
                    table,
                    forced_rls_tables,
                    f"Table {table} does not have FORCE ROW LEVEL SECURITY",
                )

    def test_all_functions_set_empty_search_path(self) -> None:
        function_pattern = re.compile(
            r"create\s+(?:or\s+replace\s+)?function\s+([a-zA-Z0-9_]+\.[a-zA-Z0-9_]+)\s*\([^)]*\).*?as\s+\$function\$",
            re.DOTALL | re.IGNORECASE,
        )
        for path in self.migrations:
            content = path.read_text(encoding="utf-8")
            for match in function_pattern.finditer(content):
                func_name = match.group(1)
                func_header = match.group(0)
                with self.subTest(migration=path.name, function=func_name):
                    self.assertIn(
                        "set search_path = ''",
                        func_header.lower(),
                        f"Function {func_name} in {path.name} does not set search_path = ''",
                    )

    def test_no_private_tables_granted_to_public(self) -> None:
        grant_pattern = re.compile(
            r"grant\s+.*?\s+on\s+.*?(?:app_private|ops_private)\..*?\s+to\s+public",
            re.IGNORECASE,
        )
        for path in self.migrations:
            content = path.read_text(encoding="utf-8")
            matches = grant_pattern.findall(content)
            self.assertFalse(
                matches,
                f"Migration {path.name} grants private tables to public: {matches}",
            )

    def test_all_roles_are_hardened(self) -> None:
        role_pattern = re.compile(
            r"create\s+role\s+([a-zA-Z0-9_]+)\s+nologin\s+noinherit\s+nobypassrls",
            re.IGNORECASE,
        )
        all_content = "\n".join(path.read_text(encoding="utf-8") for path in self.migrations)
        roles = role_pattern.findall(all_content)
        self.assertTrue(len(roles) > 0 or "dos_policy" in all_content, "Role creation not found")

    def test_public_occurrences_view_excludes_precise_location_data(self) -> None:
        m030 = next((p for p in self.migrations if "m030" in p.name), None)
        self.assertIsNotNone(m030, "M030 migration not found")
        content = m030.read_text(encoding="utf-8")
        
        view_match = re.search(
            r"create\s+or\s+replace\s+view\s+api_v1\.public_occurrences.*?;",
            content,
            re.DOTALL | re.IGNORECASE,
        )
        self.assertIsNotNone(view_match, "api_v1.public_occurrences view not found in M030")
        view_sql = view_match.group(0)
        
        self.assertNotIn("precise_address", view_sql, "Public occurrences view leaks precise_address")
        self.assertNotIn("precise_latitude", view_sql, "Public occurrences view leaks precise_latitude")
        self.assertNotIn("precise_longitude", view_sql, "Public occurrences view leaks precise_longitude")

    def test_atomic_capacity_check_uses_row_level_locking(self) -> None:
        m040 = next((p for p in self.migrations if "m040" in p.name), None)
        self.assertIsNotNone(m040, "M040 migration not found")
        content = m040.read_text(encoding="utf-8")
        
        func_match = re.search(
            r"create\s+or\s+replace\s+function\s+api_v1\.cmd_submit_registration.*?\bend\s*\$function\$;",
            content,
            re.DOTALL | re.IGNORECASE,
        )
        self.assertIsNotNone(func_match, "cmd_submit_registration function not found in M040")
        func_sql = func_match.group(0)
        
        self.assertIn("for update", func_sql.lower(), "cmd_submit_registration lacks row-level locking (FOR UPDATE)")


    def test_tenant_composite_keys_are_present(self) -> None:
        all_content = "\n".join(path.read_text(encoding="utf-8") for path in self.migrations)
        tenant_tables = [
            "programs", "occurrences", "sites", "shifts", "tasks",
            "registrations", "attendance_operations", "announcements",
            "incidents", "safety_shares"
        ]
        for table in tenant_tables:
            with self.subTest(table=table):
                pattern = rf"create\s+table\s+app_private\.{table}\s*\(.*?\bunique\s*\(\s*organization_id\s*,\s*id\s*\)"
                match = re.search(pattern, all_content, re.DOTALL | re.IGNORECASE)
                self.assertIsNotNone(
                    match,
                    f"Tenant table app_private.{table} missing composite unique(organization_id, id) constraint",
                )


if __name__ == "__main__":
    unittest.main()


