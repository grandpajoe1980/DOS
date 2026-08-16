# Review map

CODEOWNERS enforces the currently available GitHub owner. Pull requests also
name the responsible review role so ownership remains explicit as teams are
added.

| Surface | Required review role | Paths |
|---|---|---|
| Versioned interfaces | Contract owner plus affected client/data owner | `contracts/**`, generated clients |
| Data and authorization | Database/security owner | `supabase/migrations/**`, functions, RLS and policy tests |
| Native app | iOS owner; accessibility review for perceptible changes | `DOS/**`, `DOSTests/**`, `DOSUITests/**`, Xcode project |
| Responsive web | Web owner; accessibility review for perceptible changes | `web/**` |
| Media and background work | Media/security owner plus integration owner | `workers/**`, media functions/contracts |
| Architecture/product | Lead Architect and Product Delivery Manager | `docs/ARCHITECTURE.md`, `docs/adr/**`, requirements/status |
| CI, environment, and release | Integration/Platform owner plus release owner | `.github/workflows/**`, `Configuration/**`, release scripts |

Contract, migration/RLS, Xcode/project, shared navigation, and release files
have one writer at a time. Reviewers verify requirement IDs, compatibility,
authorization, tests, telemetry redaction, accessibility, and rollback rather
than approving by path ownership alone.

