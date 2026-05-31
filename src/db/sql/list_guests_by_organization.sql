-- List one organization's guests, most recently created first.
select id, organization_id, user_id, name, email
from guests
where organization_id = $1
order by created_at desc;
