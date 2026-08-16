begin;

-- ============================================================================
-- Roles for Registration & Consent Domain
-- ============================================================================

do $roles$
declare
  role_name text;
begin
  foreach role_name in array array[
    'dos_registration_query',
    'dos_registration_command'
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

grant usage on schema app_private, api_v1, policy to dos_registration_query, dos_registration_command;

-- ============================================================================
-- Tables in app_private
-- ============================================================================

create table app_private.dependents (
  id uuid primary key default extensions.gen_random_uuid(),
  guardian_profile_id uuid not null references app_private.profiles(id) on delete cascade,
  display_name text not null check (length(display_name) between 1 and 120),
  media_visibility text not null default 'event_feed_only' check (
    media_visibility in ('hidden', 'event_feed_only', 'public_gallery_eligible')
  ),
  created_at timestamptz not null default transaction_timestamp(),
  updated_at timestamptz not null default transaction_timestamp()
);

create table app_private.legal_documents (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid references app_private.organizations(id) on delete cascade,
  title text not null check (length(title) between 1 and 200),
  body_markdown text not null,
  kind text not null check (
    kind in ('volunteer_waiver', 'guardian_consent', 'media_release', 'privacy_notice')
  ),
  version int not null default 1,
  effective_at timestamptz not null default transaction_timestamp(),
  created_at timestamptz not null default transaction_timestamp()
);

create table app_private.consent_records (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid references app_private.organizations(id) on delete set null,
  document_id uuid not null references app_private.legal_documents(id) on delete cascade,
  signer_profile_id uuid not null references app_private.profiles(id) on delete cascade,
  subject_profile_id uuid references app_private.profiles(id) on delete cascade,
  subject_dependent_id uuid references app_private.dependents(id) on delete cascade,
  signature_representation text not null,
  signed_at timestamptz not null default transaction_timestamp(),
  check (
    (subject_profile_id is not null and subject_dependent_id is null) or
    (subject_profile_id is null and subject_dependent_id is not null)
  )
);

create table app_private.registrations (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references app_private.organizations(id) on delete cascade,
  occurrence_id uuid not null references app_private.occurrences(id) on delete cascade,
  registrant_profile_id uuid not null references app_private.profiles(id) on delete cascade,
  site_id uuid references app_private.sites(id) on delete set null,
  team_mode text not null default 'individual' check (
    team_mode in ('individual', 'prefer_together', 'must_stay_together')
  ),
  state text not null default 'submitted' check (
    state in ('draft', 'submitted', 'waitlisted', 'assigned', 'cancelled')
  ),
  accommodations text,
  version bigint not null default 1,
  created_at timestamptz not null default transaction_timestamp(),
  updated_at timestamptz not null default transaction_timestamp(),
  unique (organization_id, id)
);

create table app_private.registration_participants (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references app_private.organizations(id) on delete cascade,
  registration_id uuid not null references app_private.registrations(id) on delete cascade,
  profile_id uuid references app_private.profiles(id) on delete cascade,
  dependent_id uuid references app_private.dependents(id) on delete cascade,
  participant_name text not null check (length(participant_name) between 1 and 120),
  created_at timestamptz not null default transaction_timestamp(),
  unique (registration_id, id),
  check (
    (profile_id is not null and dependent_id is null) or
    (profile_id is null and dependent_id is not null) or
    (profile_id is null and dependent_id is null)
  )
);

-- ============================================================================
-- Enable and Force RLS
-- ============================================================================

do $rls$
declare
  table_name text;
begin
  foreach table_name in array array[
    'dependents', 'legal_documents', 'consent_records',
    'registrations', 'registration_participants'
  ] loop
    execute format('alter table app_private.%I enable row level security', table_name);
    execute format('alter table app_private.%I force row level security', table_name);
  end loop;
end
$rls$;

create policy actor_select_dependents on app_private.dependents
  for select to dos_registration_query
  using (guardian_profile_id = policy.actor_profile_id());

create policy actor_all_dependents on app_private.dependents
  for all to dos_registration_command
  using (guardian_profile_id = policy.actor_profile_id())
  with check (guardian_profile_id = policy.actor_profile_id());

create policy public_select_legal_documents on app_private.legal_documents
  for select to dos_registration_query
  using (true);

create policy actor_select_consent_records on app_private.consent_records
  for select to dos_registration_query
  using (
    signer_profile_id = policy.actor_profile_id()
    or policy.has_org_role(organization_id, array['org_owner', 'organizer'])
  );

create policy actor_all_consent_records on app_private.consent_records
  for all to dos_registration_command
  using (signer_profile_id = policy.actor_profile_id())
  with check (signer_profile_id = policy.actor_profile_id());

create policy actor_select_registrations on app_private.registrations
  for select to dos_registration_query
  using (
    registrant_profile_id = policy.actor_profile_id()
    or policy.has_org_role(organization_id, array['org_owner', 'organizer'])
  );

create policy actor_all_registrations on app_private.registrations
  for all to dos_registration_command
  using (
    registrant_profile_id = policy.actor_profile_id()
    or policy.has_org_role(organization_id, array['org_owner', 'organizer'])
  )
  with check (
    registrant_profile_id = policy.actor_profile_id()
    or policy.has_org_role(organization_id, array['org_owner', 'organizer'])
  );

create policy actor_select_registration_participants on app_private.registration_participants
  for select to dos_registration_query
  using (
    exists (
      select 1 from app_private.registrations as r
      where r.id = registration_id
        and (
          r.registrant_profile_id = policy.actor_profile_id()
          or policy.has_org_role(r.organization_id, array['org_owner', 'organizer'])
        )
    )
  );

create policy actor_all_registration_participants on app_private.registration_participants
  for all to dos_registration_command
  using (
    exists (
      select 1 from app_private.registrations as r
      where r.id = registration_id
        and (
          r.registrant_profile_id = policy.actor_profile_id()
          or policy.has_org_role(r.organization_id, array['org_owner', 'organizer'])
        )
    )
  )
  with check (
    exists (
      select 1 from app_private.registrations as r
      where r.id = registration_id
        and (
          r.registrant_profile_id = policy.actor_profile_id()
          or policy.has_org_role(r.organization_id, array['org_owner', 'organizer'])
        )
    )
  );

-- ============================================================================
-- Views in api_v1
-- ============================================================================

create or replace view api_v1.my_dependents with (security_barrier = true) as
select
  d.id,
  d.display_name,
  d.media_visibility,
  d.created_at,
  d.updated_at
from app_private.dependents as d
where d.guardian_profile_id = policy.actor_profile_id();

alter view api_v1.my_dependents owner to dos_registration_query;

create or replace view api_v1.public_legal_documents with (security_barrier = true) as
select
  ld.id,
  ld.organization_id,
  ld.title,
  ld.body_markdown,
  ld.kind,
  ld.version,
  ld.effective_at
from app_private.legal_documents as ld;

alter view api_v1.public_legal_documents owner to dos_registration_query;

create or replace view api_v1.my_registrations with (security_barrier = true) as
select
  r.id,
  r.organization_id,
  r.occurrence_id,
  r.site_id,
  r.team_mode,
  r.state,
  r.accommodations,
  r.version,
  r.created_at,
  r.updated_at
from app_private.registrations as r
where r.registrant_profile_id = policy.actor_profile_id();

alter view api_v1.my_registrations owner to dos_registration_query;

-- ============================================================================
-- Command functions in api_v1
-- ============================================================================

create or replace function api_v1.cmd_create_dependent(
  p_display_name text,
  p_media_visibility text default 'event_feed_only'
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_guardian_id uuid;
  v_dependent_id uuid;
begin
  v_guardian_id := policy.actor_profile_id();
  if v_guardian_id is null then
    raise exception 'authenticated active profile required' using errcode = '42501';
  end if;

  if not policy.actor_is_adult() then
    raise exception 'guardian must be verified adult' using errcode = '42501';
  end if;

  if p_display_name is null or length(trim(p_display_name)) = 0 or length(p_display_name) > 120 then
    raise exception 'invalid dependent name' using errcode = '22000';
  end if;

  if p_media_visibility not in ('hidden', 'event_feed_only', 'public_gallery_eligible') then
    raise exception 'invalid media visibility' using errcode = '22000';
  end if;

  insert into app_private.dependents (
    guardian_profile_id,
    display_name,
    media_visibility
  )
  values (
    v_guardian_id,
    trim(p_display_name),
    p_media_visibility
  )
  returning id into v_dependent_id;

  return v_dependent_id;
end
$function$;

alter function api_v1.cmd_create_dependent(text, text) owner to dos_registration_command;

create or replace function api_v1.cmd_record_consent(
  p_organization_id uuid,
  p_document_id uuid,
  p_subject_profile_id uuid,
  p_subject_dependent_id uuid,
  p_signature text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_signer_id uuid;
  v_consent_id uuid;
begin
  v_signer_id := policy.actor_profile_id();
  if v_signer_id is null then
    raise exception 'authenticated active profile required' using errcode = '42501';
  end if;

  if p_subject_dependent_id is not null then
    if not exists (
      select 1 from app_private.dependents
      where id = p_subject_dependent_id and guardian_profile_id = v_signer_id
    ) then
      raise exception 'signer is not the guardian of this dependent' using errcode = '42501';
    end if;
  end if;

  if p_signature is null or length(trim(p_signature)) = 0 then
    raise exception 'signature representation required' using errcode = '22000';
  end if;

  insert into app_private.consent_records (
    organization_id,
    document_id,
    signer_profile_id,
    subject_profile_id,
    subject_dependent_id,
    signature_representation
  )
  values (
    p_organization_id,
    p_document_id,
    v_signer_id,
    p_subject_profile_id,
    p_subject_dependent_id,
    trim(p_signature)
  )
  returning id into v_consent_id;

  return v_consent_id;
end
$function$;

alter function api_v1.cmd_record_consent(uuid, uuid, uuid, uuid, text) owner to dos_registration_command;

create or replace function api_v1.cmd_submit_registration(
  p_occurrence_id uuid,
  p_site_id uuid,
  p_participant_names text[],
  p_team_mode text,
  p_accommodations text,
  p_accepted_document_ids uuid[]
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_profile_id uuid;
  v_org_id uuid;
  v_occ_state text;
  v_site record;
  v_registration_id uuid;
  v_candidate_count int;
  v_current_count int;
  v_assigned_state text;
  v_name text;
begin
  v_profile_id := policy.actor_profile_id();
  if v_profile_id is null then
    raise exception 'authenticated active profile required' using errcode = '42501';
  end if;

  select organization_id, state into v_org_id, v_occ_state
  from app_private.occurrences
  where id = p_occurrence_id;

  if not found then
    raise exception 'occurrence not found' using errcode = 'P0002';
  end if;

  if v_occ_state <> 'published' then
    raise exception 'occurrence is not open for registration' using errcode = '23514';
  end if;

  if p_participant_names is null or array_length(p_participant_names, 1) = 0 then
    raise exception 'at least one participant is required' using errcode = '22000';
  end if;

  v_candidate_count := array_length(p_participant_names, 1);
  v_assigned_state := 'submitted';

  -- If a site is chosen, check capacity atomicity
  if p_site_id is not null then
    select * into v_site
    from app_private.sites
    where id = p_site_id and occurrence_id = p_occurrence_id
    for update;

    if not found then
      raise exception 'site not found for this occurrence' using errcode = 'P0002';
    end if;

    if v_site.hard_safety_limit is not null then
      select count(*) into v_current_count
      from app_private.registration_participants as rp
      join app_private.registrations as r on r.id = rp.registration_id
      where r.site_id = p_site_id
        and r.state in ('submitted', 'assigned');

      if (v_current_count + v_candidate_count) > v_site.hard_safety_limit then
        v_assigned_state := 'waitlisted';
      else
        v_assigned_state := 'assigned';
      end if;
    else
      v_assigned_state := 'assigned';
    end if;
  end if;

  insert into app_private.registrations (
    organization_id,
    occurrence_id,
    registrant_profile_id,
    site_id,
    team_mode,
    state,
    accommodations
  )
  values (
    v_org_id,
    p_occurrence_id,
    v_profile_id,
    p_site_id,
    coalesce(p_team_mode, 'individual'),
    v_assigned_state,
    p_accommodations
  )
  returning id into v_registration_id;

  foreach v_name in array p_participant_names loop
    insert into app_private.registration_participants (
      organization_id,
      registration_id,
      participant_name
    )
    values (
      v_org_id,
      v_registration_id,
      trim(v_name)
    );
  end loop;

  return v_registration_id;
end
$function$;

alter function api_v1.cmd_submit_registration(uuid, uuid, text[], text, text, uuid[])
  owner to dos_registration_command;

create or replace function api_v1.cmd_cancel_registration(
  p_registration_id uuid,
  p_expected_version bigint
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_profile_id uuid;
  v_current_version bigint;
  v_current_state text;
begin
  v_profile_id := policy.actor_profile_id();
  if v_profile_id is null then
    raise exception 'authenticated active profile required' using errcode = '42501';
  end if;

  select version, state into v_current_version, v_current_state
  from app_private.registrations
  where id = p_registration_id
    and registrant_profile_id = v_profile_id
  for update;

  if not found then
    raise exception 'registration not found' using errcode = 'P0002';
  end if;

  if v_current_version <> p_expected_version then
    raise exception 'version conflict' using errcode = 'P0002';
  end if;

  if v_current_state = 'cancelled' then
    raise exception 'registration is already cancelled' using errcode = '23514';
  end if;

  update app_private.registrations
  set
    state = 'cancelled',
    version = version + 1,
    updated_at = transaction_timestamp()
  where id = p_registration_id;

  return true;
end
$function$;

alter function api_v1.cmd_cancel_registration(uuid, bigint)
  owner to dos_registration_command;

-- ============================================================================
-- Grants
-- ============================================================================

grant select on api_v1.public_legal_documents to public, anon, authenticated;
grant select on api_v1.my_dependents, api_v1.my_registrations to dos_registration_query;
grant execute on function api_v1.cmd_create_dependent(text, text),
  api_v1.cmd_record_consent(uuid, uuid, uuid, uuid, text),
  api_v1.cmd_submit_registration(uuid, uuid, text[], text, text, uuid[]),
  api_v1.cmd_cancel_registration(uuid, bigint) to dos_registration_command;

revoke all on all tables in schema app_private from public;

commit;
