-- Create a session. The token is stored only as its hash; the row expires in
-- 30 days (TTL handled here so no timestamp parameter is needed).
insert into sessions (token_hash, user_id, expires_at)
values ($1, $2, now() + interval '30 days');
