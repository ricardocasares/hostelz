-- Upsert a guest: insert it, or update name/email if the id already exists.
insert into guests (id, name, email, updated_at)
values ($1, $2, $3, now())
on conflict (id) do update
set name = excluded.name,
    email = excluded.email,
    updated_at = now();
