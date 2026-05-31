-- Clear a role's permissions (before re-inserting the new set on save).
delete from role_permissions
where role_id = $1;
