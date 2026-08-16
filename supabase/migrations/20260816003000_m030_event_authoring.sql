begin;

-- ============================================================================
-- Roles for Event Domain
-- ============================================================================

do $roles$
declare
  role_name text;
begin
  foreach role_name in array array[
    'dos_event_query',
    'dos_event_command'
  ] loop
    if not exists (select 1 from pg_catalog.pg_roles where rolname = role_name) then
      execute format('create role %I nologin noinherit nobypassrls', role_name);
    end if;
    execute format(
      'alter role %I with nologin noinherit nobypassrls nosuperuser nocreatedb nocreaterole noreplication',
      role_name
    );
  end loop;
end
$roles$;

grant usage on schema app_private, api_v1, policy to dos_event_query, dos_event_command;

-- ============================================================================
-- Tables in app_private
-- ============================================================================

create table app_private.programs (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references app_private.organizations(id) on delete cascade,
  title text not null check (length(title) between 1 and 200),
  summary text not null check (length(summary) between 1 and 2000),
  state text not null default 'active' check (state in ('active', 'archived')),
  created_at timestamptz not null default transaction_timestamp(),
  updated_at timestamptz not null default transaction_timestamp(),
  unique (organization_id, id)
);

create table app_private.occurrences (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references app_private.organizations(id) on delete cascade,
  program_id uuid not null references app_private.programs(id) on delete cascade,
  title text not null check (length(title) between 1 and 200),
  summary text not null check (length(summary) between 1 and 2000),
  starts_at timestamptz not null,
  ends_at timestamptz not null check (ends_at > starts_at),
  time_zone_identifier text not null check (length(time_zone_identifier) between 1 and 80),
  state text not null default 'draft' check (state in ('draft', 'published', 'archived')),
  published_at timestamptz,
  version bigint not null default 1,
  created_at timestamptz not null default transaction_timestamp(),
  updated_at timestamptz not null default transaction_timestamp(),
  unique (organization_id, id)
);

create table app_private.sites (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references app_private.organizations(id) on delete cascade,
  occurrence_id uuid not null references app_private.occurrences(id) on delete cascade,
  name text not null check (length(name) between 1 and 150),
  public_location text not null check (length(public_location) between 1 and 250),
  approximate_latitude double precision check (approximate_latitude between -90 and 90),
  approximate_longitude double precision check (approximate_longitude between -180 and 180),
  precise_address text check (precise_address is null or length(precise_address) between 1 and 500),
  precise_latitude double precision check (precise_latitude is null or precise_latitude between -90 and 90),
  precise_longitude double precision check (precise_longitude is null or precise_longitude between -180 and 180),
  accessibility text[] not null default array[]::text[],
  arrival_notes text not null default '',
  soft_target integer not null check (soft_target > 0),
  hard_safety_limit integer check (hard_safety_limit is null or hard_safety_limit >= soft_target),
  created_at timestamptz not null default transaction_timestamp(),
  updated_at timestamptz not null default transaction_timestamp(),
  unique (organization_id, id),
  unique (occurrence_id, id)
);

create table app_private.shifts (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references app_private.organizations(id) on delete cascade,
  occurrence_id uuid not null references app_private.occurrences(id) on delete cascade,
  site_id uuid not null references app_private.sites(id) on delete cascade,
  title text not null check (length(title) between 1 and 120),
  starts_at timestamptz not null,
  ends_at timestamptz not null check (ends_at > starts_at),
  capacity integer not null check (capacity > 0),
  created_at timestamptz not null default transaction_timestamp(),
  updated_at timestamptz not null default transaction_timestamp(),
  unique (organization_id, id)
);

create table app_private.tasks (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references app_private.organizations(id) on delete cascade,
  occurrence_id uuid not null references app_private.occurrences(id) on delete cascade,
  site_id uuid not null references app_private.sites(id) on delete cascade,
  title text not null check (length(title) between 1 and 120),
  description text not null default '',
  created_at timestamptz not null default transaction_timestamp(),
  updated_at timestamptz not null default transaction_timestamp(),
  unique (organization_id, id)
);

