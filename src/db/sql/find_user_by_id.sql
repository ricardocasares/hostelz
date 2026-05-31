-- Find a single user by id.
select id, email, name
from users
where id = $1;
