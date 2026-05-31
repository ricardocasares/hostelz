-- Upsert a membership: add the user to the org, or change their role.
insert into memberships (id, organization_id, user_id, role_id, updated_at)
values ($1, $2, $3, $4, now())
on conflict (organization_id, user_id) do update
set role_id = excluded.role_id,
    updated_at = now();
