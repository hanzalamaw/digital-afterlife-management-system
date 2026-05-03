-- Run once on the DAMS database to enable admin access control.
ALTER TABLE users
  ADD COLUMN is_admin TINYINT(1) NOT NULL DEFAULT 0 AFTER recovery_email;

