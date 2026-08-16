begin;

create schema if not exists extensions;
create extension if not exists pgcrypto with schema extensions;
create extension if not exists citext with schema extensions;

create schema if not exists app_private;
create schema if not exists api_v1;
create schema if not exists policy;
create schema if not exists ops_private;

do $roles$
declare
  role_name text;
begin
  foreach role_name in array array[
    'dos_policy',
    'dos_identity_query',
    'dos_identity_command',
    'dos_control_command',
    'dos_outbox_worker',
    'dos_reconciliation_worker'
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

revoke all on schema app_private, api_v1, policy, ops_private from public;
do $supabase_roles$
declare
  role_name text;
begin
  foreach role_name in array array['anon', 'authenticated', 'service_role'] loop
    if exists (select 1 from pg_catalog.pg_roles where rolname = role_name) then
      execute format(
        'revoke all on schema app_private, api_v1, policy, ops_private from %I',
        role_name
      );
    end if;
  end loop;
end
$supabase_roles$;

grant usage on schema app_private, policy to dos_policy;
grant usage on schema api_v1, policy to dos_identity_query;
grant usage on schema app_private, api_v1, policy, ops_private to dos_identity_command;
grant usage on schema policy, ops_private to dos_control_command;
grant usage on schema ops_private to dos_outbox_worker, dos_reconciliation_worker;

alter default privileges in schema app_private revoke all on tables from public;
alter default privileges in schema app_private revoke execute on functions from public;
alter default privileges in schema api_v1 revoke all on tables from public;
alter default privileges in schema api_v1 revoke execute on functions from public;
alter default privileges in schema policy revoke execute on functions from public;
alter default privileges in schema ops_private revoke all on tables from public;
alter default privileges in schema ops_private revoke execute on functions from public;

create or replace function policy.auth_uid()
returns uuid
language plpgsql
stable
set search_path = ''
as $function$
declare
  subject_text text;
  claims_text text;
begin
  subject_text := nullif(pg_catalog.current_setting('request.jwt.claim.sub', true), '');
  if subject_text is null then
    claims_text := nullif(pg_catalog.current_setting('request.jwt.claims', true), '');
    if claims_text is not null then
      subject_text := claims_text::jsonb ->> 'sub';
    end if;
  end if;
  if subject_text is null then
    return null;
  end if;
  begin
    return subject_text::uuid;
  exception when invalid_text_representation then
    return null;
  end;
end
$function$;

revoke all on function policy.auth_uid() from public;
grant execute on function policy.auth_uid() to dos_policy, dos_identity_query,
  dos_identity_command;

comment on schema api_v1 is
  'Reviewed contract-shaped entry points only; M000 intentionally exposes no objects.';
comment on function policy.auth_uid() is
  'Reads the Supabase server-populated JWT subject; request parameters cannot select an actor.';

commit;
