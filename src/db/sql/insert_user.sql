-- Upsert a user: insert it, or update email/name if the id already exists.
insert into users (id, email, name, updated_at)
values ($1, $2, $3, now())
on conflict (id) do update
set email = excluded.email,
    name = excluded.name,
    updated_at = now();
