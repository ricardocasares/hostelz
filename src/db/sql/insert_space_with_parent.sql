-- Upsert a nested space (with a parent): insert it, or update its fields if the
-- id already exists.
insert into spaces (id, organization_id, parent_id, is_grouping, label, name, bookable, updated_at)
values ($1, $2, $3, $4, $5, $6, $7, now())
on conflict (id) do update
set organization_id = excluded.organization_id,
    parent_id = excluded.parent_id,
    is_grouping = excluded.is_grouping,
    label = excluded.label,
    name = excluded.name,
    bookable = excluded.bookable,
    updated_at = now();
