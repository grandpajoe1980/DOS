begin;

-- ============================================================================
-- Tables in ops_private
-- ============================================================================

create table ops_private.idempotency_records (
  id uuid primary key default extensions.gen_random_uuid(),
  principal_type text not null check (
    principal_type in ('authenticated_profile', 'pseudonymous_rate_limit', 'system')
  ),
  principal_id text not null,
  operation_id text not null check (length(operation_id) between 1 and 120),
  idempotency_key text not null check (length(idempotency_key) between 1 and 120),
  request_payload_hmac bytea not null check (octet_length(request_payload_hmac) = 32),
  status text not null default 'in_progress' check (
    status in ('in_progress', 'committed', 'conflicted', 'failed')
  ),
  response_status integer check (response_status between 100 and 599),
  response_body jsonb,
  created_at timestamptz not null default transaction_timestamp(),
  expires_at timestamptz not null,
  unique (principal_type, principal_id, operation_id, idempotency_key)
);

create table ops_private.audit_events (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid references app_private.organizations(id) on delete set null,
  actor_profile_id uuid references app_private.profiles(id) on delete set null,
  action text not null check (length(action) between 1 and 120),
  target_type text not null check (length(target_type) between 1 and 80),
  target_id uuid,
  request_id text check (request_id is null or length(request_id) between 1 and 120),
  reason_code text check (reason_code is null or length(reason_code) between 1 and 80),
  recorded_at timestamptz not null default transaction_timestamp()
);

create table ops_private.outbox_events (
  id uuid primary key default extensions.gen_random_uuid(),
  topic text not null check (length(topic) between 1 and 80),
  event_key text not null check (length(event_key) between 1 and 200),
  payload jsonb not null,
  state text not null default 'pending' check (
    state in ('pending', 'processing', 'delivered', 'dead_letter')
  ),
  created_at timestamptz not null default transaction_timestamp(),
  unique (topic, event_key)
);

create table ops_private.outbox_deliveries (
  id uuid primary key default extensions.gen_random_uuid(),
  outbox_event_id uuid not null references ops_private.outbox_events(id) on delete cascade,
  worker_identity text not null check (length(worker_identity) between 1 and 80),
  status text not null check (status in ('succeeded', 'retrying', 'failed')),
  attempt_count integer not null default 1 check (attempt_count > 0),
  last_error text,
  attempted_at timestamptz not null default transaction_timestamp()
);

create table ops_private.support_grants (
  id uuid primary key default extensions.gen_random_uuid(),
  platform_identity text not null check (length(platform_identity) between 1 and 120),
  scope_type text not null check (
    scope_type in ('organization', 'occurrence', 'incident', 'system')
  ),
  scope_id uuid,
  capability text not null check (length(capability) between 1 and 80),
  ticket_reference text not null check (length(ticket_reference) between 1 and 120),
  granted_at timestamptz not null default transaction_timestamp(),
  expires_at timestamptz not null check (expires_at > granted_at),
  revoked_at timestamptz check (revoked_at is null or revoked_at >= granted_at)
);

-- ============================================================================
-- Enable and Force RLS
-- ============================================================================

do $rls$
declare
  table_name text;
begin
  foreach table_name in array array[
    'idempotency_records', 'audit_events', 'outbox_events',
    'outbox_deliveries', 'support_grants'
  ] loop
    execute format('alter table ops_private.%I enable row level security', table_name);
    execute format('alter table ops_private.%I force row level security', table_name);
    execute format(
      'create policy dos_policy_ops on ops_private.%I for all to dos_control_command using (true) with check (true)',
      table_name
    );
  end loop;
end
$rls$;

create policy outbox_worker_select on ops_private.outbox_events
  for select to dos_outbox_worker using (true);
create policy outbox_worker_update on ops_private.outbox_events
  for update to dos_outbox_worker using (true) with check (true);
create policy outbox_worker_deliveries on ops_private.outbox_deliveries
  for all to dos_outbox_worker using (true) with check (true);

-- ============================================================================
-- Functions in policy & ops_private
-- ============================================================================

