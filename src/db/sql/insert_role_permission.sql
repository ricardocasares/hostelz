-- Grant a permission to a role.
insert into role_permissions (role_id, permission)
values ($1, $2)
on conflict do nothing;
