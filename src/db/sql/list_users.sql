-- List all users, most recently created first.
select id, email, name
from users
order by created_at desc;
