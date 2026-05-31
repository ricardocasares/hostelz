-- Delete a role. Its permissions cascade; a role still assigned to a member is
-- blocked by the membership foreign key.
delete from roles
where id = $1;
