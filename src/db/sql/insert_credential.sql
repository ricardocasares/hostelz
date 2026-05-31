-- Upsert a user's password hash.
insert into user_credentials (user_id, password_hash, updated_at)
values ($1, $2, now())
on conflict (user_id) do update
set password_hash = excluded.password_hash,
    updated_at = now();