-- ============================================================================
-- Enable and Force RLS
-- ============================================================================

do $rls$
declare
  table_name text;
begin
  foreach table_name in array array['programs', 'occurrences', 'sites', 'shifts', 'tasks'] loop
    execute format('alter table app_private.%I enable row level security', table_name);
    execute format('alter table app_private.%I force row level security', table_name);
  end loop;
end
$rls$;

-- RLS Policies
create policy organizer_select_programs on app_private.programs
  for select to dos_event_query
  using (policy.has_org_role(organization_id, array['org_owner', 'organizer']));

create policy organizer_select_occurrences on app_private.occurrences
  for select to dos_event_query
  using (state = 'published' or policy.has_org_role(organization_id, array['org_owner', 'organizer']));

create policy organizer_select_sites on app_private.sites
  for select to dos_event_query
  using (
    exists (
      select 1 from app_private.occurrences as o
      where o.id = occurrence_id and o.state = 'published'
    )
    or policy.has_org_role(organization_id, array['org_owner', 'organizer'])
  );

create policy organizer_select_shifts on app_private.shifts
  for select to dos_event_query
  using (
    exists (
      select 1 from app_private.occurrences as o
      where o.id = occurrence_id and o.state = 'published'
    )
    or policy.has_org_role(organization_id, array['org_owner', 'organizer'])
  );

create policy organizer_select_tasks on app_private.tasks
  for select to dos_event_query
  using (policy.has_org_role(organization_id, array['org_owner', 'organizer']));

create policy organizer_all_programs on app_private.programs
  for all to dos_event_command
  using (policy.has_org_role(organization_id, array['org_owner', 'organizer']))
  with check (policy.has_org_role(organization_id, array['org_owner', 'organizer']));

create policy organizer_all_occurrences on app_private.occurrences
  for all to dos_event_command
  using (policy.has_org_role(organization_id, array['org_owner', 'organizer']))
  with check (policy.has_org_role(organization_id, array['org_owner', 'organizer']));

create policy organizer_all_sites on app_private.sites
  for all to dos_event_command
  using (policy.has_org_role(organization_id, array['org_owner', 'organizer']))
  with check (policy.has_org_role(organization_id, array['org_owner', 'organizer']));

create policy organizer_all_shifts on app_private.shifts
  for all to dos_event_command
  using (policy.has_org_role(organization_id, array['org_owner', 'organizer']))
  with check (policy.has_org_role(organization_id, array['org_owner', 'organizer']));

create policy organizer_all_tasks on app_private.tasks
  for all to dos_event_command
  using (policy.has_org_role(organization_id, array['org_owner', 'organizer']))
  with check (policy.has_org_role(organization_id, array['org_owner', 'organizer']));

-- ============================================================================
-- Views in api_v1
-- ============================================================================

create or replace view api_v1.public_occurrences with (security_barrier = true) as
select
  o.id,
  o.organization_id,
  o.title,
  o.summary,
  o.starts_at,
  o.ends_at,
  o.time_zone_identifier,
  o.state,
  coalesce(
    (
      select jsonb_agg(
        jsonb_build_object(
          'id', s.id,
          'name', s.name,
          'public_location', s.public_location,
          'approximate_latitude', s.approximate_latitude,
          'approximate_longitude', s.approximate_longitude,
          'accessibility', s.accessibility,
          'arrival_notes', s.arrival_notes,
          'soft_target', s.soft_target,
          'hard_safety_limit', s.hard_safety_limit
        ) order by s.name
      )
      from app_private.sites as s
      where s.occurrence_id = o.id
    ),
    '[]'::jsonb
  ) as sites
from app_private.occurrences as o
join app_private.organizations as org on org.id = o.organization_id
where o.state = 'published'
  and org.state = 'active';

