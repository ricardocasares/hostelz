-- Revoke a session (logout). Idempotent.
delete from sessions
where token_hash = $1;
