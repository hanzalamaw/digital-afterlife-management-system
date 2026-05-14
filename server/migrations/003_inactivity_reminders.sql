-- =============================================================================
-- 003_inactivity_reminders.sql
-- Adds support for multiple reminder messages dispatched when a user's
-- inactivity grows toward the "pronounce dead" threshold.
-- Also adds a send-log so the cron job doesn't re-send the same reminder.
-- Safe to run multiple times (idempotent guards included).
-- =============================================================================

USE dams;

-- -----------------------------------------------------------------------------
-- 1. inactivity_reminders
--    User-defined reminders fired when a percent-of-threshold is reached.
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS inactivity_reminders (
    reminder_id        INT          NOT NULL AUTO_INCREMENT,
    user_id            INT          NOT NULL,
    threshold_percent  INT          NOT NULL
                                    COMMENT 'When days_since_checkin / inactivity_days >= this percent, fire reminder',
    custom_message     TEXT         NULL DEFAULT NULL,
    created_at         DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT pk_inactivity_reminders PRIMARY KEY (reminder_id),
    CONSTRAINT fk_ir_user_id
        FOREIGN KEY (user_id) REFERENCES users(user_id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT ck_ir_threshold
        CHECK (threshold_percent BETWEEN 1 AND 99)
) ENGINE=InnoDB COMMENT='User-defined reminders for the inactivity death rule';


-- -----------------------------------------------------------------------------
-- 2. inactivity_reminder_sends
--    Audit log of reminders that have actually been emailed so we don't
--    double-send when the cron job runs repeatedly.
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS inactivity_reminder_sends (
    send_id           INT          NOT NULL AUTO_INCREMENT,
    user_id           INT          NOT NULL,
    reminder_id       INT              NULL DEFAULT NULL,
    threshold_percent INT          NOT NULL,
    sent_at           DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT pk_inactivity_reminder_sends PRIMARY KEY (send_id),
    CONSTRAINT fk_irs_user_id
        FOREIGN KEY (user_id) REFERENCES users(user_id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_irs_reminder_id
        FOREIGN KEY (reminder_id) REFERENCES inactivity_reminders(reminder_id)
        ON DELETE SET NULL ON UPDATE CASCADE,
    INDEX idx_irs_user_threshold (user_id, threshold_percent)
) ENGINE=InnoDB COMMENT='Tracks which reminder thresholds have already fired';


-- -----------------------------------------------------------------------------
-- 3. notification_log
--    Stores every email the system attempts to send to a beneficiary or
--    trusted contact. Useful for the admin and the dashboard.
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS notification_log (
    notification_id INT          NOT NULL AUTO_INCREMENT,
    user_id         INT              NULL DEFAULT NULL,
    recipient_email VARCHAR(200) NOT NULL,
    recipient_name  VARCHAR(150)     NULL DEFAULT NULL,
    subject         VARCHAR(255) NOT NULL,
    body            TEXT             NULL DEFAULT NULL,
    category        ENUM(
                      'reminder',
                      'suspect_death',
                      'confirmed_death',
                      'beneficiary_grant',
                      'contact_request',
                      'other'
                    ) NOT NULL DEFAULT 'other',
    status          ENUM('queued','sent','failed') NOT NULL DEFAULT 'queued',
    error_message   TEXT             NULL DEFAULT NULL,
    created_at      DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    sent_at         DATETIME         NULL DEFAULT NULL,

    CONSTRAINT pk_notification_log PRIMARY KEY (notification_id),
    CONSTRAINT fk_nl_user_id
        FOREIGN KEY (user_id) REFERENCES users(user_id)
        ON DELETE SET NULL ON UPDATE CASCADE,
    INDEX idx_nl_user_category (user_id, category, created_at)
) ENGINE=InnoDB COMMENT='Audit log of every notification the system attempts to send';
