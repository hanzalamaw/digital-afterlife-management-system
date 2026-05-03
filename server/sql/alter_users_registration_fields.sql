-- Run once if your `users` table was created from dams.sql (before API registration fields).
-- Adds columns expected by the PHP registration endpoint.

ALTER TABLE users
  ADD COLUMN country VARCHAR(100) NULL DEFAULT NULL AFTER phone,
  ADD COLUMN recovery_email VARCHAR(200) NULL DEFAULT NULL AFTER email;
