-- Find a single booking by id.
select id, organization_id, guest_id, status
from bookings
where id = $1;
