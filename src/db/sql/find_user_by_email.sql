-- Find a single user by email.
select id, email, name
from users
where email = $1;
