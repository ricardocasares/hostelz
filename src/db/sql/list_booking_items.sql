-- List a booking's items, period rendered as ISO date text.
select id, booking_id,
  to_char(lower(period), 'YYYY-MM-DD') as check_in,
  to_char(upper(period), 'YYYY-MM-DD') as check_out,
  kind, target_space_id, assigned_space_id
from booking_items
where booking_id = $1
order by created_at asc;
