-- Upsert a guest linked to a user account: insert it, or update its fields if
-- the id already exists.
insert into guests (id, organization_id, user_id, name, email, updated_at)
values ($1, $2, $3, $4, $5, now())
on conflict (id) do update
set organization_id = excluded.organization_id,
    user_id = excluded.user_id,
    name = excluded.name,
    email = excluded.email,
    updated_at = now();
