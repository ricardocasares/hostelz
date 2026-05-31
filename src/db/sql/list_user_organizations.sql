-- The organizations a user belongs to, oldest first.
select o.id, o.slug, o.name
from organizations o
join memberships m on m.organization_id = o.id
where m.user_id = $1
order by o.created_at asc;
