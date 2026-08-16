begin;

create table app_private.profiles (
  id uuid primary key default extensions.gen_random_uuid(),
  auth_user_id uuid not null unique,
  display_name text not null check (length(display_name) between 1 and 120),
  state text not null default 'active' check (state in ('active', 'suspended', 'deleted')),
  version bigint not null default 1 check (version > 0),
  created_at timestamptz not null default transaction_timestamp(),
  updated_at timestamptz not null default transaction_timestamp()
);

create table app_private.profile_assurances (
  id uuid primary key default extensions.gen_random_uuid(),
  profile_id uuid not null references app_private.profiles(id) on delete restrict,
  assurance_type text not null check (assurance_type in ('adult')),
  asserted_at timestamptz not null default transaction_timestamp(),
  expires_at timestamptz,
  revoked_at timestamptz,
  unique (profile_id, assurance_type),
  check (expires_at is null or expires_at > asserted_at),
  check (revoked_at is null or revoked_at >= asserted_at)
);

create table app_private.organizations (
  id uuid primary key default extensions.gen_random_uuid(),
  legal_name text not null check (length(legal_name) between 1 and 200),
  display_name text not null check (length(display_name) between 1 and 120),
  slug extensions.citext not null unique,
  state text not null default 'active' check (state in ('active', 'suspended', 'closed')),
  version bigint not null default 1 check (version > 0),
  created_at timestamptz not null default transaction_timestamp(),
  updated_at timestamptz not null default transaction_timestamp()
);

create table app_private.organization_memberships (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references app_private.organizations(id) on delete restrict,
  profile_id uuid not null references app_private.profiles(id) on delete restrict,
  state text not null default 'active' check (state in ('active', 'suspended', 'removed')),
  version bigint not null default 1 check (version > 0),
  created_at timestamptz not null default transaction_timestamp(),
  updated_at timestamptz not null default transaction_timestamp(),
  unique (organization_id, id),
  unique (organization_id, profile_id)
);

create table app_private.membership_role_grants (
  organization_id uuid not null,
  membership_id uuid not null,
  role_name text not null check (
    role_name in ('org_owner', 'organizer', 'media_moderator')
  ),
  granted_at timestamptz not null default transaction_timestamp(),
  primary key (organization_id, membership_id, role_name),
  foreign key (organization_id, membership_id)
    references app_private.organization_memberships(organization_id, id)
    on delete cascade
);

create table app_private.organization_invitations (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references app_private.organizations(id) on delete restrict,
  invited_by_membership_id uuid not null,
  token_hash bytea not null unique check (octet_length(token_hash) = 32),
  normalized_email_hash bytea not null check (octet_length(normalized_email_hash) = 32),
  email_hint text not null check (length(email_hint) between 1 and 320),
  state text not null default 'pending' check (state in ('pending', 'accepted', 'expired', 'revoked')),
  expires_at timestamptz not null,
  accepted_by_profile_id uuid references app_private.profiles(id) on delete restrict,
  accepted_at timestamptz,
  revoked_at timestamptz,
  version bigint not null default 1 check (version > 0),
  created_at timestamptz not null default transaction_timestamp(),
  unique (organization_id, id),
  foreign key (organization_id, invited_by_membership_id)
    references app_private.organization_memberships(organization_id, id)
    on delete restrict,
  check (
    (state = 'accepted' and accepted_by_profile_id is not null and accepted_at is not null and revoked_at is null)
    or (state = 'revoked' and revoked_at is not null and accepted_at is null)
    or (state in ('pending', 'expired') and accepted_at is null and revoked_at is null)
  )
);

create table app_private.organization_invitation_contacts (
  organization_id uuid not null,
  invitation_id uuid not null,
  encrypted_delivery_address bytea not null,
  key_version integer not null check (key_version > 0),
  primary key (organization_id, invitation_id),
  foreign key (organization_id, invitation_id)
    references app_private.organization_invitations(organization_id, id)
    on delete cascade
);

