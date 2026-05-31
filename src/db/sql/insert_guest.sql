-- Upsert a walk-in guest (no linked user account): insert it, or update its
-- fields if the id already exists.
insert into guests (id, organization_id, name, email, updated_at)
values ($1, $2, $3, $4, now())
on conflict (id) do update
set organization_id = excluded.organization_id,
    user_id = null,
    name = excluded.name,
    email = excluded.email,
    updated_at = now();
