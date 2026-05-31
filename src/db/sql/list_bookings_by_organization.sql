-- List an organization's bookings, newest first.
select id, organization_id, guest_id, status
from bookings
where organization_id = $1
order by created_at desc;