create or replace function policy.has_support_grant(
  p_scope_type text,
  p_scope_id uuid,
  p_capability text
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $function$
  select coalesce(exists (
    select 1
    from ops_private.support_grants as g
    where g.platform_identity = coalesce(pg_catalog.current_setting('request.jwt.claim.email', true), '')
      and g.scope_type = p_scope_type
      and (g.scope_id is null or g.scope_id = p_scope_id)
      and g.capability = p_capability
      and g.granted_at <= transaction_timestamp()
      and g.expires_at > transaction_timestamp()
      and g.revoked_at is null
  ), false)
$function$;

alter function policy.has_support_grant(text, uuid, text) owner to dos_policy;

create or replace function ops_private.claim_idempotency(
  p_principal_type text,
  p_principal_id text,
  p_operation_id text,
  p_idempotency_key text,
  p_request_payload_hmac bytea,
  p_ttl_seconds integer default 86400
)
returns table (
  record_id uuid,
  is_first_claim boolean,
  current_status text,
  cached_response_status integer,
  cached_response_body jsonb
)
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_existing ops_private.idempotency_records%rowtype;
  v_new_id uuid;
  v_expires_at timestamptz;
begin
  v_expires_at := transaction_timestamp() + (p_ttl_seconds || ' seconds')::interval;

  select * into v_existing
  from ops_private.idempotency_records
  where principal_type = p_principal_type
    and principal_id = p_principal_id
    and operation_id = p_operation_id
    and idempotency_key = p_idempotency_key
  for update;

  if found then
    if v_existing.request_payload_hmac <> p_request_payload_hmac then
      return query select
        v_existing.id,
        false,
        'conflicted'::text,
        409::integer,
        null::jsonb;
      return;
    end if;

    return query select
      v_existing.id,
      false,
      v_existing.status,
      v_existing.response_status,
      v_existing.response_body;
    return;
  end if;

  insert into ops_private.idempotency_records (
    principal_type,
    principal_id,
    operation_id,
    idempotency_key,
    request_payload_hmac,
    status,
    expires_at
  )
  values (
    p_principal_type,
    p_principal_id,
    p_operation_id,
    p_idempotency_key,
    p_request_payload_hmac,
    'in_progress',
    v_expires_at
  )
  returning id into v_new_id;

  return query select
    v_new_id,
    true,
    'in_progress'::text,
    null::integer,
    null::jsonb;
end
$function$;

alter function ops_private.claim_idempotency(text, text, text, text, bytea, integer)
  owner to dos_control_command;

create or replace function ops_private.complete_idempotency(
  p_idempotency_record_id uuid,
  p_response_status integer,
  p_response_body jsonb
)
returns void
language plpgsql
security definer
set search_path = ''
as $function$
begin
  update ops_private.idempotency_records
  set
    status = 'committed',
    response_status = p_response_status,
    response_body = p_response_body
  where id = p_idempotency_record_id;
end
$function$;

alter function ops_private.complete_idempotency(uuid, integer, jsonb)
  owner to dos_control_command;

create or replace function ops_private.record_audit_event(
  p_organization_id uuid,
  p_actor_profile_id uuid,
  p_action text,
  p_target_type text,
  p_target_id uuid,
  p_request_id text default null,
  p_reason_code text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_audit_id uuid;
begin
  insert into ops_private.audit_events (
    organization_id,
    actor_profile_id,
    action,
    target_type,
    target_id,
    request_id,
    reason_code
  )
  values (
    p_organization_id,
    p_actor_profile_id,
    p_action,
    p_target_type,
    p_target_id,
    p_request_id,
    p_reason_code
  )
  returning id into v_audit_id;

  return v_audit_id;
end
$function$;

alter function ops_private.record_audit_event(uuid, uuid, text, text, uuid, text, text)
  owner to dos_control_command;

create or replace function ops_private.queue_outbox_event(
  p_topic text,
  p_event_key text,
  p_payload jsonb
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_event_id uuid;
begin
  insert into ops_private.outbox_events (
    topic,
    event_key,
    payload,
    state
  )
  values (
    p_topic,
    p_event_key,
    p_payload,
    'pending'
  )
  on conflict (topic, event_key) do nothing
  returning id into v_event_id;

  return v_event_id;
end
$function$;

alter function ops_private.queue_outbox_event(text, text, jsonb)
  owner to dos_control_command;

-- ============================================================================
-- Grants
-- ============================================================================

grant select, insert, update on ops_private.idempotency_records,
  ops_private.audit_events, ops_private.outbox_events,
  ops_private.outbox_deliveries, ops_private.support_grants to dos_control_command;

grant select, update on ops_private.outbox_events to dos_outbox_worker;
grant select, insert on ops_private.outbox_deliveries to dos_outbox_worker;

grant execute on function policy.has_support_grant(text, uuid, text)
  to dos_policy, dos_identity_query, dos_control_command;
grant execute on function ops_private.claim_idempotency(text, text, text, text, bytea, integer),
  ops_private.complete_idempotency(uuid, integer, jsonb),
  ops_private.record_audit_event(uuid, uuid, text, text, uuid, text, text),
  ops_private.queue_outbox_event(text, text, jsonb) to dos_control_command;

revoke all on all tables in schema ops_private from public;

commit;
