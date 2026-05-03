-- =============================================================================
-- DIGITAL AFTERLIFE MANAGEMENT SYSTEM (DAMS)
-- Complete MySQL Database Schema + Sample Data + Queries + Views + Triggers + Events
-- Student: Hanzala Muhammad Abdul Wahab | ID: 20241-36798
-- Course: Database Management Systems | IoBM
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 0. DATABASE SETUP
-- -----------------------------------------------------------------------------

DROP DATABASE IF EXISTS dams;
CREATE DATABASE dams
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE dams;

SET FOREIGN_KEY_CHECKS = 0;
SET SQL_MODE = 'STRICT_TRANS_TABLES,NO_ZERO_DATE,NO_ZERO_IN_DATE,ERROR_FOR_DIVISION_BY_ZERO';

-- =============================================================================
-- 1. TABLE DEFINITIONS (DDL)
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1.1 USERS
--     Central entity. Tracks all registered users and their lifecycle status.
-- -----------------------------------------------------------------------------
CREATE TABLE users (
    user_id               INT            NOT NULL AUTO_INCREMENT,
    full_name             VARCHAR(150)   NOT NULL,
    email                 VARCHAR(200)   NOT NULL,
    password_hash         VARCHAR(255)   NOT NULL,
    date_of_birth         DATE           NOT NULL,
    phone                 VARCHAR(30)        NULL DEFAULT NULL,
    account_status        ENUM(
                            'Active',
                            'Flagged',
                            'Pending_Verification',
                            'Deceased',
                            'Executed'
                          )              NOT NULL DEFAULT 'Active',
    last_checkin_at       DATETIME       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    checkin_interval_days INT            NOT NULL DEFAULT 90
                                         COMMENT 'Days of inactivity before flagging',
    created_at            DATETIME       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at            DATETIME       NOT NULL DEFAULT CURRENT_TIMESTAMP
                                                   ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT pk_users        PRIMARY KEY (user_id),
    CONSTRAINT uq_users_email  UNIQUE      (email),
    CONSTRAINT ck_users_interval
        CHECK (checkin_interval_days BETWEEN 7 AND 3650)
) ENGINE=InnoDB COMMENT='Core user accounts and lifecycle states';


