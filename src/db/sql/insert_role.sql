-- Upsert a role row (its permissions are written separately).
insert into roles (id, organization_id, name, is_owner, updated_at)
values ($1, $2, $3, $4, now())
on conflict (id) do update
set name = excluded.name,
    is_owner = excluded.is_owner,
    updated_at = now();
