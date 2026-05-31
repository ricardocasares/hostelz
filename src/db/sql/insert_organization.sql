-- Upsert an organization: insert it, or update slug/name if the id exists.
insert into organizations (id, slug, name, updated_at)
values ($1, $2, $3, now())
on conflict (id) do update
set slug = excluded.slug,
    name = excluded.name,
    updated_at = now();
