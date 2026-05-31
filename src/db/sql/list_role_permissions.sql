-- A role's permissions.
select permission
from role_permissions
where role_id = $1;
