-- =============================================================================
-- 004_system_hardening.sql
-- Tightens the data model after a full review of the system:
--
--   1. Dedupes inactivity_reminders and adds a UNIQUE(user_id, threshold_percent)
--   2. Replaces trg_checkin_update_user so a user logging back in ALSO cancels
--      any open death_verifications rows (otherwise they sit "initiated" forever)
--   3. Adds an index used by the new ManageAssets list query
--   4. Adds a helper view (asset_summary) used by the new dashboard / list
--
-- Safe to run multiple times.
-- =============================================================================

USE dams;

-- -----------------------------------------------------------------------------
-- 1) Dedupe inactivity_reminders and lock the constraint in
-- -----------------------------------------------------------------------------

-- Keep only the lowest reminder_id per (user_id, threshold_percent)
DELETE r1 FROM inactivity_reminders r1
INNER JOIN inactivity_reminders r2
  ON r1.user_id           = r2.user_id
 AND r1.threshold_percent = r2.threshold_percent
 AND r1.reminder_id       > r2.reminder_id;

-- Add a unique constraint if missing (no native IF NOT EXISTS for ADD KEY)
SET @c := (
    SELECT COUNT(*) FROM information_schema.table_constraints
    WHERE table_schema = DATABASE()
      AND table_name   = 'inactivity_reminders'
      AND constraint_name = 'uq_ir_user_threshold'
);
SET @sql := IF(@c = 0,
    'ALTER TABLE inactivity_reminders ADD CONSTRAINT uq_ir_user_threshold UNIQUE (user_id, threshold_percent)',
    'SELECT "uq_ir_user_threshold already exists"');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;


-- -----------------------------------------------------------------------------
-- 2) Recreate trg_checkin_update_user so re-activation also cancels open
--    death_verifications. Old version only flipped the account_status.
-- -----------------------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_checkin_update_user;

DELIMITER $$
CREATE TRIGGER trg_checkin_update_user
AFTER INSERT ON checkin_log
FOR EACH ROW
BEGIN
    UPDATE users
    SET
        last_checkin_at = NEW.checkin_at,
        account_status  = IF(account_status IN ('Flagged', 'Pending_Verification'),
                             'Active',
                             account_status)
    WHERE user_id = NEW.user_id;

    -- Any open verification for this user is now stale: the user is alive.
    UPDATE death_verifications
    SET status       = 'cancelled',
        cancelled_at = NOW()
    WHERE user_id = NEW.user_id
      AND status IN ('initiated', 'awaiting_quorum');
END$$
DELIMITER ;


-- -----------------------------------------------------------------------------
-- 3) Index that supports the new ManageAssets list query
-- -----------------------------------------------------------------------------
SET @i := (
    SELECT COUNT(*) FROM information_schema.statistics
    WHERE table_schema = DATABASE()
      AND table_name   = 'digital_assets'
      AND index_name   = 'idx_da_user_status'
);
SET @sql := IF(@i = 0,
    'CREATE INDEX idx_da_user_status ON digital_assets (user_id, status)',
    'SELECT "idx_da_user_status already exists"');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;


-- -----------------------------------------------------------------------------
-- 4) asset_summary view — one row per asset with the counts/total the
--    Manage Assets table and Dashboard now display.
-- -----------------------------------------------------------------------------
DROP VIEW IF EXISTS asset_summary;
CREATE VIEW asset_summary AS
SELECT
    a.asset_id,
    a.user_id,
    a.asset_name,
    a.asset_type,
    a.description,
    a.instructions,
    a.require_contact_verify,
    a.status,
    a.include_in_estate,
    a.created_at,
    a.updated_at,
    COALESCE((
        SELECT COUNT(*) FROM asset_beneficiaries ab WHERE ab.asset_id = a.asset_id
    ), 0)                                              AS beneficiary_count,
    COALESCE((
        SELECT SUM(ab.share_percentage) FROM asset_beneficiaries ab WHERE ab.asset_id = a.asset_id
    ), 0)                                              AS share_total,
    COALESCE((
        SELECT COUNT(*) FROM vault_entries v WHERE v.asset_id = a.asset_id
    ), 0)                                              AS vault_count
FROM digital_assets a;
