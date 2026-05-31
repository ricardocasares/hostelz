-- Upsert a root space (no parent): insert it, or update its fields if the id
-- already exists.
insert into spaces (id, organization_id, is_grouping, label, name, updated_at)
values ($1, $2, $3, $4, $5, now())
on conflict (id) do update
set organization_id = excluded.organization_id,
    parent_id = null,
    is_grouping = excluded.is_grouping,
    label = excluded.label,
    name = excluded.name,
    updated_at = now();
