begin;

-- ============================================================================
-- Views in api_v1
-- ============================================================================

create or replace view api_v1.my_profile with (security_barrier = true) as
select
  p.id,
  p.display_name,
  p.state,
  p.version,
  p.created_at,
  p.updated_at
from app_private.profiles as p
where p.id = policy.actor_profile_id()
  and p.state = 'active';

alter view api_v1.my_profile owner to dos_identity_query;

create or replace view api_v1.organization_memberships with (security_barrier = true) as
select
  m.id,
  m.organization_id,
  m.profile_id,
  m.state,
  coalesce(
    (
      select array_agg(r.role_name order by r.role_name)
      from app_private.membership_role_grants as r
      where r.organization_id = m.organization_id
        and r.membership_id = m.id
    ),
    array[]::text[]
  ) as roles,
  m.version,
  m.created_at,
  m.updated_at
from app_private.organization_memberships as m
join app_private.organizations as o on o.id = m.organization_id
where m.state = 'active'
  and o.state = 'active'
  and (
    m.profile_id = policy.actor_profile_id()
    or policy.has_org_role(m.organization_id, array['org_owner'])
  );

alter view api_v1.organization_memberships owner to dos_identity_query;

-- ============================================================================
-- Command functions in api_v1
-- ============================================================================

create or replace function api_v1.cmd_update_my_profile(
  p_display_name text,
  p_expected_version bigint
)
returns api_v1.my_profile
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_profile_id uuid;
  v_current_version bigint;
  v_result api_v1.my_profile%rowtype;
begin
  v_profile_id := policy.actor_profile_id();
  if v_profile_id is null then
    raise exception 'authenticated active profile required' using errcode = '42501';
  end if;

  if p_display_name is null or length(trim(p_display_name)) = 0 or length(p_display_name) > 120 then
    raise exception 'invalid display name' using errcode = '22000';
  end if;

  select version into v_current_version
  from app_private.profiles
  where id = v_profile_id
  for update;

  if v_current_version <> p_expected_version then
    raise exception 'version conflict' using errcode = 'P0002';
  end if;

  update app_private.profiles
  set
    display_name = trim(p_display_name),
    version = version + 1,
    updated_at = transaction_timestamp()
  where id = v_profile_id;

  select * into v_result
  from api_v1.my_profile
  where id = v_profile_id;

  return v_result;
end
$function$;

alter function api_v1.cmd_update_my_profile(text, bigint) owner to dos_identity_command;

