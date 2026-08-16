# Roles and permissions

## Roles

Platform roles: `platform_support`, `platform_admin`. Organization roles: `org_owner`, `organizer`, `media_moderator`, `site_lead`. Participant states: visitor, authenticated adult, guardian, and minor dependent.

## Permission rules

| Capability | Public | Adult/guardian | Site lead | Organizer | Owner | Platform |
|---|---:|---:|---:|---:|---:|---:|
| Read published event/site summary | Yes | Yes | Yes | Yes | Yes | Support need |
| Register self/team/dependent | No | Yes | No special grant | Yes | Yes | No |
| View own household registration | No | Yes | No | Scoped support | Yes | No |
| View assigned roster | No | Own record | Assigned sites only | Tenant | Tenant | Break-glass only |
| Check attendance | No | Self where enabled | Assigned sites | Tenant | Tenant | No |
| Edit event/site/task | No | No | Operational task updates | Yes | Yes | No |
| Moderate tenant media | Approved only | Own submissions | No | If granted | Yes | Abuse escalation |
| Manage tenant roles/settings | No | No | No | Limited | Yes | Platform admin |

## Enforcement

Authorization is deny-by-default and evaluated server-side. Organization membership alone does not grant organizer access. Every privileged mutation checks tenant, role, resource state, and assignment scope. RLS protects direct data access; edge functions do not bypass it except narrowly documented service operations. Support access requires a ticket/reason, expires, and creates an immutable audit event.

## Separation and lifecycle

Owners cannot grant platform roles. The last owner cannot remove themself. Invitations expire and are single-use. Role changes revoke active authorization caches and sessions where practical. Suspended users cannot mutate data; deletion and legal retention are handled separately.
