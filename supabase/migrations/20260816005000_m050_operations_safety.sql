begin;

-- ============================================================================
-- Roles for Operations & Safety Domain
-- ============================================================================

do $roles$
declare
  role_name text;
begin
  foreach role_name in array array[
    'dos_ops_query',
    'dos_ops_command'
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

grant usage on schema app_private, api_v1, policy to dos_ops_query, dos_ops_command;

-- ============================================================================
-- Tables in app_private
-- ============================================================================

create table app_private.attendance_operations (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references app_private.organizations(id) on delete cascade,
  occurrence_id uuid not null references app_private.occurrences(id) on delete cascade,
  site_id uuid not null references app_private.sites(id) on delete cascade,
  registration_id uuid not null references app_private.registrations(id) on delete cascade,
  kind text not null check (kind in ('check_in', 'check_out')),
  occurred_at timestamptz not null default transaction_timestamp(),
  recorded_by_profile_id uuid not null references app_private.profiles(id) on delete cascade,
  created_at timestamptz not null default transaction_timestamp(),
  unique (organization_id, id)
);

create table app_private.announcements (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references app_private.organizations(id) on delete cascade,
  occurrence_id uuid not null references app_private.occurrences(id) on delete cascade,
  audience_type text not null check (
    audience_type in ('all_participants', 'site_specific', 'site_leads_only')
  ),
  site_id uuid references app_private.sites(id) on delete cascade,
  title text not null check (length(title) between 1 and 200),
  body text not null check (length(body) between 1 and 4000),
  author_profile_id uuid not null references app_private.profiles(id) on delete cascade,
  created_at timestamptz not null default transaction_timestamp(),
  unique (organization_id, id),
  check (
    (audience_type = 'site_specific' and site_id is not null) or
    (audience_type in ('all_participants', 'site_leads_only'))
  )
);

create table app_private.incidents (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references app_private.organizations(id) on delete cascade,
  occurrence_id uuid not null references app_private.occurrences(id) on delete cascade,
  site_id uuid references app_private.sites(id) on delete set null,
  severity text not null check (severity in ('low', 'medium', 'high', 'critical')),
  summary text not null check (length(summary) between 1 and 500),
  details text not null,
  reporter_profile_id uuid not null references app_private.profiles(id) on delete cascade,
  state text not null default 'open' check (
    state in ('open', 'investigating', 'resolved', 'closed')
  ),
  created_at timestamptz not null default transaction_timestamp(),
  updated_at timestamptz not null default transaction_timestamp(),
  unique (organization_id, id)
);

create table app_private.safety_shares (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references app_private.organizations(id) on delete cascade,
  occurrence_id uuid not null references app_private.occurrences(id) on delete cascade,
  site_id uuid not null references app_private.sites(id) on delete cascade,
  participant_profile_id uuid not null references app_private.profiles(id) on delete cascade,
  recipient_ids uuid[] not null check (
    array_length(recipient_ids, 1) between 1 and 5
  ),
  expires_at timestamptz not null check (expires_at > created_at),
  stopped_at timestamptz,
  created_at timestamptz not null default transaction_timestamp(),
  unique (organization_id, id)
);

-- ============================================================================
-- Enable and Force RLS
-- ============================================================================

do $rls$
declare
  table_name text;
begin
  foreach table_name in array array[
    'attendance_operations', 'announcements', 'incidents', 'safety_shares'
  ] loop
    execute format('alter table app_private.%I enable row level security', table_name);
    execute format('alter table app_private.%I force row level security', table_name);
  end loop;
end
$rls$;

create policy actor_select_attendance on app_private.attendance_operations
  for select to dos_ops_query
  using (
    recorded_by_profile_id = policy.actor_profile_id()
    or policy.has_org_role(organization_id, array['org_owner', 'organizer', 'site_lead'])
  );

create policy actor_all_attendance on app_private.attendance_operations
  for all to dos_ops_command
  using (
    recorded_by_profile_id = policy.actor_profile_id()
    or policy.has_org_role(organization_id, array['org_owner', 'organizer', 'site_lead'])
  )
  with check (
    recorded_by_profile_id = policy.actor_profile_id()
    or policy.has_org_role(organization_id, array['org_owner', 'organizer', 'site_lead'])
  );

create policy actor_select_announcements on app_private.announcements
  for select to dos_ops_query
  using (
    policy.has_org_role(organization_id, array['org_owner', 'organizer'])
    or (
      audience_type = 'all_participants'
      and exists (
        select 1 from app_private.registrations as r
        where r.occurrence_id = announcements.occurrence_id
          and r.registrant_profile_id = policy.actor_profile_id()
          and r.state in ('submitted', 'assigned')
      )
    )
    or (
      audience_type = 'site_specific'
      and exists (
        select 1 from app_private.registrations as r
        where r.occurrence_id = announcements.occurrence_id
          and r.site_id = announcements.site_id
          and r.registrant_profile_id = policy.actor_profile_id()
          and r.state = 'assigned'
      )
    )
    or (
      audience_type = 'site_leads_only'
      and policy.has_org_role(organization_id, array['site_lead'])
    )
  );

create policy organizer_all_announcements on app_private.announcements
  for all to dos_ops_command
  using (policy.has_org_role(organization_id, array['org_owner', 'organizer']))
  with check (policy.has_org_role(organization_id, array['org_owner', 'organizer']));

create policy organizer_select_incidents on app_private.incidents
  for select to dos_ops_query
  using (
    reporter_profile_id = policy.actor_profile_id()
    or policy.has_org_role(organization_id, array['org_owner', 'organizer', 'site_lead'])
  );

create policy actor_all_incidents on app_private.incidents
  for all to dos_ops_command
  using (
    reporter_profile_id = policy.actor_profile_id()
    or policy.has_org_role(organization_id, array['org_owner', 'organizer', 'site_lead'])
  )
  with check (
    reporter_profile_id = policy.actor_profile_id()
    or policy.has_org_role(organization_id, array['org_owner', 'organizer', 'site_lead'])
  );

create policy actor_select_safety_shares on app_private.safety_shares
  for select to dos_ops_query
  using (
    participant_profile_id = policy.actor_profile_id()
    or policy.actor_profile_id() = any(recipient_ids)
    or policy.has_org_role(organization_id, array['org_owner', 'organizer'])
  );

create policy actor_all_safety_shares on app_private.safety_shares
  for all to dos_ops_command
  using (participant_profile_id = policy.actor_profile_id())
  with check (participant_profile_id = policy.actor_profile_id());

-- ============================================================================
-- Views in api_v1
-- ============================================================================

create or replace view api_v1.event_announcements with (security_barrier = true) as
select
  a.id,
  a.organization_id,
  a.occurrence_id,
  a.audience_type,
  a.site_id,
  a.title,
  a.body,
  a.created_at
from app_private.announcements as a;

alter view api_v1.event_announcements owner to dos_ops_query;

create or replace view api_v1.active_safety_shares with (security_barrier = true) as
select
  ss.id,
  ss.organization_id,
  ss.occurrence_id,
  ss.site_id,
  ss.participant_profile_id,
  ss.recipient_ids,
  ss.expires_at,
  ss.created_at
from app_private.safety_shares as ss
where ss.stopped_at is null
  and ss.expires_at > transaction_timestamp();

alter view api_v1.active_safety_shares owner to dos_ops_query;

-- ============================================================================
-- Command functions in api_v1
-- ============================================================================

create or replace function api_v1.cmd_record_attendance(
  p_organization_id uuid,
  p_occurrence_id uuid,
  p_site_id uuid,
  p_registration_id uuid,
  p_kind text,
  p_occurred_at timestamptz default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_profile_id uuid;
  v_attendance_id uuid;
begin
  v_profile_id := policy.actor_profile_id();
  if v_profile_id is null then
    raise exception 'authenticated active profile required' using errcode = '42501';
  end if;

  if p_kind not in ('check_in', 'check_out') then
    raise exception 'invalid attendance operation kind' using errcode = '22000';
  end if;

  insert into app_private.attendance_operations (
    organization_id,
    occurrence_id,
    site_id,
    registration_id,
    kind,
    occurred_at,
    recorded_by_profile_id
  )
  values (
    p_organization_id,
    p_occurrence_id,
    p_site_id,
    p_registration_id,
    p_kind,
    coalesce(p_occurred_at, transaction_timestamp()),
    v_profile_id
  )
  returning id into v_attendance_id;

  return v_attendance_id;
end
$function$;

alter function api_v1.cmd_record_attendance(uuid, uuid, uuid, uuid, text, timestamptz)
  owner to dos_ops_command;

create or replace function api_v1.cmd_publish_announcement(
  p_organization_id uuid,
  p_occurrence_id uuid,
  p_audience_type text,
  p_site_id uuid,
  p_title text,
  p_body text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_author_id uuid;
  v_announcement_id uuid;
begin
  v_author_id := policy.actor_profile_id();
  if v_author_id is null then
    raise exception 'authenticated active profile required' using errcode = '42501';
  end if;

  if not policy.has_org_role(p_organization_id, array['org_owner', 'organizer']) then
    raise exception 'organizer permission required to publish announcements' using errcode = '42501';
  end if;

  if p_title is null or length(trim(p_title)) = 0 or length(p_title) > 200 then
    raise exception 'invalid announcement title' using errcode = '22000';
  end if;
  if p_body is null or length(trim(p_body)) = 0 or length(p_body) > 4000 then
    raise exception 'invalid announcement body' using errcode = '22000';
  end if;

  insert into app_private.announcements (
    organization_id,
    occurrence_id,
    audience_type,
    site_id,
    title,
    body,
    author_profile_id
  )
  values (
    p_organization_id,
    p_occurrence_id,
    p_audience_type,
    p_site_id,
    trim(p_title),
    trim(p_body),
    v_author_id
  )
  returning id into v_announcement_id;

  return v_announcement_id;
end
$function$;

alter function api_v1.cmd_publish_announcement(uuid, uuid, text, uuid, text, text)
  owner to dos_ops_command;

create or replace function api_v1.cmd_report_incident(
  p_organization_id uuid,
  p_occurrence_id uuid,
  p_site_id uuid,
  p_severity text,
  p_summary text,
  p_details text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_reporter_id uuid;
  v_incident_id uuid;
begin
  v_reporter_id := policy.actor_profile_id();
  if v_reporter_id is null then
    raise exception 'authenticated active profile required' using errcode = '42501';
  end if;

  if p_severity not in ('low', 'medium', 'high', 'critical') then
    raise exception 'invalid severity level' using errcode = '22000';
  end if;

  if p_summary is null or length(trim(p_summary)) = 0 or length(p_summary) > 500 then
    raise exception 'invalid incident summary' using errcode = '22000';
  end if;

  insert into app_private.incidents (
    organization_id,
    occurrence_id,
    site_id,
    severity,
    summary,
    details,
    reporter_profile_id,
    state
  )
  values (
    p_organization_id,
    p_occurrence_id,
    p_site_id,
    p_severity,
    trim(p_summary),
    trim(coalesce(p_details, '')),
    v_reporter_id,
    'open'
  )
  returning id into v_incident_id;

  return v_incident_id;
end
$function$;

alter function api_v1.cmd_report_incident(uuid, uuid, uuid, text, text, text)
  owner to dos_ops_command;

create or replace function api_v1.cmd_start_safety_share(
  p_organization_id uuid,
  p_occurrence_id uuid,
  p_site_id uuid,
  p_recipient_ids uuid[],
  p_duration_minutes int default 240
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_participant_id uuid;
  v_share_id uuid;
  v_expires_at timestamptz;
  v_duration int;
begin
  v_participant_id := policy.actor_profile_id();
  if v_participant_id is null then
    raise exception 'authenticated active profile required' using errcode = '42501';
  end if;

  if not policy.actor_is_adult() then
    raise exception 'safety sharing requires verified adult assurance' using errcode = '42501';
  end if;

  if p_recipient_ids is null or array_length(p_recipient_ids, 1) = 0 or array_length(p_recipient_ids, 1) > 5 then
    raise exception 'safety sharing requires between 1 and 5 recipients' using errcode = '22000';
  end if;

  v_duration := coalesce(p_duration_minutes, 240);
  if v_duration <= 0 or v_duration > 720 then
    raise exception 'safety sharing duration must be between 1 and 720 minutes' using errcode = '22000';
  end if;

  v_expires_at := transaction_timestamp() + (v_duration || ' minutes')::interval;

  insert into app_private.safety_shares (
    organization_id,
    occurrence_id,
    site_id,
    participant_profile_id,
    recipient_ids,
    expires_at
  )
  values (
    p_organization_id,
    p_occurrence_id,
    p_site_id,
    v_participant_id,
    p_recipient_ids,
    v_expires_at
  )
  returning id into v_share_id;

  return v_share_id;
end
$function$;

alter function api_v1.cmd_start_safety_share(uuid, uuid, uuid, uuid[], int)
  owner to dos_ops_command;

create or replace function api_v1.cmd_stop_safety_share(
  p_safety_share_id uuid
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_participant_id uuid;
begin
  v_participant_id := policy.actor_profile_id();
  if v_participant_id is null then
    raise exception 'authenticated active profile required' using errcode = '42501';
  end if;

  update app_private.safety_shares
  set stopped_at = transaction_timestamp()
  where id = p_safety_share_id
    and participant_profile_id = v_participant_id
    and stopped_at is null;

  if not found then
    raise exception 'active safety share not found' using errcode = 'P0002';
  end if;

  return true;
end
$function$;

alter function api_v1.cmd_stop_safety_share(uuid)
  owner to dos_ops_command;

-- ============================================================================
-- Grants
-- ============================================================================

grant select on api_v1.event_announcements, api_v1.active_safety_shares to dos_ops_query;
grant execute on function api_v1.cmd_record_attendance(uuid, uuid, uuid, uuid, text, timestamptz),
  api_v1.cmd_publish_announcement(uuid, uuid, text, uuid, text, text),
  api_v1.cmd_report_incident(uuid, uuid, uuid, text, text, text),
  api_v1.cmd_start_safety_share(uuid, uuid, uuid, uuid[], int),
  api_v1.cmd_stop_safety_share(uuid) to dos_ops_command;

revoke all on all tables in schema app_private from public;

commit;