create or replace function api_v1.cmd_create_organization(
  p_legal_name text,
  p_display_name text,
  p_slug text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_profile_id uuid;
  v_org_id uuid;
  v_membership_id uuid;
begin
  v_profile_id := policy.actor_profile_id();
  if v_profile_id is null then
    raise exception 'authenticated active profile required' using errcode = '42501';
  end if;

  if not policy.actor_is_adult() then
    raise exception 'organization creation requires verified adult assurance' using errcode = '42501';
  end if;

  if p_legal_name is null or length(trim(p_legal_name)) = 0 or length(p_legal_name) > 200 then
    raise exception 'invalid legal name' using errcode = '22000';
  end if;
  if p_display_name is null or length(trim(p_display_name)) = 0 or length(p_display_name) > 120 then
    raise exception 'invalid display name' using errcode = '22000';
  end if;
  if p_slug is null or length(trim(p_slug)) = 0 or length(p_slug) > 80 then
    raise exception 'invalid slug' using errcode = '22000';
  end if;

  insert into app_private.organizations (legal_name, display_name, slug, state)
  values (trim(p_legal_name), trim(p_display_name), trim(p_slug)::extensions.citext, 'active')
  returning id into v_org_id;

  insert into app_private.organization_memberships (organization_id, profile_id, state)
  values (v_org_id, v_profile_id, 'active')
  returning id into v_membership_id;

  insert into app_private.membership_role_grants (organization_id, membership_id, role_name)
  values (v_org_id, v_membership_id, 'org_owner');

  return v_org_id;
end
$function$;

alter function api_v1.cmd_create_organization(text, text, text) owner to dos_identity_command;

create or replace function api_v1.cmd_create_organization_invitation(
  p_organization_id uuid,
  p_email_hint text,
  p_token_hash bytea,
  p_normalized_email_hash bytea,
  p_encrypted_delivery_address bytea,
  p_key_version int,
  p_role_names text[],
  p_expires_at timestamptz
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_profile_id uuid;
  v_inviter_membership_id uuid;
  v_invitation_id uuid;
  v_role text;
begin
  v_profile_id := policy.actor_profile_id();
  if v_profile_id is null then
    raise exception 'authenticated active profile required' using errcode = '42501';
  end if;

  if not policy.has_org_role(p_organization_id, array['org_owner']) then
    raise exception 'only organization owners may create invitations' using errcode = '42501';
  end if;

  select id into v_inviter_membership_id
  from app_private.organization_memberships
  where organization_id = p_organization_id
    and profile_id = v_profile_id
    and state = 'active'
  limit 1;

  if v_inviter_membership_id is null then
    raise exception 'active inviter membership not found' using errcode = '42501';
  end if;

  if p_token_hash is null or octet_length(p_token_hash) <> 32 then
    raise exception 'invalid token hash' using errcode = '22000';
  end if;
  if p_normalized_email_hash is null or octet_length(p_normalized_email_hash) <> 32 then
    raise exception 'invalid email hash' using errcode = '22000';
  end if;
  if p_expires_at is null or p_expires_at <= transaction_timestamp() then
    raise exception 'invitation expiry must be in the future' using errcode = '22000';
  end if;

  insert into app_private.organization_invitations (
    organization_id,
    invited_by_membership_id,
    token_hash,
    normalized_email_hash,
    email_hint,
    state,
    expires_at
  )
  values (
    p_organization_id,
    v_inviter_membership_id,
    p_token_hash,
    p_normalized_email_hash,
    p_email_hint,
    'pending',
    p_expires_at
  )
  returning id into v_invitation_id;

  if p_encrypted_delivery_address is not null then
    insert into app_private.organization_invitation_contacts (
      organization_id,
      invitation_id,
      encrypted_delivery_address,
      key_version
    )
    values (
      p_organization_id,
      v_invitation_id,
      p_encrypted_delivery_address,
      coalesce(p_key_version, 1)
    );
  end if;

  if p_role_names is not null and array_length(p_role_names, 1) > 0 then
    foreach v_role in array p_role_names loop
      if v_role not in ('org_owner', 'organizer', 'media_moderator') then
        raise exception 'invalid role name: %', v_role using errcode = '22000';
      end if;
      insert into app_private.organization_invitation_role_grants (
        organization_id,
        invitation_id,
        role_name
      )
      values (
        p_organization_id,
        v_invitation_id,
        v_role
      );
    end loop;
  end if;

  return v_invitation_id;
end
$function$;

alter function api_v1.cmd_create_organization_invitation(
  uuid, text, bytea, bytea, bytea, int, text[], timestamptz
) owner to dos_identity_command;

create or replace function api_v1.cmd_accept_organization_invitation(
  p_token_hash bytea
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_profile_id uuid;
  v_invitation record;
  v_membership_id uuid;
  v_role record;
begin
  v_profile_id := policy.actor_profile_id();
  if v_profile_id is null then
    raise exception 'authenticated active profile required' using errcode = '42501';
  end if;

  select * into v_invitation
  from app_private.organization_invitations
  where token_hash = p_token_hash
  for update;

  if not found then
    raise exception 'invitation not found' using errcode = 'P0002';
  end if;

  if v_invitation.state <> 'pending' then
    raise exception 'invitation is not pending' using errcode = '23514';
  end if;

  if v_invitation.expires_at <= transaction_timestamp() then
    update app_private.organization_invitations
    set state = 'expired'
    where id = v_invitation.id;
    raise exception 'invitation has expired' using errcode = '23514';
  end if;

  -- Create or activate membership
  insert into app_private.organization_memberships (
    organization_id,
    profile_id,
    state
  )
  values (
    v_invitation.organization_id,
    v_profile_id,
    'active'
  )
  on conflict (organization_id, profile_id) do update
  set state = 'active', updated_at = transaction_timestamp()
  returning id into v_membership_id;

  -- Apply granted roles
  for v_role in
    select role_name
    from app_private.organization_invitation_role_grants
    where organization_id = v_invitation.organization_id
      and invitation_id = v_invitation.id
  loop
    insert into app_private.membership_role_grants (
      organization_id,
      membership_id,
      role_name
    )
    values (
      v_invitation.organization_id,
      v_membership_id,
      v_role.role_name
    )
    on conflict do nothing;
  end loop;

  -- Mark invitation accepted
  update app_private.organization_invitations
  set
    state = 'accepted',
    accepted_by_profile_id = v_profile_id,
    accepted_at = transaction_timestamp(),
    version = version + 1
  where id = v_invitation.id;

  return v_membership_id;
end
$function$;

alter function api_v1.cmd_accept_organization_invitation(bytea) owner to dos_identity_command;

create or replace function api_v1.cmd_revoke_organization_invitation(
  p_organization_id uuid,
  p_invitation_id uuid
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_profile_id uuid;
  v_invitation record;
begin
  v_profile_id := policy.actor_profile_id();
  if v_profile_id is null then
    raise exception 'authenticated active profile required' using errcode = '42501';
  end if;

  if not policy.has_org_role(p_organization_id, array['org_owner']) then
    raise exception 'only organization owners may revoke invitations' using errcode = '42501';
  end if;

  select * into v_invitation
  from app_private.organization_invitations
  where organization_id = p_organization_id
    and id = p_invitation_id
  for update;

  if not found then
    raise exception 'invitation not found' using errcode = 'P0002';
  end if;

  if v_invitation.state <> 'pending' then
    raise exception 'cannot revoke non-pending invitation' using errcode = '23514';
  end if;

  update app_private.organization_invitations
  set
    state = 'revoked',
    revoked_at = transaction_timestamp(),
    version = version + 1
  where id = p_invitation_id;

  return true;
end
$function$;

alter function api_v1.cmd_revoke_organization_invitation(uuid, uuid) owner to dos_identity_command;

-- Grants
grant select on api_v1.my_profile, api_v1.organization_memberships to dos_identity_query;
grant execute on function api_v1.cmd_update_my_profile(text, bigint),
  api_v1.cmd_create_organization(text, text, text),
  api_v1.cmd_create_organization_invitation(uuid, text, bytea, bytea, bytea, int, text[], timestamptz),
  api_v1.cmd_accept_organization_invitation(bytea),
  api_v1.cmd_revoke_organization_invitation(uuid, uuid) to dos_identity_command;

commit;