-- -----------------------------------------------------------------------------
-- 1.2 DEATH_TRIGGER_RULES
--     Configurable rules each user sets to define when death verification fires.
-- -----------------------------------------------------------------------------
CREATE TABLE death_trigger_rules (
    rule_id            INT  NOT NULL AUTO_INCREMENT,
    user_id            INT  NOT NULL,
    rule_type          ENUM(
                         'inactivity_timer',
                         'quorum_vote',
                         'manual_declaration',
                         'combined_and'
                       )    NOT NULL,
    inactivity_days    INT      NULL DEFAULT NULL
                                COMMENT 'Days before flagging; NULL for quorum_vote only',
    quorum_required    INT      NULL DEFAULT NULL
                                COMMENT 'Contacts needed to confirm; NULL for inactivity_timer only',
    grace_period_days  INT  NOT NULL DEFAULT 7
                                COMMENT 'Days user has to cancel after a declaration',
    logic_operator     ENUM('AND', 'OR') NULL DEFAULT NULL
                                COMMENT 'Only used for combined_and rule type',
    is_active          TINYINT(1) NOT NULL DEFAULT 1,
    created_at         DATETIME   NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT pk_death_trigger_rules  PRIMARY KEY (rule_id),
    CONSTRAINT fk_dtr_user_id
        FOREIGN KEY (user_id) REFERENCES users(user_id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT ck_dtr_inactivity
        CHECK (inactivity_days IS NULL OR inactivity_days >= 7),
    CONSTRAINT ck_dtr_quorum
        CHECK (quorum_required IS NULL OR quorum_required >= 1)
) ENGINE=InnoDB COMMENT='User-configured death detection rule sets';


-- -----------------------------------------------------------------------------
-- 1.3 TRUSTED_CONTACTS
--     People the user designates to participate in death verification.
-- -----------------------------------------------------------------------------
CREATE TABLE trusted_contacts (
    contact_id          INT          NOT NULL AUTO_INCREMENT,
    user_id             INT          NOT NULL,
    full_name           VARCHAR(150) NOT NULL,
    email               VARCHAR(200) NOT NULL,
    phone               VARCHAR(30)      NULL DEFAULT NULL,
    verification_token  VARCHAR(100)     NULL DEFAULT NULL,
    verification_status ENUM('pending', 'verified') NOT NULL DEFAULT 'pending',
    priority_order      INT          NOT NULL DEFAULT 1
                                     COMMENT 'Lower number = notified first',
    verified_at         DATETIME         NULL DEFAULT NULL,
    created_at          DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT pk_trusted_contacts  PRIMARY KEY (contact_id),
    CONSTRAINT fk_tc_user_id
        FOREIGN KEY (user_id) REFERENCES users(user_id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT ck_tc_priority
        CHECK (priority_order >= 1)
) ENGINE=InnoDB COMMENT='Trusted contacts for death verification';


-- -----------------------------------------------------------------------------
-- 1.4 DEATH_VERIFICATIONS
--     Tracks each death verification event initiated for a user.
-- -----------------------------------------------------------------------------
CREATE TABLE death_verifications (
    verification_id         INT  NOT NULL AUTO_INCREMENT,
    user_id                 INT  NOT NULL,
    initiated_by            INT      NULL DEFAULT NULL
                                     COMMENT 'NULL if triggered by inactivity',
    status                  ENUM(
                              'initiated',
                              'awaiting_quorum',
                              'confirmed',
                              'cancelled',
                              'expired'
                            ) NOT NULL DEFAULT 'initiated',
    confirmations_received  INT  NOT NULL DEFAULT 0,
    confirmations_required  INT  NOT NULL DEFAULT 1,
    trigger_source          ENUM(
                              'inactivity_timer',
                              'contact_report',
                              'admin_override'
                            ) NOT NULL,
    initiated_at            DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    confirmed_at            DATETIME         NULL DEFAULT NULL,
    expires_at              DATETIME         NULL DEFAULT NULL,
    cancelled_at            DATETIME         NULL DEFAULT NULL,

    CONSTRAINT pk_death_verifications  PRIMARY KEY (verification_id),
    CONSTRAINT fk_dv_user_id
        FOREIGN KEY (user_id)       REFERENCES users(user_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_dv_initiated_by
        FOREIGN KEY (initiated_by)  REFERENCES trusted_contacts(contact_id)
        ON DELETE SET NULL ON UPDATE CASCADE,
    CONSTRAINT ck_dv_confirmations
        CHECK (confirmations_received >= 0 AND confirmations_required >= 1)
) ENGINE=InnoDB COMMENT='Death verification events per user';


-- -----------------------------------------------------------------------------
-- 1.5 CONTACT_CONFIRMATIONS
--     Individual trusted contact responses to a verification request.
-- -----------------------------------------------------------------------------
CREATE TABLE contact_confirmations (
    confirmation_id  INT          NOT NULL AUTO_INCREMENT,
    verification_id  INT          NOT NULL,
    contact_id       INT          NOT NULL,
    action           ENUM('confirmed', 'denied', 'no_response')
                                  NOT NULL DEFAULT 'no_response',
    token_used       VARCHAR(100)     NULL DEFAULT NULL,
    ip_address       VARCHAR(45)      NULL DEFAULT NULL,
    responded_at     DATETIME         NULL DEFAULT NULL,

    CONSTRAINT pk_contact_confirmations  PRIMARY KEY (confirmation_id),
    CONSTRAINT fk_cc_verification_id
        FOREIGN KEY (verification_id) REFERENCES death_verifications(verification_id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_cc_contact_id
        FOREIGN KEY (contact_id)      REFERENCES trusted_contacts(contact_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT uq_cc_verification_contact
        UNIQUE (verification_id, contact_id)
        COMMENT 'One response per contact per verification'
) ENGINE=InnoDB COMMENT='Individual contact responses to verification requests';


-- -----------------------------------------------------------------------------
-- 1.6 DIGITAL_ASSETS
--     All digital properties a user registers for posthumous execution.
--     require_contact_verify: if TRUE, trusted contacts must confirm before
--     this specific asset's credentials are released.
-- -----------------------------------------------------------------------------
CREATE TABLE digital_assets (
    asset_id                INT          NOT NULL AUTO_INCREMENT,
    user_id                 INT          NOT NULL,
    asset_name              VARCHAR(200) NOT NULL,
    asset_type              ENUM(
                              'bank_account',
                              'crypto_wallet',
                              'social_media',
                              'email',
                              'file_storage',
                              'subscription',
                              'domain',
                              'other'
                            ) NOT NULL,
    description             TEXT             NULL DEFAULT NULL,
    instructions            TEXT             NULL DEFAULT NULL
                                             COMMENT 'What to do with this asset after death',
    require_contact_verify  TINYINT(1)   NOT NULL DEFAULT 0
                                         COMMENT 'If 1, trusted contacts must verify before release',
    status                  ENUM(
                              'active',
                              'pending_execution',
                              'executed',
                              'cancelled'
                            ) NOT NULL DEFAULT 'active',
    include_in_estate       TINYINT(1)   NOT NULL DEFAULT 1,
    created_at              DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at              DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP
                                                   ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT pk_digital_assets  PRIMARY KEY (asset_id),
    CONSTRAINT fk_da_user_id
        FOREIGN KEY (user_id) REFERENCES users(user_id)
        ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB COMMENT='Digital assets registered for posthumous execution';


-- -----------------------------------------------------------------------------
-- 1.7 VAULT_ENTRIES
--     Encrypted credential fields. Each sensitive field is its own row
--     with a unique IV so credentials are never stored in plaintext.
-- -----------------------------------------------------------------------------
CREATE TABLE vault_entries (
    vault_id         INT          NOT NULL AUTO_INCREMENT,
    asset_id         INT          NOT NULL,
    field_name       VARCHAR(100) NOT NULL
                                  COMMENT 'e.g. password, seed_phrase, recovery_key',
    encrypted_value  TEXT         NOT NULL COMMENT 'AES-256-CBC ciphertext',
    iv               VARCHAR(64)  NOT NULL COMMENT 'Initialization vector for decryption',
    encryption_algo  VARCHAR(30)  NOT NULL DEFAULT 'AES-256-CBC',
    created_at       DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT pk_vault_entries  PRIMARY KEY (vault_id),
    CONSTRAINT fk_ve_asset_id
        FOREIGN KEY (asset_id) REFERENCES digital_assets(asset_id)
        ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB COMMENT='Encrypted credential vault for digital assets';


-- -----------------------------------------------------------------------------
-- 1.8 BENEFICIARIES
--     Recipients of asset credentials. Independent of user accounts —
--     the same person can be a beneficiary for multiple users.
-- -----------------------------------------------------------------------------
CREATE TABLE beneficiaries (
    beneficiary_id      INT          NOT NULL AUTO_INCREMENT,
    full_name           VARCHAR(150) NOT NULL,
    email               VARCHAR(200) NOT NULL,
    phone               VARCHAR(30)      NULL DEFAULT NULL,
    relationship        VARCHAR(100)     NULL DEFAULT NULL,
    verification_token  VARCHAR(100)     NULL DEFAULT NULL,
    verification_status ENUM('pending', 'verified') NOT NULL DEFAULT 'pending',
    verified_at         DATETIME         NULL DEFAULT NULL,
    created_at          DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT pk_beneficiaries  PRIMARY KEY (beneficiary_id)
) ENGINE=InnoDB COMMENT='Asset recipients - independent of user accounts';


-- -----------------------------------------------------------------------------
-- 1.9 ASSET_BENEFICIARIES
--     Junction table: many assets <-> many beneficiaries.
--     share_percentage per asset must sum to 100 (enforced by trigger below).
-- -----------------------------------------------------------------------------
CREATE TABLE asset_beneficiaries (
    id                   INT            NOT NULL AUTO_INCREMENT,
    asset_id             INT            NOT NULL,
    beneficiary_id       INT            NOT NULL,
    share_percentage     DECIMAL(5, 2)  NOT NULL DEFAULT 100.00,
    special_instructions TEXT               NULL DEFAULT NULL,
    notification_method  ENUM('email', 'sms', 'both') NOT NULL DEFAULT 'email',
    assigned_at          DATETIME       NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT pk_asset_beneficiaries  PRIMARY KEY (id),
    CONSTRAINT uq_asset_beneficiary    UNIQUE (asset_id, beneficiary_id),
    CONSTRAINT fk_ab_asset_id
        FOREIGN KEY (asset_id)       REFERENCES digital_assets(asset_id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_ab_beneficiary_id
        FOREIGN KEY (beneficiary_id) REFERENCES beneficiaries(beneficiary_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT ck_ab_share
        CHECK (share_percentage > 0 AND share_percentage <= 100)
) ENGINE=InnoDB COMMENT='Many-to-many: assets to beneficiaries with share splits';


-- -----------------------------------------------------------------------------
-- 1.10 CHECKIN_LOG
--      Every login and manual check-in. Used by the Event Scheduler
--      to evaluate inactivity against each user's configured threshold.
-- -----------------------------------------------------------------------------
CREATE TABLE checkin_log (
    checkin_id    INT          NOT NULL AUTO_INCREMENT,
    user_id       INT          NOT NULL,
    checkin_type  ENUM('login', 'manual_ping', 'api_call') NOT NULL DEFAULT 'login',
    ip_address    VARCHAR(45)      NULL DEFAULT NULL,
    user_agent    VARCHAR(500)     NULL DEFAULT NULL,
    client_type   ENUM('web', 'socket_client', 'api') NOT NULL DEFAULT 'web',
    checkin_at    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT pk_checkin_log  PRIMARY KEY (checkin_id),
    CONSTRAINT fk_cl_user_id
        FOREIGN KEY (user_id) REFERENCES users(user_id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    INDEX idx_checkin_user_time (user_id, checkin_at)
) ENGINE=InnoDB COMMENT='User login and check-in activity log';


-- -----------------------------------------------------------------------------
-- 1.11 EXECUTION_JOBS
--      One row per asset-beneficiary delivery unit. Queued on death
--      confirmation. Status respects per-asset contact verification flag.
-- -----------------------------------------------------------------------------
CREATE TABLE execution_jobs (
    job_id          INT          NOT NULL AUTO_INCREMENT,
    user_id         INT          NOT NULL,
    asset_id        INT          NOT NULL,
    beneficiary_id  INT          NOT NULL,
    status          ENUM(
                      'pending',
                      'awaiting_contact_verify',
                      'in_progress',
                      'completed',
                      'failed',
                      'cancelled'
                    ) NOT NULL DEFAULT 'pending',
    attempt_count   INT          NOT NULL DEFAULT 0,
    max_attempts    INT          NOT NULL DEFAULT 3,
    error_message   TEXT             NULL DEFAULT NULL,
    scheduled_at    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    last_attempted_at DATETIME       NULL DEFAULT NULL,
    executed_at     DATETIME         NULL DEFAULT NULL,

    CONSTRAINT pk_execution_jobs  PRIMARY KEY (job_id),
    CONSTRAINT fk_ej_user_id
        FOREIGN KEY (user_id)       REFERENCES users(user_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_ej_asset_id
        FOREIGN KEY (asset_id)      REFERENCES digital_assets(asset_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_ej_beneficiary_id
        FOREIGN KEY (beneficiary_id) REFERENCES beneficiaries(beneficiary_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT ck_ej_attempts
        CHECK (attempt_count >= 0 AND max_attempts >= 1),
    INDEX idx_ej_status       (status),
    INDEX idx_ej_user_status  (user_id, status)
) ENGINE=InnoDB COMMENT='Execution jobs: one per asset-beneficiary delivery unit';


-- -----------------------------------------------------------------------------
-- 1.12 STATUS_TRANSITIONS
--      Immutable record of every account status change.
--      Never updated after insert — permanent audit trail.
-- -----------------------------------------------------------------------------
CREATE TABLE status_transitions (
    transition_id    INT          NOT NULL AUTO_INCREMENT,
    user_id          INT          NOT NULL,
    from_status      ENUM(
                       'Active',
                       'Flagged',
                       'Pending_Verification',
                       'Deceased',
                       'Executed'
                     )            NOT NULL,
    to_status        ENUM(
                       'Active',
                       'Flagged',
                       'Pending_Verification',
                       'Deceased',
                       'Executed'
                     )            NOT NULL,
    rule_id          INT              NULL DEFAULT NULL,
    verification_id  INT              NULL DEFAULT NULL,
    triggered_by     VARCHAR(100) NOT NULL DEFAULT 'system',
    notes            TEXT             NULL DEFAULT NULL,
    transitioned_at  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT pk_status_transitions  PRIMARY KEY (transition_id),
    CONSTRAINT fk_st_user_id
        FOREIGN KEY (user_id)          REFERENCES users(user_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_st_rule_id
        FOREIGN KEY (rule_id)          REFERENCES death_trigger_rules(rule_id)
        ON DELETE SET NULL ON UPDATE CASCADE,
    CONSTRAINT fk_st_verification_id
        FOREIGN KEY (verification_id)  REFERENCES death_verifications(verification_id)
        ON DELETE SET NULL ON UPDATE CASCADE,
    INDEX idx_st_user_time (user_id, transitioned_at)
) ENGINE=InnoDB COMMENT='Immutable audit trail of all account status changes';


-- -----------------------------------------------------------------------------
-- 1.13 AUDIT_LOG
--      Row-level change log auto-populated by triggers on sensitive tables.
--      Captures old_values and new_values as JSON snapshots.
-- -----------------------------------------------------------------------------
CREATE TABLE audit_log (
    log_id       INT          NOT NULL AUTO_INCREMENT,
    user_id      INT              NULL DEFAULT NULL,
    table_name   VARCHAR(100) NOT NULL,
    record_id    INT          NOT NULL,
    action       ENUM('INSERT', 'UPDATE', 'DELETE') NOT NULL,
    old_values   JSON             NULL DEFAULT NULL,
    new_values   JSON             NULL DEFAULT NULL,
    changed_by   VARCHAR(100) NOT NULL DEFAULT 'system',
    client_type  ENUM('web', 'socket_client', 'api', 'scheduler', 'trigger')
                              NOT NULL DEFAULT 'trigger',
    ip_address   VARCHAR(45)      NULL DEFAULT NULL,
    changed_at   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT pk_audit_log  PRIMARY KEY (log_id),
    CONSTRAINT fk_al_user_id
        FOREIGN KEY (user_id) REFERENCES users(user_id)
        ON DELETE SET NULL ON UPDATE CASCADE,
    INDEX idx_al_table_record (table_name, record_id),
    INDEX idx_al_user_time    (user_id, changed_at)
) ENGINE=InnoDB COMMENT='Row-level audit log for all sensitive table changes';

SET FOREIGN_KEY_CHECKS = 1;


-- =============================================================================
-- 2. TRIGGERS
-- =============================================================================

DELIMITER $$

-- -----------------------------------------------------------------------------
-- 2.1 trg_after_death_confirmed
--     Fires when a user's account_status changes to 'Deceased'.
--     Queues one execution_job per asset-beneficiary pair.
--     Assets with require_contact_verify=1 get status 'awaiting_contact_verify'.
--     Assets with require_contact_verify=0 get status 'pending'.
--     Also inserts a status_transitions record.
-- -----------------------------------------------------------------------------
CREATE TRIGGER trg_after_death_confirmed
AFTER UPDATE ON users
FOR EACH ROW
BEGIN
    IF NEW.account_status = 'Deceased' AND OLD.account_status != 'Deceased' THEN

        -- Queue execution jobs with correct status per asset verification flag
        INSERT INTO execution_jobs (
            user_id, asset_id, beneficiary_id, status, scheduled_at
        )
        SELECT
            a.user_id,
            ab.asset_id,
            ab.beneficiary_id,
            IF(a.require_contact_verify = 1, 'awaiting_contact_verify', 'pending'),
            NOW()
        FROM asset_beneficiaries ab
        JOIN digital_assets a ON ab.asset_id = a.asset_id
        WHERE a.user_id     = NEW.user_id
          AND a.include_in_estate = 1
          AND a.status      = 'active';

        -- Mark those assets as pending_execution
        UPDATE digital_assets
        SET status = 'pending_execution'
        WHERE user_id = NEW.user_id
          AND include_in_estate = 1
          AND status = 'active';

        -- Log the status transition
        INSERT INTO status_transitions (
            user_id, from_status, to_status, triggered_by, notes
        )
        VALUES (
            NEW.user_id,
            OLD.account_status,
            'Deceased',
            'death_verification_confirmed',
            'Quorum reached. Execution jobs queued.'
        );

    END IF;
END$$


-- -----------------------------------------------------------------------------
-- 2.2 trg_after_user_flagged
--     Fires when account_status changes to 'Flagged'.
--     Logs the transition automatically.
-- -----------------------------------------------------------------------------
CREATE TRIGGER trg_after_user_flagged
AFTER UPDATE ON users
FOR EACH ROW
BEGIN
    IF NEW.account_status = 'Flagged' AND OLD.account_status = 'Active' THEN
        INSERT INTO status_transitions (
            user_id, from_status, to_status, triggered_by, notes
        )
        VALUES (
            NEW.user_id,
            'Active',
            'Flagged',
            'event_scheduler',
            CONCAT('Inactivity threshold exceeded. Days since last check-in: ',
                   DATEDIFF(NOW(), OLD.last_checkin_at))
        );
    END IF;
END$$


-- -----------------------------------------------------------------------------
-- 2.3 trg_after_user_reactivated
--     Fires when account_status returns to 'Active' from 'Flagged'.
--     Logs the cancellation/reactivation.
-- -----------------------------------------------------------------------------
CREATE TRIGGER trg_after_user_reactivated
AFTER UPDATE ON users
FOR EACH ROW
BEGIN
    IF NEW.account_status = 'Active' AND OLD.account_status IN ('Flagged', 'Pending_Verification') THEN
        INSERT INTO status_transitions (
            user_id, from_status, to_status, triggered_by, notes
        )
        VALUES (
            NEW.user_id,
            OLD.account_status,
            'Active',
            'user_login',
            'User logged in. Death verification process cancelled and account reactivated.'
        );
    END IF;
END$$


-- -----------------------------------------------------------------------------
-- 2.4 trg_audit_digital_assets_update
--     Fires on UPDATE of digital_assets. Writes old/new JSON to audit_log.
-- -----------------------------------------------------------------------------
CREATE TRIGGER trg_audit_digital_assets_update
AFTER UPDATE ON digital_assets
FOR EACH ROW
BEGIN
    INSERT INTO audit_log (
        user_id, table_name, record_id, action, old_values, new_values, changed_by
    )
    VALUES (
        NEW.user_id,
        'digital_assets',
        NEW.asset_id,
        'UPDATE',
        JSON_OBJECT(
            'asset_name',             OLD.asset_name,
            'asset_type',             OLD.asset_type,
            'status',                 OLD.status,
            'require_contact_verify', OLD.require_contact_verify,
            'include_in_estate',      OLD.include_in_estate
        ),
        JSON_OBJECT(
            'asset_name',             NEW.asset_name,
            'asset_type',             NEW.asset_type,
            'status',                 NEW.status,
            'require_contact_verify', NEW.require_contact_verify,
            'include_in_estate',      NEW.include_in_estate
        ),
        'trigger'
    );
END$$


-- -----------------------------------------------------------------------------
-- 2.5 trg_audit_users_update
--     Fires on UPDATE of users. Captures status and checkin changes.
-- -----------------------------------------------------------------------------
CREATE TRIGGER trg_audit_users_update
AFTER UPDATE ON users
FOR EACH ROW
BEGIN
    IF OLD.account_status != NEW.account_status
       OR OLD.last_checkin_at != NEW.last_checkin_at THEN
        INSERT INTO audit_log (
            user_id, table_name, record_id, action, old_values, new_values, changed_by
        )
        VALUES (
            NEW.user_id,
            'users',
            NEW.user_id,
            'UPDATE',
            JSON_OBJECT(
                'account_status',  OLD.account_status,
                'last_checkin_at', OLD.last_checkin_at
            ),
            JSON_OBJECT(
                'account_status',  NEW.account_status,
                'last_checkin_at', NEW.last_checkin_at
            ),
            'trigger'
        );
    END IF;
END$$


-- -----------------------------------------------------------------------------
-- 2.6 trg_checkin_update_user
--     Fires on INSERT into checkin_log.
--     Updates users.last_checkin_at automatically.
--     If user was Flagged, resets to Active (dead man's switch cancelled).
-- -----------------------------------------------------------------------------
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
END$$


DELIMITER ;


-- =============================================================================
-- 3. VIEWS
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 3.1 pending_executions
--     All execution jobs not yet completed.
--     Shows per-asset contact verify flag and share percentages.
-- -----------------------------------------------------------------------------
CREATE VIEW pending_executions AS
SELECT
    u.user_id,
    u.full_name                              AS user_name,
    a.asset_id,
    a.asset_name,
    a.asset_type,
    a.require_contact_verify,
    b.beneficiary_id,
    b.full_name                              AS beneficiary_name,
    b.email                                  AS beneficiary_email,
    ab.share_percentage,
    ab.notification_method,
    j.job_id,
    j.status                                 AS job_status,
    j.attempt_count,
    j.max_attempts,
    j.scheduled_at,
    j.last_attempted_at
FROM execution_jobs j
JOIN digital_assets       a  ON j.asset_id       = a.asset_id
JOIN users                u  ON j.user_id         = u.user_id
JOIN beneficiaries        b  ON j.beneficiary_id  = b.beneficiary_id
JOIN asset_beneficiaries  ab ON ab.asset_id       = j.asset_id
                             AND ab.beneficiary_id = j.beneficiary_id
WHERE j.status IN ('pending', 'awaiting_contact_verify', 'failed');


-- -----------------------------------------------------------------------------
-- 3.2 user_estate_summary
--     Per-user summary of registered assets, beneficiaries, and job counts.
-- -----------------------------------------------------------------------------
CREATE VIEW user_estate_summary AS
SELECT
    u.user_id,
    u.full_name,
    u.email,
    u.account_status,
    u.last_checkin_at,
    u.checkin_interval_days,
    DATEDIFF(NOW(), u.last_checkin_at)         AS days_since_checkin,
    COUNT(DISTINCT da.asset_id)                AS total_assets,
    COUNT(DISTINCT ab.beneficiary_id)          AS total_beneficiaries,
    SUM(da.require_contact_verify)             AS assets_requiring_contact_verify,
    COUNT(DISTINCT ej.job_id)                  AS total_execution_jobs,
    SUM(ej.status = 'completed')               AS completed_jobs,
    SUM(ej.status IN ('pending',
        'awaiting_contact_verify', 'failed'))  AS pending_jobs
FROM users u
LEFT JOIN digital_assets      da  ON da.user_id  = u.user_id
LEFT JOIN asset_beneficiaries ab  ON ab.asset_id = da.asset_id
LEFT JOIN execution_jobs      ej  ON ej.user_id  = u.user_id
GROUP BY
    u.user_id, u.full_name, u.email, u.account_status,
    u.last_checkin_at, u.checkin_interval_days;


-- -----------------------------------------------------------------------------
-- 3.3 death_verification_status
--     Active or recent verification events with confirmation progress.
-- -----------------------------------------------------------------------------
CREATE VIEW death_verification_status AS
SELECT
    dv.verification_id,
    u.full_name                                 AS user_name,
    u.account_status,
    dv.status                                   AS verification_status,
    dv.trigger_source,
    tc.full_name                                AS initiated_by_name,
    dv.confirmations_received,
    dv.confirmations_required,
    ROUND(
        (dv.confirmations_received / dv.confirmations_required) * 100, 1
    )                                           AS confirmation_pct,
    dv.initiated_at,
    dv.expires_at,
    dv.confirmed_at,
    DATEDIFF(dv.expires_at, NOW())              AS days_until_expiry
FROM death_verifications dv
JOIN  users           u   ON dv.user_id      = u.user_id
LEFT JOIN trusted_contacts tc ON dv.initiated_by = tc.contact_id
WHERE dv.status IN ('initiated', 'awaiting_quorum');


-- =============================================================================
-- 4. STORED PROCEDURES
-- =============================================================================

DELIMITER $$

-- -----------------------------------------------------------------------------
-- 4.1 sp_register_asset
--     Registers a new digital asset and optionally adds a vault entry.
--     Parameters: user_id, asset_name, type, instructions,
--                 require_contact_verify, field_name, encrypted_value, iv
-- -----------------------------------------------------------------------------
CREATE PROCEDURE sp_register_asset(
    IN p_user_id               INT,
    IN p_asset_name            VARCHAR(200),
    IN p_asset_type            VARCHAR(50),
    IN p_instructions          TEXT,
    IN p_require_contact_verify TINYINT,
    IN p_field_name            VARCHAR(100),
    IN p_encrypted_value       TEXT,
    IN p_iv                    VARCHAR(64)
)
BEGIN
    DECLARE v_asset_id INT;

    INSERT INTO digital_assets (
        user_id, asset_name, asset_type,
        instructions, require_contact_verify
    )
    VALUES (
        p_user_id, p_asset_name, p_asset_type,
        p_instructions, p_require_contact_verify
    );

    SET v_asset_id = LAST_INSERT_ID();

    -- Only insert vault entry if credential provided
    IF p_field_name IS NOT NULL AND p_encrypted_value IS NOT NULL THEN
        INSERT INTO vault_entries (asset_id, field_name, encrypted_value, iv)
        VALUES (v_asset_id, p_field_name, p_encrypted_value, p_iv);
    END IF;

    SELECT v_asset_id AS new_asset_id;
END$$


-- -----------------------------------------------------------------------------
-- 4.2 sp_confirm_death_quorum
--     Called when a trusted contact submits their confirmation.
--     Increments the confirmation count. If quorum is met, updates
--     verification to 'confirmed' and flips user to 'Deceased'.
-- -----------------------------------------------------------------------------
CREATE PROCEDURE sp_confirm_death_quorum(
    IN p_verification_id INT,
    IN p_contact_id      INT,
    IN p_token           VARCHAR(100),
    IN p_ip_address      VARCHAR(45)
)
BEGIN
    DECLARE v_user_id               INT;
    DECLARE v_confirmations_recv    INT;
    DECLARE v_confirmations_req     INT;
    DECLARE v_status                VARCHAR(30);

    -- Record the individual confirmation
    UPDATE contact_confirmations
    SET action       = 'confirmed',
        token_used   = p_token,
        ip_address   = p_ip_address,
        responded_at = NOW()
    WHERE verification_id = p_verification_id
      AND contact_id      = p_contact_id;

    -- Increment count on the verification record
    UPDATE death_verifications
    SET confirmations_received = confirmations_received + 1
    WHERE verification_id = p_verification_id;

    -- Check if quorum is now reached
    SELECT user_id, confirmations_received, confirmations_required, status
    INTO v_user_id, v_confirmations_recv, v_confirmations_req, v_status
    FROM death_verifications
    WHERE verification_id = p_verification_id;

    IF v_confirmations_recv >= v_confirmations_req AND v_status != 'confirmed' THEN

        -- Confirm the verification
        UPDATE death_verifications
        SET status       = 'confirmed',
            confirmed_at = NOW()
        WHERE verification_id = p_verification_id;

        -- Flip the user to Deceased (triggers trg_after_death_confirmed)
        UPDATE users
        SET account_status = 'Deceased'
        WHERE user_id = v_user_id;

        SELECT 'QUORUM_REACHED' AS result, v_user_id AS user_id;
    ELSE
        SELECT 'CONFIRMATION_RECORDED' AS result, v_user_id AS user_id;
    END IF;
END$$


-- -----------------------------------------------------------------------------
-- 4.3 sp_process_execution_job
--     Simulates processing one execution job.
--     Marks it completed on success or increments attempt_count on failure.
-- -----------------------------------------------------------------------------
CREATE PROCEDURE sp_process_execution_job(
    IN p_job_id    INT,
    IN p_success   TINYINT,
    IN p_error_msg TEXT
)
BEGIN
    IF p_success = 1 THEN
        UPDATE execution_jobs
        SET status           = 'completed',
            executed_at      = NOW(),
            last_attempted_at = NOW()
        WHERE job_id = p_job_id;
    ELSE
        UPDATE execution_jobs
        SET attempt_count     = attempt_count + 1,
            last_attempted_at = NOW(),
            error_message     = p_error_msg,
            status            = IF(attempt_count + 1 >= max_attempts, 'failed', 'pending')
        WHERE job_id = p_job_id;
    END IF;
END$$


DELIMITER ;


-- =============================================================================
-- 5. EVENTS (MySQL Event Scheduler)
-- =============================================================================

SET GLOBAL event_scheduler = ON;

DELIMITER $$

-- -----------------------------------------------------------------------------
-- 5.1 evt_daily_inactivity_check
--     Runs every day at 02:00 AM.
--     Transitions Active users to Flagged when their inactivity threshold
--     is exceeded based on their configured death_trigger_rule.
-- -----------------------------------------------------------------------------
CREATE EVENT evt_daily_inactivity_check
ON SCHEDULE EVERY 1 DAY
STARTS (CURRENT_DATE + INTERVAL 1 DAY + INTERVAL 2 HOUR)
COMMENT 'Daily check: flags users who exceeded their inactivity threshold'
DO
BEGIN
    UPDATE users u
    JOIN death_trigger_rules r
        ON  r.user_id   = u.user_id
        AND r.is_active = 1
    SET
        u.account_status = 'Flagged',
        u.updated_at     = NOW()
    WHERE
        u.account_status = 'Active'
        AND r.rule_type  IN ('inactivity_timer', 'combined_and')
        AND r.inactivity_days IS NOT NULL
        AND DATEDIFF(NOW(), u.last_checkin_at) > r.inactivity_days;
END$$


-- -----------------------------------------------------------------------------
-- 5.2 evt_expire_stale_verifications
--     Runs every day at 03:00 AM.
--     Expires death verifications that passed their deadline without quorum.
--     Resets the associated user back to Active.
-- -----------------------------------------------------------------------------
CREATE EVENT evt_expire_stale_verifications
ON SCHEDULE EVERY 1 DAY
STARTS (CURRENT_DATE + INTERVAL 1 DAY + INTERVAL 3 HOUR)
COMMENT 'Expire verifications that missed their quorum deadline'
DO
BEGIN
    -- Expire timed-out verifications
    UPDATE death_verifications
    SET status = 'expired'
    WHERE status   IN ('initiated', 'awaiting_quorum')
      AND expires_at IS NOT NULL
      AND expires_at < NOW();

    -- Reset those users back to Active
    UPDATE users u
    JOIN death_verifications dv ON dv.user_id = u.user_id
    SET u.account_status = 'Active'
    WHERE dv.status             = 'expired'
      AND u.account_status      = 'Pending_Verification';
END$$


DELIMITER ;


-- =============================================================================
-- 6. SAMPLE DATA (INSERT)
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 6.1 Users (mix of lifecycle states for testing)
-- -----------------------------------------------------------------------------
INSERT INTO users (full_name, email, password_hash, date_of_birth, phone, account_status, last_checkin_at, checkin_interval_days) VALUES
('Hanzala Muhammad',   'hanzala@email.com',   '$2b$12$abc123hashedpassword1', '1995-03-15', '+92-300-1111111', 'Active',              NOW() - INTERVAL 5  DAY, 90),
('Sara Ahmed',         'sara@email.com',       '$2b$12$abc123hashedpassword2', '1988-07-22', '+92-301-2222222', 'Flagged',             NOW() - INTERVAL 95 DAY, 90),
('Bilal Khan',         'bilal@email.com',      '$2b$12$abc123hashedpassword3', '1975-11-08', '+92-302-3333333', 'Deceased',            NOW() - INTERVAL 200 DAY, 60),
('Ayesha Siddiqui',    'ayesha@email.com',     '$2b$12$abc123hashedpassword4', '1990-01-30', '+92-303-4444444', 'Active',              NOW() - INTERVAL 10 DAY, 120),
('Zain Ul Abidin',     'zain@email.com',       '$2b$12$abc123hashedpassword5', '1982-09-14', '+92-304-5555555', 'Pending_Verification', NOW() - INTERVAL 70 DAY, 60),
('Fatima Malik',       'fatima@email.com',     '$2b$12$abc123hashedpassword6', '1993-06-05', '+92-305-6666666', 'Executed',            NOW() - INTERVAL 400 DAY, 30),
('Omar Sheikh',        'omar@email.com',       '$2b$12$abc123hashedpassword7', '1970-12-20', '+92-306-7777777', 'Active',              NOW() - INTERVAL 2  DAY, 180);


-- -----------------------------------------------------------------------------
-- 6.2 Death Trigger Rules
-- -----------------------------------------------------------------------------
INSERT INTO death_trigger_rules (user_id, rule_type, inactivity_days, quorum_required, grace_period_days, logic_operator, is_active) VALUES
(1, 'combined_and',      60, 2, 7,  'AND', 1),  -- Hanzala: both inactivity AND quorum
(2, 'inactivity_timer',  90, NULL, 7, NULL, 1), -- Sara: inactivity only
(3, 'quorum_vote',     NULL, 3,    7, NULL, 0), -- Bilal: quorum (already deceased)
(4, 'inactivity_timer', 120, NULL, 14, NULL, 1),-- Ayesha: 120 day inactivity
(5, 'combined_and',      60, 1,    7, 'AND', 1),-- Zain: combined
(6, 'inactivity_timer',  30, NULL, 7, NULL, 0), -- Fatima: already executed
(7, 'manual_declaration',NULL, NULL, 30, NULL, 1); -- Omar: manual declaration only


-- -----------------------------------------------------------------------------
-- 6.3 Trusted Contacts
-- -----------------------------------------------------------------------------
INSERT INTO trusted_contacts (user_id, full_name, email, phone, verification_token, verification_status, priority_order, verified_at) VALUES
(1, 'Ali Muhammad',       'ali@email.com',       '+92-311-1111111', 'tok_ali_001',   'verified', 1, NOW() - INTERVAL 30 DAY),
(1, 'Mariam Khan',        'mariam@email.com',     '+92-312-1111111', 'tok_mariam_001','verified', 2, NOW() - INTERVAL 28 DAY),
(2, 'Ahmed Raza',         'ahmed@email.com',      '+92-313-2222222', 'tok_ahmed_001', 'verified', 1, NOW() - INTERVAL 60 DAY),
(3, 'Nadia Bilal',        'nadia@email.com',      '+92-314-3333333', 'tok_nadia_001', 'verified', 1, NOW() - INTERVAL 90 DAY),
(3, 'Tariq Hassan',       'tariq@email.com',      '+92-315-3333333', 'tok_tariq_001', 'verified', 2, NOW() - INTERVAL 85 DAY),
(3, 'Sana Bilal',         'sana@email.com',       '+92-316-3333333', 'tok_sana_001',  'verified', 3, NOW() - INTERVAL 80 DAY),
(5, 'Usman Zain',         'usman@email.com',      '+92-317-5555555', 'tok_usman_001', 'verified', 1, NOW() - INTERVAL 45 DAY),
(7, 'Khalid Sheikh',      'khalid@email.com',     '+92-318-7777777', 'tok_khalid_001','verified', 1, NOW() - INTERVAL 10 DAY);


-- -----------------------------------------------------------------------------
-- 6.4 Beneficiaries
-- -----------------------------------------------------------------------------
INSERT INTO beneficiaries (full_name, email, phone, relationship, verification_token, verification_status, verified_at) VALUES
('Ali Muhammad',      'ali@email.com',       '+92-311-1111111', 'Brother',       'ben_tok_001', 'verified', NOW() - INTERVAL 25 DAY),
('Mariam Khan',       'mariam@email.com',     '+92-312-1111111', 'Sister',        'ben_tok_002', 'verified', NOW() - INTERVAL 22 DAY),
('Nadia Bilal',       'nadia@email.com',      '+92-314-3333333', 'Wife',          'ben_tok_003', 'verified', NOW() - INTERVAL 80 DAY),
('Tariq Hassan',      'tariq@email.com',      '+92-315-3333333', 'Son',           'ben_tok_004', 'verified', NOW() - INTERVAL 75 DAY),
('Sana Bilal',        'sana@email.com',       '+92-316-3333333', 'Daughter',      'ben_tok_005', 'verified', NOW() - INTERVAL 70 DAY),
('Ayesha Foundation', 'foundation@email.com', '+92-319-0000000', 'Charity',       'ben_tok_006', 'verified', NOW() - INTERVAL 50 DAY),
('Usman Zain',        'usman@email.com',      '+92-317-5555555', 'Son',           'ben_tok_007', 'verified', NOW() - INTERVAL 40 DAY),
('Khalid Sheikh',     'khalid@email.com',     '+92-318-7777777', 'Son',           'ben_tok_008', 'verified', NOW() - INTERVAL 5  DAY);


-- -----------------------------------------------------------------------------
-- 6.5 Digital Assets
-- -----------------------------------------------------------------------------
INSERT INTO digital_assets (user_id, asset_name, asset_type, description, instructions, require_contact_verify, status) VALUES
-- Hanzala's assets
(1, 'HBL Bank Account',       'bank_account',   'Main savings account at HBL',         'Transfer balance equally to Ali and Mariam. Contact branch manager.',                1, 'active'),
(1, 'Bitcoin Wallet',          'crypto_wallet',  '0.5 BTC cold storage wallet',         'Import seed phrase into a hardware wallet. Split 60/40 between Ali and charity.',   1, 'active'),
(1, 'Gmail Personal',          'email',          'Personal gmail account',              'Download all emails. Delete account after 90 days.',                                0, 'active'),
(1, 'Farewell Letter',         'other',          'Final message to family',             'Send this email to all family members immediately.',                                 0, 'active'),
-- Bilal's assets (deceased - used for execution testing)
(3, 'Meezan Bank Account',     'bank_account',   'Joint savings account',               'Transfer to Nadia. Contact bank with death certificate.',                           1, 'pending_execution'),
(3, 'Ethereum Wallet',         'crypto_wallet',  '2.3 ETH in MetaMask',                 'Split equally among Nadia, Tariq, and Sana.',                                      1, 'pending_execution'),
(3, 'Google Drive Files',      'file_storage',   '50GB family photos and documents',    'Download everything. Share family photos with Nadia. Delete personal files.',       0, 'pending_execution'),
-- Sara's assets (flagged)
(2, 'MCB Savings Account',     'bank_account',   'MCB savings',                         'Transfer all funds to Ahmed.',                                                      1, 'active'),
-- Ayesha's asset
(4, 'Netflix Subscription',    'subscription',   'Family Netflix account',              'Cancel subscription. Share downloaded content links with family.',                  0, 'active'),
-- Zain's asset (pending verification)
(5, 'Coinbase Account',        'crypto_wallet',  'ETH and USDT on Coinbase',            'Transfer to Usman. Two-factor auth code needed.',                                   1, 'active');


-- -----------------------------------------------------------------------------
-- 6.6 Vault Entries (simulated encrypted credentials)
-- -----------------------------------------------------------------------------
INSERT INTO vault_entries (asset_id, field_name, encrypted_value, iv, encryption_algo) VALUES
(1, 'account_number',  'U2FsdGVkX19abc123HBL456',           'iv_hbl_001', 'AES-256-CBC'),
(1, 'online_banking_password', 'U2FsdGVkX19xyz789HBLpass', 'iv_hbl_002', 'AES-256-CBC'),
(2, 'seed_phrase',     'U2FsdGVkX19BTC24wordSeedPhrase',     'iv_btc_001', 'AES-256-CBC'),
(2, 'wallet_password', 'U2FsdGVkX19BTCwalletpass',           'iv_btc_002', 'AES-256-CBC'),
(3, 'email_password',  'U2FsdGVkX19gmailPasswordHash',       'iv_gml_001', 'AES-256-CBC'),
(3, 'recovery_email',  'U2FsdGVkX19gmailRecovery',           'iv_gml_002', 'AES-256-CBC'),
(4, 'letter_content',  'U2FsdGVkX19FarewellLetterEncrypted', 'iv_lttr_01', 'AES-256-CBC'),
(5, 'account_number',  'U2FsdGVkX19MeezanAccNum',            'iv_mzn_001', 'AES-256-CBC'),
(6, 'seed_phrase',     'U2FsdGVkX19ETHseedPhrase24words',    'iv_eth_001', 'AES-256-CBC'),
(6, 'metamask_password','U2FsdGVkX19MetaMaskPass',           'iv_eth_002', 'AES-256-CBC'),
(8, 'account_number',  'U2FsdGVkX19MCBaccountNum',           'iv_mcb_001', 'AES-256-CBC'),
(10,'api_key',         'U2FsdGVkX19CoinbaseAPIkey',          'iv_cb_001',  'AES-256-CBC');


-- -----------------------------------------------------------------------------
-- 6.7 Asset Beneficiaries (with share percentages summing to 100 per asset)
-- -----------------------------------------------------------------------------
INSERT INTO asset_beneficiaries (asset_id, beneficiary_id, share_percentage, special_instructions, notification_method) VALUES
-- Asset 1 (HBL): Ali 50%, Mariam 50%
(1, 1, 50.00, 'Ali receives 50% of the balance.',     'email'),
(1, 2, 50.00, 'Mariam receives 50% of the balance.',  'email'),
-- Asset 2 (Bitcoin): Ali 60%, Charity 40%
(2, 1, 60.00, 'Ali receives the private keys.',        'email'),
(2, 6, 40.00, 'Donate 40% value to Ayesha Foundation.','email'),
-- Asset 3 (Gmail): Mariam 100%
(3, 2, 100.00,'Mariam handles the account.',           'email'),
-- Asset 4 (Farewell Letter): Ali 50%, Mariam 50%
(4, 1, 50.00, 'Send this message to Ali.',             'email'),
(4, 2, 50.00, 'Send this message to Mariam.',          'email'),
-- Asset 5 (Meezan): Nadia 100%
(5, 3, 100.00,'Full transfer to Nadia.',               'both'),
-- Asset 6 (Ethereum): Nadia 40%, Tariq 30%, Sana 30%
(6, 3, 40.00, 'Nadia receives 40% ETH.',               'email'),
(6, 4, 30.00, 'Tariq receives 30% ETH.',               'email'),
(6, 5, 30.00, 'Sana receives 30% ETH.',                'email'),
-- Asset 7 (Google Drive): Nadia 100%
(7, 3, 100.00,'All files go to Nadia.',                'both'),
-- Asset 8 (MCB): Ahmed 100%
(8, 1, 100.00,'Full transfer to Ahmed.',               'email'),
-- Asset 9 (Netflix): Ayesha 100% (placeholder, no real beneficiary needed)
(9, 2, 100.00,'Cancel and notify.',                    'email'),
-- Asset 10 (Coinbase): Usman 100%
(10, 7, 100.00,'Transfer all holdings to Usman.',     'both');


-- -----------------------------------------------------------------------------
-- 6.8 Checkin Log
-- -----------------------------------------------------------------------------
INSERT INTO checkin_log (user_id, checkin_type, ip_address, client_type, checkin_at) VALUES
(1, 'login',       '192.168.1.10', 'web',           NOW() - INTERVAL 5  DAY),
(1, 'manual_ping', '192.168.1.10', 'web',           NOW() - INTERVAL 2  DAY),
(2, 'login',       '192.168.1.20', 'web',           NOW() - INTERVAL 95 DAY),
(3, 'login',       '10.0.0.30',    'web',           NOW() - INTERVAL 200 DAY),
(4, 'login',       '172.16.0.40',  'socket_client', NOW() - INTERVAL 10 DAY),
(5, 'login',       '192.168.2.50', 'web',           NOW() - INTERVAL 70 DAY),
(7, 'login',       '192.168.3.70', 'web',           NOW() - INTERVAL 2  DAY);


-- -----------------------------------------------------------------------------
-- 6.9 Death Verifications
-- -----------------------------------------------------------------------------
INSERT INTO death_verifications (user_id, initiated_by, status, confirmations_received, confirmations_required, trigger_source, initiated_at, expires_at) VALUES
-- Bilal: confirmed (3 contacts confirmed)
(3, 4, 'confirmed', 3, 3, 'contact_report',  NOW() - INTERVAL 10 DAY, NOW() + INTERVAL 20 DAY),
-- Sara: initiated but not yet quorum
(2, 3, 'awaiting_quorum', 0, 1, 'inactivity_timer', NOW() - INTERVAL 3 DAY,  NOW() + INTERVAL 27 DAY),
-- Zain: initiated
(5, 7, 'initiated', 0, 1, 'inactivity_timer', NOW() - INTERVAL 1 DAY, NOW() + INTERVAL 29 DAY);


-- -----------------------------------------------------------------------------
-- 6.10 Contact Confirmations
-- -----------------------------------------------------------------------------
INSERT INTO contact_confirmations (verification_id, contact_id, action, token_used, ip_address, responded_at) VALUES
-- Bilal's verification (confirmed by all 3 contacts)
(1, 4, 'confirmed', 'conf_tok_nadia_001',  '10.1.1.41', NOW() - INTERVAL 9  DAY),
(1, 5, 'confirmed', 'conf_tok_tariq_001',  '10.1.1.42', NOW() - INTERVAL 8  DAY),
(1, 6, 'confirmed', 'conf_tok_sana_001',   '10.1.1.43', NOW() - INTERVAL 7  DAY),
-- Sara's verification (no response yet)
(2, 3, 'no_response', NULL, NULL, NULL),
-- Zain's verification (no response yet)
(3, 7, 'no_response', NULL, NULL, NULL);


-- -----------------------------------------------------------------------------
-- 6.11 Execution Jobs (Bilal's — triggered by trg_after_death_confirmed)
--      Manually inserting here since the trigger fires on UPDATE, not INSERT.
--      In production these are auto-created by the trigger.
-- -----------------------------------------------------------------------------
INSERT INTO execution_jobs (user_id, asset_id, beneficiary_id, status, attempt_count, scheduled_at) VALUES
-- Asset 5 (Meezan - requires contact verify): Nadia
(3, 5, 3, 'awaiting_contact_verify', 0, NOW() - INTERVAL 9 DAY),
-- Asset 6 (Ethereum - requires contact verify): 3 beneficiaries
(3, 6, 3, 'awaiting_contact_verify', 0, NOW() - INTERVAL 9 DAY),
(3, 6, 4, 'awaiting_contact_verify', 0, NOW() - INTERVAL 9 DAY),
(3, 6, 5, 'awaiting_contact_verify', 0, NOW() - INTERVAL 9 DAY),
-- Asset 7 (Google Drive - no contact verify): Nadia
(3, 7, 3, 'completed', 1, NOW() - INTERVAL 9 DAY),
-- Fatima's (executed user - all completed for reference)
(6, NULL, NULL, 'completed', 1, NOW() - INTERVAL 390 DAY);


-- -----------------------------------------------------------------------------
-- 6.12 Status Transitions (historical records)
-- -----------------------------------------------------------------------------
INSERT INTO status_transitions (user_id, from_status, to_status, triggered_by, notes, transitioned_at) VALUES
(2, 'Active',  'Flagged',              'event_scheduler',              'Inactivity threshold exceeded. Days since last check-in: 95', NOW() - INTERVAL 5 DAY),
(3, 'Active',  'Flagged',              'event_scheduler',              'Inactivity threshold exceeded. Days since last check-in: 140', NOW() - INTERVAL 60 DAY),
(3, 'Flagged', 'Pending_Verification', 'contact_report',               'Trusted contact Nadia filed death declaration.',              NOW() - INTERVAL 10 DAY),
(3, 'Pending_Verification','Deceased', 'death_verification_confirmed', 'Quorum of 3 contacts reached. Execution jobs queued.',        NOW() - INTERVAL 9  DAY),
(5, 'Active',  'Flagged',              'event_scheduler',              'Inactivity threshold exceeded.',                              NOW() - INTERVAL 2  DAY),
(5, 'Flagged', 'Pending_Verification', 'contact_report',               'Contact Usman filed declaration.',                           NOW() - INTERVAL 1  DAY),
(6, 'Active',  'Flagged',              'event_scheduler',              'Inactivity threshold exceeded.',                             NOW() - INTERVAL 400 DAY),
(6, 'Flagged', 'Pending_Verification', 'inactivity_timer',             'Quorum threshold met.',                                      NOW() - INTERVAL 395 DAY),
(6, 'Pending_Verification','Deceased', 'death_verification_confirmed', 'Confirmed.',                                                  NOW() - INTERVAL 390 DAY),
(6, 'Deceased','Executed',             'execution_engine',             'All asset jobs completed successfully.',                      NOW() - INTERVAL 380 DAY);


-- =============================================================================
-- 7. SELECT QUERIES (Demonstration & Analysis)
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Q1. Full estate overview for all users
-- -----------------------------------------------------------------------------
SELECT *
FROM user_estate_summary
ORDER BY user_id;


-- -----------------------------------------------------------------------------
-- Q2. All pending/failed execution jobs with full context
-- -----------------------------------------------------------------------------
SELECT *
FROM pending_executions
ORDER BY user_id, asset_type;


-- -----------------------------------------------------------------------------
-- Q3. Active death verification events with confirmation progress
-- -----------------------------------------------------------------------------
SELECT *
FROM death_verification_status;


-- -----------------------------------------------------------------------------
-- Q4. Inactivity report: users approaching their threshold
--     Shows days remaining before each user would be flagged
-- -----------------------------------------------------------------------------
SELECT
    u.user_id,
    u.full_name,
    u.account_status,
    u.checkin_interval_days                             AS threshold_days,
    DATEDIFF(NOW(), u.last_checkin_at)                  AS days_inactive,
    u.checkin_interval_days
        - DATEDIFF(NOW(), u.last_checkin_at)            AS days_remaining_before_flag,
    r.rule_type
FROM users u
JOIN death_trigger_rules r
    ON  r.user_id   = u.user_id
    AND r.is_active = 1
WHERE u.account_status = 'Active'
ORDER BY days_remaining_before_flag ASC;


-- -----------------------------------------------------------------------------
-- Q5. Asset distribution breakdown: which beneficiaries get what and how much
-- -----------------------------------------------------------------------------
SELECT
    u.full_name                         AS owner,
    da.asset_name,
    da.asset_type,
    da.require_contact_verify           AS needs_contact_verify,
    b.full_name                         AS beneficiary,
    b.relationship,
    ab.share_percentage,
    ab.notification_method
FROM digital_assets da
JOIN users               u   ON da.user_id        = u.user_id
JOIN asset_beneficiaries ab  ON ab.asset_id        = da.asset_id
JOIN beneficiaries       b   ON ab.beneficiary_id  = b.beneficiary_id
ORDER BY u.user_id, da.asset_id, ab.share_percentage DESC;


-- -----------------------------------------------------------------------------
-- Q6. Share percentage validation: flag any asset where shares do not sum to 100
-- -----------------------------------------------------------------------------
SELECT
    da.asset_id,
    da.asset_name,
    u.full_name                         AS owner,
    COUNT(ab.beneficiary_id)            AS beneficiary_count,
    SUM(ab.share_percentage)            AS total_shares,
    IF(ABS(SUM(ab.share_percentage) - 100.00) < 0.01,
       'OK', 'ERROR: SHARES DO NOT SUM TO 100') AS validation_status
FROM digital_assets da
JOIN users               u   ON da.user_id = u.user_id
JOIN asset_beneficiaries ab  ON ab.asset_id = da.asset_id
GROUP BY da.asset_id, da.asset_name, u.full_name
ORDER BY validation_status DESC, da.asset_id;


-- -----------------------------------------------------------------------------
-- Q7. Vault entries count per asset (confirms credentials are registered)
-- -----------------------------------------------------------------------------
SELECT
    da.asset_id,
    da.asset_name,
    da.asset_type,
    u.full_name                         AS owner,
    COUNT(ve.vault_id)                  AS credential_fields_stored
FROM digital_assets da
JOIN users         u   ON da.user_id = u.user_id
LEFT JOIN vault_entries ve ON ve.asset_id = da.asset_id
GROUP BY da.asset_id, da.asset_name, da.asset_type, u.full_name
ORDER BY u.user_id, da.asset_id;


-- -----------------------------------------------------------------------------
-- Q8. Execution progress for deceased users
--     Groups by user and shows completed vs awaiting vs failed counts
-- -----------------------------------------------------------------------------
SELECT
    u.user_id,
    u.full_name,
    COUNT(ej.job_id)                        AS total_jobs,
    SUM(ej.status = 'completed')            AS completed,
    SUM(ej.status = 'awaiting_contact_verify') AS awaiting_contact_verify,
    SUM(ej.status = 'pending')              AS pending,
    SUM(ej.status = 'failed')               AS failed,
    ROUND(
        SUM(ej.status = 'completed') / COUNT(ej.job_id) * 100, 1
    )                                       AS completion_pct
FROM users u
JOIN execution_jobs ej ON ej.user_id = u.user_id
WHERE u.account_status IN ('Deceased', 'Executed')
GROUP BY u.user_id, u.full_name
ORDER BY u.user_id;


-- -----------------------------------------------------------------------------
-- Q9. Full status transition history (lifecycle audit trail)
-- -----------------------------------------------------------------------------
SELECT
    u.full_name,
    st.from_status,
    st.to_status,
    st.triggered_by,
    st.notes,
    st.transitioned_at
FROM status_transitions st
JOIN users u ON st.user_id = u.user_id
ORDER BY st.transitioned_at ASC;


-- -----------------------------------------------------------------------------
-- Q10. Assets with require_contact_verify=1 and their job status
--      Identifies which assets are still blocked waiting for confirmation
-- -----------------------------------------------------------------------------
SELECT
    u.full_name                         AS owner,
    da.asset_name,
    da.asset_type,
    b.full_name                         AS beneficiary,
    ej.status                           AS job_status,
    ej.scheduled_at,
    DATEDIFF(NOW(), ej.scheduled_at)    AS days_waiting
FROM execution_jobs ej
JOIN digital_assets      da ON ej.asset_id      = da.asset_id
JOIN users               u  ON ej.user_id        = u.user_id
JOIN beneficiaries       b  ON ej.beneficiary_id = b.beneficiary_id
WHERE da.require_contact_verify = 1
  AND ej.status = 'awaiting_contact_verify'
ORDER BY days_waiting DESC;


-- -----------------------------------------------------------------------------
-- Q11. Trusted contact verification status per user
-- -----------------------------------------------------------------------------
SELECT
    u.full_name                         AS user_name,
    tc.full_name                        AS contact_name,
    tc.email,
    tc.priority_order,
    tc.verification_status,
    tc.verified_at,
    DATEDIFF(NOW(), tc.created_at)      AS days_since_added
FROM trusted_contacts tc
JOIN users u ON tc.user_id = u.user_id
ORDER BY u.user_id, tc.priority_order;


-- -----------------------------------------------------------------------------
-- Q12. Complete audit log: all tracked changes across the system
-- -----------------------------------------------------------------------------
SELECT
    al.log_id,
    u.full_name                         AS user_name,
    al.table_name,
    al.record_id,
    al.action,
    al.old_values,
    al.new_values,
    al.changed_by,
    al.client_type,
    al.changed_at
FROM audit_log al
LEFT JOIN users u ON al.user_id = u.user_id
ORDER BY al.changed_at DESC
LIMIT 50;


-- -----------------------------------------------------------------------------
-- Q13. Death trigger rules summary per user
-- -----------------------------------------------------------------------------
SELECT
    u.full_name,
    r.rule_type,
    r.inactivity_days,
    r.quorum_required,
    r.grace_period_days,
    r.logic_operator,
    r.is_active,
    CASE r.rule_type
        WHEN 'inactivity_timer'   THEN CONCAT('Flag after ', r.inactivity_days, ' inactive days')
        WHEN 'quorum_vote'        THEN CONCAT(r.quorum_required, ' contacts must confirm')
        WHEN 'manual_declaration' THEN CONCAT('Contact declares + ', r.grace_period_days, ' day grace')
        WHEN 'combined_and'       THEN CONCAT(r.inactivity_days, ' days inactive AND ',
                                              r.quorum_required, ' contacts confirm')
    END                                 AS rule_description
FROM death_trigger_rules r
JOIN users u ON r.user_id = u.user_id
ORDER BY u.user_id;


-- -----------------------------------------------------------------------------
-- Q14. Users with assets that have NO beneficiaries assigned (data integrity check)
-- -----------------------------------------------------------------------------
SELECT
    u.full_name                         AS owner,
    da.asset_id,
    da.asset_name,
    da.asset_type,
    da.status
FROM digital_assets da
JOIN users u ON da.user_id = u.user_id
LEFT JOIN asset_beneficiaries ab ON ab.asset_id = da.asset_id
WHERE ab.id IS NULL
ORDER BY u.user_id;


-- -----------------------------------------------------------------------------
-- Q15. Total assets and beneficiaries per user (GROUP BY + aggregate)
-- -----------------------------------------------------------------------------
SELECT
    u.full_name,
    u.account_status,
    COUNT(DISTINCT da.asset_id)          AS total_assets,
    SUM(da.require_contact_verify)       AS assets_with_contact_verify,
    COUNT(DISTINCT ab.beneficiary_id)    AS unique_beneficiaries,
    COUNT(DISTINCT ve.vault_id)          AS total_vault_entries
FROM users u
LEFT JOIN digital_assets      da ON da.user_id  = u.user_id
LEFT JOIN asset_beneficiaries ab ON ab.asset_id = da.asset_id
LEFT JOIN vault_entries       ve ON ve.asset_id = da.asset_id
GROUP BY u.user_id, u.full_name, u.account_status
ORDER BY total_assets DESC;


-- =============================================================================
-- 8. UPDATE & DELETE SAMPLES
-- =============================================================================

-- Update: user logs in → checkin_log INSERT → trigger resets status + last_checkin_at
-- (Sara logs back in, cancelling the flagged status)
INSERT INTO checkin_log (user_id, checkin_type, ip_address, client_type, checkin_at)
VALUES (2, 'login', '192.168.1.20', 'web', NOW());

-- Update: mark an asset as excluded from estate
UPDATE digital_assets
SET include_in_estate = 0
WHERE asset_id = 9 AND user_id = 4; -- Ayesha excludes Netflix

-- Update: change inactivity threshold
UPDATE death_trigger_rules
SET inactivity_days = 45
WHERE user_id = 1 AND rule_type = 'combined_and';

-- Update: add a new vault entry for an existing asset
INSERT INTO vault_entries (asset_id, field_name, encrypted_value, iv)
VALUES (1, 'branch_code', 'U2FsdGVkX19HBLbranchCode', 'iv_hbl_003');

-- Delete: remove a trusted contact (user decided to change contacts)
-- FK is CASCADE so contact_confirmations for this contact are also removed
DELETE FROM trusted_contacts
WHERE contact_id = 8; -- Khalid Sheikh removed by Omar


-- =============================================================================
-- END OF DAMS.SQL
-- =============================================================================