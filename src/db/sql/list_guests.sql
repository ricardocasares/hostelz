-- List all guests, most recently created first.
select id, name, email
from guests
order by created_at desc;