create table app_private.organization_invitation_role_grants (
  organization_id uuid not null,
  invitation_id uuid not null,
  role_name text not null check (
    role_name in ('org_owner', 'organizer', 'media_moderator')
  ),
  primary key (organization_id, invitation_id, role_name),
  foreign key (organization_id, invitation_id)
    references app_private.organization_invitations(organization_id, id)
    on delete cascade
);

do $rls$
declare
  table_name text;
begin
  foreach table_name in array array[
    'profiles', 'profile_assurances', 'organizations',
    'organization_memberships', 'membership_role_grants',
    'organization_invitations', 'organization_invitation_contacts',
    'organization_invitation_role_grants'
  ] loop
    execute format('alter table app_private.%I enable row level security', table_name);
    execute format('alter table app_private.%I force row level security', table_name);
    execute format(
      'create policy dos_policy_facts on app_private.%I for select to dos_policy using (true)',
      table_name
    );
  end loop;
end
$rls$;

grant select on app_private.profiles, app_private.profile_assurances,
  app_private.organizations, app_private.organization_memberships,
  app_private.membership_role_grants,
  app_private.organization_invitations,
  app_private.organization_invitation_role_grants to dos_policy;

create or replace function policy.actor_profile_id()
returns uuid
language sql
stable
security definer
set search_path = ''
as $function$
  select p.id
  from app_private.profiles as p
  where p.auth_user_id = policy.auth_uid()
    and p.state = 'active'
  limit 1
$function$;
alter function policy.actor_profile_id() owner to dos_policy;

create or replace function policy.actor_is_adult()
returns boolean
language sql
stable
security definer
set search_path = ''
as $function$
  select coalesce(exists (
    select 1
    from app_private.profile_assurances as a
    where a.profile_id = policy.actor_profile_id()
      and a.assurance_type = 'adult'
      and a.revoked_at is null
      and (a.expires_at is null or a.expires_at > statement_timestamp())
  ), false)
$function$;
alter function policy.actor_is_adult() owner to dos_policy;

