-- Run once on the DAMS database (same name as DB_NAME in server/.env).
-- Adds signup fields expected by the API; safe to re-run only if columns do not exist.

ALTER TABLE users
  ADD COLUMN country VARCHAR(100) NULL DEFAULT NULL AFTER phone,
  ADD COLUMN recovery_email VARCHAR(200) NULL DEFAULT NULL AFTER country;