alter view api_v1.public_occurrences owner to dos_event_query;

create or replace view api_v1.organizer_occurrences with (security_barrier = true) as
select
  o.id,
  o.organization_id,
  o.program_id,
  o.title,
  o.summary,
  o.starts_at,
  o.ends_at,
  o.time_zone_identifier,
  o.state,
  o.published_at,
  o.version,
  o.created_at,
  o.updated_at
from app_private.occurrences as o
where policy.has_org_role(o.organization_id, array['org_owner', 'organizer']);

alter view api_v1.organizer_occurrences owner to dos_event_query;

-- ============================================================================
-- Command functions in api_v1
-- ============================================================================

create or replace function api_v1.cmd_create_program(
  p_organization_id uuid,
  p_title text,
  p_summary text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_program_id uuid;
begin
  if not policy.has_org_role(p_organization_id, array['org_owner', 'organizer']) then
    raise exception 'organizer permission required' using errcode = '42501';
  end if;

  if p_title is null or length(trim(p_title)) = 0 or length(p_title) > 200 then
    raise exception 'invalid program title' using errcode = '22000';
  end if;
  if p_summary is null or length(trim(p_summary)) = 0 or length(p_summary) > 2000 then
    raise exception 'invalid program summary' using errcode = '22000';
  end if;

  insert into app_private.programs (organization_id, title, summary, state)
  values (p_organization_id, trim(p_title), trim(p_summary), 'active')
  returning id into v_program_id;

  return v_program_id;
end
$function$;

alter function api_v1.cmd_create_program(uuid, text, text) owner to dos_event_command;

create or replace function api_v1.cmd_create_occurrence(
  p_organization_id uuid,
  p_program_id uuid,
  p_title text,
  p_summary text,
  p_starts_at timestamptz,
  p_ends_at timestamptz,
  p_time_zone_identifier text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_occurrence_id uuid;
begin
  if not policy.has_org_role(p_organization_id, array['org_owner', 'organizer']) then
    raise exception 'organizer permission required' using errcode = '42501';
  end if;

  if p_starts_at is null or p_ends_at is null or p_ends_at <= p_starts_at then
    raise exception 'invalid occurrence schedule' using errcode = '22000';
  end if;

  insert into app_private.occurrences (
    organization_id,
    program_id,
    title,
    summary,
    starts_at,
    ends_at,
    time_zone_identifier,
    state
  )
  values (
    p_organization_id,
    p_program_id,
    trim(p_title),
    trim(p_summary),
    p_starts_at,
    p_ends_at,
    trim(p_time_zone_identifier),
    'draft'
  )
  returning id into v_occurrence_id;

  return v_occurrence_id;
end
$function$;

alter function api_v1.cmd_create_occurrence(uuid, uuid, text, text, timestamptz, timestamptz, text)
  owner to dos_event_command;

create or replace function api_v1.cmd_create_site(
  p_organization_id uuid,
  p_occurrence_id uuid,
  p_name text,
  p_public_location text,
  p_approx_lat double precision,
  p_approx_lng double precision,
  p_precise_address text,
  p_precise_lat double precision,
  p_precise_lng double precision,
  p_accessibility text[],
  p_arrival_notes text,
  p_soft_target int,
  p_hard_safety_limit int
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_site_id uuid;
begin
  if not policy.has_org_role(p_organization_id, array['org_owner', 'organizer']) then
    raise exception 'organizer permission required' using errcode = '42501';
  end if;

  if p_soft_target is null or p_soft_target <= 0 then
    raise exception 'invalid soft target' using errcode = '22000';
  end if;
  if p_hard_safety_limit is not null and p_hard_safety_limit < p_soft_target then
    raise exception 'hard safety limit cannot be less than soft target' using errcode = '22000';
  end if;

  insert into app_private.sites (
    organization_id,
    occurrence_id,
    name,
    public_location,
    approximate_latitude,
    approximate_longitude,
    precise_address,
    precise_latitude,
    precise_longitude,
    accessibility,
    arrival_notes,
    soft_target,
    hard_safety_limit
  )
  values (
    p_organization_id,
    p_occurrence_id,
    trim(p_name),
    trim(p_public_location),
    p_approx_lat,
    p_approx_lng,
    p_precise_address,
    p_precise_lat,
    p_precise_lng,
    coalesce(p_accessibility, array[]::text[]),
    coalesce(p_arrival_notes, ''),
    p_soft_target,
    p_hard_safety_limit
  )
  returning id into v_site_id;

  return v_site_id;
end
$function$;

alter function api_v1.cmd_create_site(
  uuid, uuid, text, text, double precision, double precision, text, double precision, double precision, text[], text, int, int
) owner to dos_event_command;

create or replace function api_v1.cmd_publish_occurrence(
  p_organization_id uuid,
  p_occurrence_id uuid,
  p_expected_version bigint
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_current_version bigint;
  v_state text;
  v_site_count int;
begin
  if not policy.has_org_role(p_organization_id, array['org_owner', 'organizer']) then
    raise exception 'organizer permission required' using errcode = '42501';
  end if;

  select version, state into v_current_version, v_state
  from app_private.occurrences
  where id = p_occurrence_id and organization_id = p_organization_id
  for update;

  if not found then
    raise exception 'occurrence not found' using errcode = 'P0002';
  end if;

  if v_current_version <> p_expected_version then
    raise exception 'version conflict' using errcode = 'P0002';
  end if;

  if v_state <> 'draft' then
    raise exception 'only draft occurrences may be published' using errcode = '23514';
  end if;

  select count(*) into v_site_count
  from app_private.sites
  where occurrence_id = p_occurrence_id;

  if v_site_count = 0 then
    raise exception 'cannot publish occurrence with zero sites' using errcode = '23514';
  end if;

  update app_private.occurrences
  set
    state = 'published',
    published_at = transaction_timestamp(),
    version = version + 1,
    updated_at = transaction_timestamp()
  where id = p_occurrence_id;

  return true;
end
$function$;

alter function api_v1.cmd_publish_occurrence(uuid, uuid, bigint) owner to dos_event_command;

create or replace function api_v1.cmd_archive_occurrence(
  p_organization_id uuid,
  p_occurrence_id uuid,
  p_expected_version bigint
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_current_version bigint;
begin
  if not policy.has_org_role(p_organization_id, array['org_owner', 'organizer']) then
    raise exception 'organizer permission required' using errcode = '42501';
  end if;

  select version into v_current_version
  from app_private.occurrences
  where id = p_occurrence_id and organization_id = p_organization_id
  for update;

  if not found then
    raise exception 'occurrence not found' using errcode = 'P0002';
  end if;

  if v_current_version <> p_expected_version then
    raise exception 'version conflict' using errcode = 'P0002';
  end if;

  update app_private.occurrences
  set
    state = 'archived',
    version = version + 1,
    updated_at = transaction_timestamp()
  where id = p_occurrence_id;

  return true;
end
$function$;

alter function api_v1.cmd_archive_occurrence(uuid, uuid, bigint) owner to dos_event_command;

-- ============================================================================
-- Grants
-- ============================================================================

grant select on api_v1.public_occurrences to public, anon, authenticated;
grant select on api_v1.organizer_occurrences to dos_event_query;
grant execute on function api_v1.cmd_create_program(uuid, text, text),
  api_v1.cmd_create_occurrence(uuid, uuid, text, text, timestamptz, timestamptz, text),
  api_v1.cmd_create_site(uuid, uuid, text, text, double precision, double precision, text, double precision, double precision, text[], text, int, int),
  api_v1.cmd_publish_occurrence(uuid, uuid, bigint),
  api_v1.cmd_archive_occurrence(uuid, uuid, bigint) to dos_event_command;

revoke all on all tables in schema app_private from public;

commit;
