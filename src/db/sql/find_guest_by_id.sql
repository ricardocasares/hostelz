-- Find a single guest by id.
select id, name, email
from guests
where id = $1;
