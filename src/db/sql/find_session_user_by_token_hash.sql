-- The user behind a session token hash, only while the session is unexpired.
select user_id
from sessions
where token_hash = $1
  and expires_at > now();