create or replace function policy.is_active_member(p_organization_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $function$
  select coalesce(exists (
    select 1
    from app_private.organization_memberships as m
    join app_private.organizations as o on o.id = m.organization_id
    where m.organization_id = p_organization_id
      and m.profile_id = policy.actor_profile_id()
      and m.state = 'active'
      and o.state = 'active'
  ), false)
$function$;
alter function policy.is_active_member(uuid) owner to dos_policy;

create or replace function policy.has_org_role(
  p_organization_id uuid,
  p_role_names text[]
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $function$
  select coalesce(exists (
    select 1
    from app_private.organization_memberships as m
    join app_private.membership_role_grants as r
      on r.organization_id = m.organization_id and r.membership_id = m.id
    where m.organization_id = p_organization_id
      and m.profile_id = policy.actor_profile_id()
      and m.state = 'active'
      and r.role_name = any (p_role_names)
  ), false)
$function$;
alter function policy.has_org_role(uuid, text[]) owner to dos_policy;

revoke all on function policy.actor_profile_id(), policy.actor_is_adult(),
  policy.is_active_member(uuid), policy.has_org_role(uuid, text[]) from public;
grant execute on function policy.actor_profile_id(), policy.actor_is_adult(),
  policy.is_active_member(uuid), policy.has_org_role(uuid, text[])
  to dos_identity_query, dos_identity_command;

grant select, update on app_private.profiles to dos_identity_command;
grant select on app_private.profile_assurances, app_private.organizations to dos_identity_command;
grant select, insert, update on app_private.organization_memberships,
  app_private.membership_role_grants,
  app_private.organization_invitations,
  app_private.organization_invitation_contacts,
  app_private.organization_invitation_role_grants to dos_identity_command;
grant delete on app_private.membership_role_grants,
  app_private.organization_invitation_role_grants to dos_identity_command;

create policy actor_profile_select on app_private.profiles for select to dos_identity_command
  using (id = policy.actor_profile_id());
create policy actor_profile_update on app_private.profiles for update to dos_identity_command
  using (id = policy.actor_profile_id()) with check (id = policy.actor_profile_id());
create policy actor_assurance_select on app_private.profile_assurances for select to dos_identity_command
  using (profile_id = policy.actor_profile_id());
create policy active_member_organization_select on app_private.organizations for select to dos_identity_command
  using (policy.is_active_member(id));
create policy membership_select on app_private.organization_memberships for select to dos_identity_command
  using (profile_id = policy.actor_profile_id() or policy.has_org_role(organization_id, array['org_owner']));
create policy membership_owner_write on app_private.organization_memberships for all to dos_identity_command
  using (policy.has_org_role(organization_id, array['org_owner']))
  with check (policy.has_org_role(organization_id, array['org_owner']));

do $tenant_policies$
declare
  table_name text;
begin
  foreach table_name in array array[
    'membership_role_grants',
    'organization_invitations', 'organization_invitation_contacts',
    'organization_invitation_role_grants'
  ] loop
    execute format(
      'create policy owner_scope on app_private.%I for all to dos_identity_command using (policy.has_org_role(organization_id, array[''org_owner''])) with check (policy.has_org_role(organization_id, array[''org_owner'']))',
      table_name
    );
  end loop;
end
$tenant_policies$;

create or replace function app_private.guard_last_active_owner_membership()
returns trigger
language plpgsql
set search_path = ''
as $function$
begin
  if old.state = 'active'
     and (tg_op = 'DELETE' or new.state <> 'active')
     and exists (
       select 1 from app_private.membership_role_grants r
       where r.organization_id = old.organization_id
         and r.membership_id = old.id and r.role_name = 'org_owner'
     )
     and not exists (
       select 1
       from app_private.organization_memberships m
       join app_private.membership_role_grants r
         on r.organization_id = m.organization_id and r.membership_id = m.id
       where m.organization_id = old.organization_id
         and m.id <> old.id and m.state = 'active' and r.role_name = 'org_owner'
     ) then
    raise exception 'organization must retain an active owner' using errcode = '23514';
  end if;
  return case when tg_op = 'DELETE' then old else new end;
end
$function$;

create trigger guard_last_active_owner_membership
before update or delete on app_private.organization_memberships
for each row execute function app_private.guard_last_active_owner_membership();

create or replace function app_private.guard_last_active_owner_role()
returns trigger
language plpgsql
set search_path = ''
as $function$
begin
  if old.role_name = 'org_owner'
     and (tg_op = 'DELETE' or new.role_name <> 'org_owner')
     and not exists (
       select 1
       from app_private.organization_memberships m
       join app_private.membership_role_grants r
         on r.organization_id = m.organization_id and r.membership_id = m.id
       where m.organization_id = old.organization_id
         and m.id <> old.membership_id and m.state = 'active'
         and r.role_name = 'org_owner'
     ) then
    raise exception 'organization must retain an active owner' using errcode = '23514';
  end if;
  return case when tg_op = 'DELETE' then old else new end;
end
$function$;

create trigger guard_last_active_owner_role
before update or delete on app_private.membership_role_grants
for each row execute function app_private.guard_last_active_owner_role();

create or replace function app_private.guard_invitation_terminal_state()
returns trigger
language plpgsql
set search_path = ''
as $function$
begin
  if old.state in ('accepted', 'expired', 'revoked') and new is distinct from old then
    raise exception 'terminal invitation is immutable' using errcode = '23514';
  end if;
  return new;
end
$function$;

create trigger guard_invitation_terminal_state
before update on app_private.organization_invitations
for each row execute function app_private.guard_invitation_terminal_state();

revoke all on all tables in schema app_private from public;

commit;
