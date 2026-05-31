-- The stored password hash for a user.
select password_hash
from user_credentials
where user_id = $1;
