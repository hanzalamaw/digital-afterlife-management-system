-- phpMyAdmin SQL Dump
-- version 5.2.1
-- https://www.phpmyadmin.net/
--
-- Host: 127.0.0.1
-- Generation Time: May 13, 2026 at 06:18 PM
-- Server version: 10.4.32-MariaDB
-- PHP Version: 8.0.30

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- Database: `dams`
--

DELIMITER $$
--
-- Procedures
--
CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_confirm_death_quorum` (IN `p_verification_id` INT, IN `p_contact_id` INT, IN `p_token` VARCHAR(100), IN `p_ip_address` VARCHAR(45))   BEGIN
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

CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_process_execution_job` (IN `p_job_id` INT, IN `p_success` TINYINT, IN `p_error_msg` TEXT)   BEGIN
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

CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_register_asset` (IN `p_user_id` INT, IN `p_asset_name` VARCHAR(200), IN `p_asset_type` VARCHAR(50), IN `p_instructions` TEXT, IN `p_require_contact_verify` TINYINT, IN `p_field_name` VARCHAR(100), IN `p_encrypted_value` TEXT, IN `p_iv` VARCHAR(64))   BEGIN
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

DELIMITER ;

-- --------------------------------------------------------

--
-- Table structure for table `asset_beneficiaries`
--

CREATE TABLE `asset_beneficiaries` (
  `id` int(11) NOT NULL,
  `asset_id` int(11) NOT NULL,
  `beneficiary_id` int(11) NOT NULL,
  `share_percentage` decimal(5,2) NOT NULL DEFAULT 100.00,
  `special_instructions` text DEFAULT NULL,
  `notification_method` enum('email','sms','both') NOT NULL DEFAULT 'email',
  `assigned_at` datetime NOT NULL DEFAULT current_timestamp()
) ;

--
-- Dumping data for table `asset_beneficiaries`
--

INSERT INTO `asset_beneficiaries` (`id`, `asset_id`, `beneficiary_id`, `share_percentage`, `special_instructions`, `notification_method`, `assigned_at`) VALUES
(1, 1, 1, 50.00, 'Ali receives 50% of the balance.', 'email', '2026-04-13 11:03:36'),
(2, 1, 2, 50.00, 'Mariam receives 50% of the balance.', 'email', '2026-04-13 11:03:36'),
(3, 2, 1, 60.00, 'Ali receives the private keys.', 'email', '2026-04-13 11:03:36'),
(4, 2, 6, 40.00, 'Donate 40% value to Ayesha Foundation.', 'email', '2026-04-13 11:03:36'),
(5, 3, 2, 100.00, 'Mariam handles the account.', 'email', '2026-04-13 11:03:36'),
(6, 4, 1, 50.00, 'Send this message to Ali.', 'email', '2026-04-13 11:03:36'),
(7, 4, 2, 50.00, 'Send this message to Mariam.', 'email', '2026-04-13 11:03:36'),
(8, 5, 3, 100.00, 'Full transfer to Nadia.', 'both', '2026-04-13 11:03:36'),
(9, 6, 3, 40.00, 'Nadia receives 40% ETH.', 'email', '2026-04-13 11:03:36'),
(10, 6, 4, 30.00, 'Tariq receives 30% ETH.', 'email', '2026-04-13 11:03:36'),
(11, 6, 5, 30.00, 'Sana receives 30% ETH.', 'email', '2026-04-13 11:03:36'),
(12, 7, 3, 100.00, 'All files go to Nadia.', 'both', '2026-04-13 11:03:36'),
(13, 8, 1, 100.00, 'Full transfer to Ahmed.', 'email', '2026-04-13 11:03:36'),
(14, 9, 2, 100.00, 'Cancel and notify.', 'email', '2026-04-13 11:03:36'),
(15, 10, 7, 100.00, 'Transfer all holdings to Usman.', 'both', '2026-04-13 11:03:36'),
(16, 12, 9, 100.00, NULL, 'email', '2026-04-22 20:58:49'),
(23, 16, 13, 20.00, NULL, 'email', '2026-04-23 10:04:32'),
(24, 16, 14, 60.00, NULL, 'email', '2026-04-23 10:04:32'),
(25, 16, 15, 20.00, NULL, 'email', '2026-04-23 10:04:32'),
(26, 17, 16, 50.00, NULL, 'email', '2026-05-13 20:37:12'),
(27, 17, 17, 50.00, NULL, 'email', '2026-05-13 20:37:12');

-- --------------------------------------------------------

--
-- Table structure for table `audit_log`
--

CREATE TABLE `audit_log` (
  `log_id` int(11) NOT NULL,
  `user_id` int(11) DEFAULT NULL,
  `table_name` varchar(100) NOT NULL,
  `record_id` int(11) NOT NULL,
  `action` enum('INSERT','UPDATE','DELETE') NOT NULL,
  `old_values` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL CHECK (json_valid(`old_values`)),
  `new_values` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL CHECK (json_valid(`new_values`)),
  `changed_by` varchar(100) NOT NULL DEFAULT 'system',
  `client_type` enum('web','socket_client','api','scheduler','trigger') NOT NULL DEFAULT 'trigger',
  `ip_address` varchar(45) DEFAULT NULL,
  `changed_at` datetime NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Row-level audit log for all sensitive table changes';

--
-- Dumping data for table `audit_log`
--

INSERT INTO `audit_log` (`log_id`, `user_id`, `table_name`, `record_id`, `action`, `old_values`, `new_values`, `changed_by`, `client_type`, `ip_address`, `changed_at`) VALUES
(1, 1, 'users', 1, 'UPDATE', '{\"account_status\": \"Active\", \"last_checkin_at\": \"2026-04-08 11:03:36\"}', '{\"account_status\": \"Active\", \"last_checkin_at\": \"2026-04-11 11:03:36\"}', 'trigger', 'trigger', NULL, '2026-04-13 11:03:36'),
(2, 2, 'users', 2, 'UPDATE', '{\"account_status\": \"Flagged\", \"last_checkin_at\": \"2026-01-08 11:03:36\"}', '{\"account_status\": \"Active\", \"last_checkin_at\": \"2026-01-08 11:03:36\"}', 'trigger', 'trigger', NULL, '2026-04-13 11:03:36'),
(3, 5, 'users', 5, 'UPDATE', '{\"account_status\": \"Pending_Verification\", \"last_checkin_at\": \"2026-02-02 11:03:36\"}', '{\"account_status\": \"Active\", \"last_checkin_at\": \"2026-02-02 11:03:36\"}', 'trigger', 'trigger', NULL, '2026-04-13 11:03:36'),
(4, 2, 'users', 2, 'UPDATE', '{\"account_status\": \"Active\", \"last_checkin_at\": \"2026-01-08 11:03:36\"}', '{\"account_status\": \"Active\", \"last_checkin_at\": \"2026-04-13 11:03:36\"}', 'trigger', 'trigger', NULL, '2026-04-13 11:03:36'),
(5, 4, 'digital_assets', 9, 'UPDATE', '{\"asset_name\": \"Netflix Subscription\", \"asset_type\": \"subscription\", \"status\": \"active\", \"require_contact_verify\": 0, \"include_in_estate\": 1}', '{\"asset_name\": \"Netflix Subscription\", \"asset_type\": \"subscription\", \"status\": \"active\", \"require_contact_verify\": 0, \"include_in_estate\": 0}', 'trigger', 'trigger', NULL, '2026-04-13 11:03:36'),
(6, 9, 'users', 9, 'UPDATE', '{\"account_status\": \"Active\", \"last_checkin_at\": \"2026-04-22 20:39:40\"}', '{\"account_status\": \"Active\", \"last_checkin_at\": \"2026-04-22 20:40:40\"}', 'trigger', 'trigger', NULL, '2026-04-22 20:40:40'),
(7, 9, 'users', 9, 'UPDATE', '{\"account_status\": \"Active\", \"last_checkin_at\": \"2026-04-22 20:40:40\"}', '{\"account_status\": \"Active\", \"last_checkin_at\": \"2026-04-22 20:45:35\"}', 'trigger', 'trigger', NULL, '2026-04-22 20:45:35'),
(8, 9, 'users', 9, 'UPDATE', '{\"account_status\": \"Active\", \"last_checkin_at\": \"2026-04-22 20:45:35\"}', '{\"account_status\": \"Active\", \"last_checkin_at\": \"2026-04-22 20:55:14\"}', 'trigger', 'trigger', NULL, '2026-04-22 20:55:14'),
(9, 9, 'users', 9, 'UPDATE', '{\"account_status\": \"Active\", \"last_checkin_at\": \"2026-04-22 20:55:14\"}', '{\"account_status\": \"Active\", \"last_checkin_at\": \"2026-04-22 21:52:35\"}', 'trigger', 'trigger', NULL, '2026-04-22 21:52:35'),
(10, 9, 'users', 9, 'UPDATE', '{\"account_status\": \"Active\", \"last_checkin_at\": \"2026-04-22 21:52:35\"}', '{\"account_status\": \"Active\", \"last_checkin_at\": \"2026-04-23 09:49:44\"}', 'trigger', 'trigger', NULL, '2026-04-23 09:49:44'),
(11, 9, 'digital_assets', 12, 'UPDATE', '{\"asset_name\": \"Meezan\'s Account\", \"asset_type\": \"bank_account\", \"status\": \"active\", \"require_contact_verify\": 1, \"include_in_estate\": 1}', '{\"asset_name\": \"Meezan\'s Account\", \"asset_type\": \"bank_account\", \"status\": \"active\", \"require_contact_verify\": 0, \"include_in_estate\": 1}', 'trigger', 'trigger', NULL, '2026-04-23 09:51:23'),
(12, 9, 'digital_assets', 12, 'UPDATE', '{\"asset_name\": \"Meezan\'s Account\", \"asset_type\": \"bank_account\", \"status\": \"active\", \"require_contact_verify\": 0, \"include_in_estate\": 1}', '{\"asset_name\": \"Meezan\'s Account\", \"asset_type\": \"bank_account\", \"status\": \"active\", \"require_contact_verify\": 1, \"include_in_estate\": 1}', 'trigger', 'trigger', NULL, '2026-04-23 09:51:26'),
(13, 9, 'digital_assets', 12, 'UPDATE', '{\"asset_name\": \"Meezan\'s Account\", \"asset_type\": \"bank_account\", \"status\": \"active\", \"require_contact_verify\": 1, \"include_in_estate\": 1}', '{\"asset_name\": \"Meezan\'s Account\", \"asset_type\": \"bank_account\", \"status\": \"active\", \"require_contact_verify\": 0, \"include_in_estate\": 1}', 'trigger', 'trigger', NULL, '2026-04-23 09:52:15'),
(14, 10, 'digital_assets', 16, 'UPDATE', '{\"asset_name\": \"zewar\", \"asset_type\": \"other\", \"status\": \"active\", \"require_contact_verify\": 1, \"include_in_estate\": 1}', '{\"asset_name\": \"zewar\", \"asset_type\": \"other\", \"status\": \"active\", \"require_contact_verify\": 0, \"include_in_estate\": 1}', 'trigger', 'trigger', NULL, '2026-04-23 10:05:30'),
(15, 10, 'digital_assets', 16, 'UPDATE', '{\"asset_name\": \"zewar\", \"asset_type\": \"other\", \"status\": \"active\", \"require_contact_verify\": 0, \"include_in_estate\": 1}', '{\"asset_name\": \"zewar\", \"asset_type\": \"other\", \"status\": \"active\", \"require_contact_verify\": 1, \"include_in_estate\": 1}', 'trigger', 'trigger', NULL, '2026-04-23 10:05:33'),
(16, 9, 'users', 9, 'UPDATE', '{\"account_status\": \"Active\", \"last_checkin_at\": \"2026-04-23 09:49:44\"}', '{\"account_status\": \"Active\", \"last_checkin_at\": \"2026-05-03 20:17:07\"}', 'trigger', 'trigger', NULL, '2026-05-03 20:17:07'),
(17, 9, 'digital_assets', 12, 'UPDATE', '{\"asset_name\": \"Meezan\'s Account\", \"asset_type\": \"bank_account\", \"status\": \"active\", \"require_contact_verify\": 0, \"include_in_estate\": 1}', '{\"asset_name\": \"Meezan\'s Account\", \"asset_type\": \"bank_account\", \"status\": \"active\", \"require_contact_verify\": 1, \"include_in_estate\": 1}', 'trigger', 'trigger', NULL, '2026-05-03 20:18:23'),
(18, 9, 'digital_assets', 12, 'UPDATE', '{\"asset_name\": \"Meezan\'s Account\", \"asset_type\": \"bank_account\", \"status\": \"active\", \"require_contact_verify\": 1, \"include_in_estate\": 1}', '{\"asset_name\": \"Meezan\'s Account\", \"asset_type\": \"bank_account\", \"status\": \"active\", \"require_contact_verify\": 0, \"include_in_estate\": 1}', 'trigger', 'trigger', NULL, '2026-05-03 20:18:23'),
(19, 9, 'digital_assets', 12, 'UPDATE', '{\"asset_name\": \"Meezan\'s Account\", \"asset_type\": \"bank_account\", \"status\": \"active\", \"require_contact_verify\": 0, \"include_in_estate\": 1}', '{\"asset_name\": \"Meezan\'s Account\", \"asset_type\": \"bank_account\", \"status\": \"active\", \"require_contact_verify\": 1, \"include_in_estate\": 1}', 'trigger', 'trigger', NULL, '2026-05-03 20:18:24'),
(20, 9, 'digital_assets', 12, 'UPDATE', '{\"asset_name\": \"Meezan\'s Account\", \"asset_type\": \"bank_account\", \"status\": \"active\", \"require_contact_verify\": 1, \"include_in_estate\": 1}', '{\"asset_name\": \"Meezan\'s Account\", \"asset_type\": \"bank_account\", \"status\": \"active\", \"require_contact_verify\": 1, \"include_in_estate\": 0}', 'trigger', 'trigger', NULL, '2026-05-03 20:18:24'),
(21, 9, 'digital_assets', 12, 'UPDATE', '{\"asset_name\": \"Meezan\'s Account\", \"asset_type\": \"bank_account\", \"status\": \"active\", \"require_contact_verify\": 1, \"include_in_estate\": 0}', '{\"asset_name\": \"Meezan\'s Account\", \"asset_type\": \"bank_account\", \"status\": \"active\", \"require_contact_verify\": 1, \"include_in_estate\": 1}', 'trigger', 'trigger', NULL, '2026-05-03 20:18:25'),
(22, 9, 'digital_assets', 12, 'UPDATE', '{\"asset_name\": \"Meezan\'s Account\", \"asset_type\": \"bank_account\", \"status\": \"active\", \"require_contact_verify\": 1, \"include_in_estate\": 1}', '{\"asset_name\": \"Meezan\'s Account\", \"asset_type\": \"bank_account\", \"status\": \"active\", \"require_contact_verify\": 1, \"include_in_estate\": 0}', 'trigger', 'trigger', NULL, '2026-05-03 20:18:26'),
(23, 9, 'digital_assets', 12, 'UPDATE', '{\"asset_name\": \"Meezan\'s Account\", \"asset_type\": \"bank_account\", \"status\": \"active\", \"require_contact_verify\": 1, \"include_in_estate\": 0}', '{\"asset_name\": \"Meezan\'s Account\", \"asset_type\": \"bank_account\", \"status\": \"active\", \"require_contact_verify\": 1, \"include_in_estate\": 1}', 'trigger', 'trigger', NULL, '2026-05-03 20:18:27'),
(24, 9, 'users', 9, 'UPDATE', '{\"account_status\": \"Active\", \"last_checkin_at\": \"2026-05-03 20:17:07\"}', '{\"account_status\": \"Active\", \"last_checkin_at\": \"2026-05-13 19:49:21\"}', 'trigger', 'trigger', NULL, '2026-05-13 19:49:21'),
(25, 9, 'digital_assets', 17, 'UPDATE', '{\"asset_name\": \"Binance Account\", \"asset_type\": \"crypto_wallet\", \"status\": \"active\", \"require_contact_verify\": 1, \"include_in_estate\": 1}', '{\"asset_name\": \"Binance Account\", \"asset_type\": \"crypto_wallet\", \"status\": \"active\", \"require_contact_verify\": 0, \"include_in_estate\": 1}', 'trigger', 'trigger', NULL, '2026-05-13 20:40:26'),
(26, 9, 'digital_assets', 12, 'UPDATE', '{\"asset_name\": \"Meezan\'s Account\", \"asset_type\": \"bank_account\", \"status\": \"active\", \"require_contact_verify\": 1, \"include_in_estate\": 1}', '{\"asset_name\": \"Meezan\'s Account\", \"asset_type\": \"bank_account\", \"status\": \"active\", \"require_contact_verify\": 0, \"include_in_estate\": 1}', 'trigger', 'trigger', NULL, '2026-05-13 20:40:26'),
(27, 9, 'digital_assets', 17, 'UPDATE', '{\"asset_name\": \"Binance Account\", \"asset_type\": \"crypto_wallet\", \"status\": \"active\", \"require_contact_verify\": 0, \"include_in_estate\": 1}', '{\"asset_name\": \"Binance Account\", \"asset_type\": \"crypto_wallet\", \"status\": \"active\", \"require_contact_verify\": 1, \"include_in_estate\": 1}', 'trigger', 'trigger', NULL, '2026-05-13 20:40:27'),
(28, 9, 'digital_assets', 17, 'UPDATE', '{\"asset_name\": \"Binance Account\", \"asset_type\": \"crypto_wallet\", \"status\": \"active\", \"require_contact_verify\": 1, \"include_in_estate\": 1}', '{\"asset_name\": \"Binance Account\", \"asset_type\": \"crypto_wallet\", \"status\": \"active\", \"require_contact_verify\": 0, \"include_in_estate\": 1}', 'trigger', 'trigger', NULL, '2026-05-13 20:40:27'),
(29, 9, 'digital_assets', 12, 'UPDATE', '{\"asset_name\": \"Meezan\'s Account\", \"asset_type\": \"bank_account\", \"status\": \"active\", \"require_contact_verify\": 0, \"include_in_estate\": 1}', '{\"asset_name\": \"Meezan\'s Account\", \"asset_type\": \"bank_account\", \"status\": \"active\", \"require_contact_verify\": 1, \"include_in_estate\": 1}', 'trigger', 'trigger', NULL, '2026-05-13 20:40:28'),
(30, 9, 'digital_assets', 17, 'UPDATE', '{\"asset_name\": \"Binance Account\", \"asset_type\": \"crypto_wallet\", \"status\": \"active\", \"require_contact_verify\": 0, \"include_in_estate\": 1}', '{\"asset_name\": \"Binance Account\", \"asset_type\": \"crypto_wallet\", \"status\": \"active\", \"require_contact_verify\": 1, \"include_in_estate\": 1}', 'trigger', 'trigger', NULL, '2026-05-13 20:40:29'),
(31, 9, 'digital_assets', 12, 'UPDATE', '{\"asset_name\": \"Meezan\'s Account\", \"asset_type\": \"bank_account\", \"status\": \"active\", \"require_contact_verify\": 1, \"include_in_estate\": 1}', '{\"asset_name\": \"Meezan\'s Account\", \"asset_type\": \"bank_account\", \"status\": \"active\", \"require_contact_verify\": 0, \"include_in_estate\": 1}', 'trigger', 'trigger', NULL, '2026-05-13 20:40:30'),
(32, 9, 'digital_assets', 17, 'UPDATE', '{\"asset_name\": \"Binance Account\", \"asset_type\": \"crypto_wallet\", \"status\": \"active\", \"require_contact_verify\": 1, \"include_in_estate\": 1}', '{\"asset_name\": \"Binance Account\", \"asset_type\": \"crypto_wallet\", \"status\": \"active\", \"require_contact_verify\": 0, \"include_in_estate\": 1}', 'trigger', 'trigger', NULL, '2026-05-13 20:40:32'),
(33, 9, 'digital_assets', 12, 'UPDATE', '{\"asset_name\": \"Meezan\'s Account\", \"asset_type\": \"bank_account\", \"status\": \"active\", \"require_contact_verify\": 0, \"include_in_estate\": 1}', '{\"asset_name\": \"Meezan\'s Account\", \"asset_type\": \"bank_account\", \"status\": \"active\", \"require_contact_verify\": 1, \"include_in_estate\": 1}', 'trigger', 'trigger', NULL, '2026-05-13 20:40:32'),
(34, 9, 'digital_assets', 17, 'UPDATE', '{\"asset_name\": \"Binance Account\", \"asset_type\": \"crypto_wallet\", \"status\": \"active\", \"require_contact_verify\": 0, \"include_in_estate\": 1}', '{\"asset_name\": \"Binance Account\", \"asset_type\": \"crypto_wallet\", \"status\": \"active\", \"require_contact_verify\": 1, \"include_in_estate\": 1}', 'trigger', 'trigger', NULL, '2026-05-13 20:40:33'),
(35, 9, 'digital_assets', 12, 'UPDATE', '{\"asset_name\": \"Meezan\'s Account\", \"asset_type\": \"bank_account\", \"status\": \"active\", \"require_contact_verify\": 1, \"include_in_estate\": 1}', '{\"asset_name\": \"Meezan\'s Account\", \"asset_type\": \"bank_account\", \"status\": \"active\", \"require_contact_verify\": 1, \"include_in_estate\": 0}', 'trigger', 'trigger', NULL, '2026-05-13 20:40:36'),
(36, 9, 'digital_assets', 17, 'UPDATE', '{\"asset_name\": \"Binance Account\", \"asset_type\": \"crypto_wallet\", \"status\": \"active\", \"require_contact_verify\": 1, \"include_in_estate\": 1}', '{\"asset_name\": \"Binance Account\", \"asset_type\": \"crypto_wallet\", \"status\": \"active\", \"require_contact_verify\": 1, \"include_in_estate\": 0}', 'trigger', 'trigger', NULL, '2026-05-13 20:40:37'),
(37, 9, 'digital_assets', 12, 'UPDATE', '{\"asset_name\": \"Meezan\'s Account\", \"asset_type\": \"bank_account\", \"status\": \"active\", \"require_contact_verify\": 1, \"include_in_estate\": 0}', '{\"asset_name\": \"Meezan\'s Account\", \"asset_type\": \"bank_account\", \"status\": \"active\", \"require_contact_verify\": 1, \"include_in_estate\": 1}', 'trigger', 'trigger', NULL, '2026-05-13 20:40:37'),
(38, 9, 'digital_assets', 17, 'UPDATE', '{\"asset_name\": \"Binance Account\", \"asset_type\": \"crypto_wallet\", \"status\": \"active\", \"require_contact_verify\": 1, \"include_in_estate\": 0}', '{\"asset_name\": \"Binance Account\", \"asset_type\": \"crypto_wallet\", \"status\": \"active\", \"require_contact_verify\": 1, \"include_in_estate\": 1}', 'trigger', 'trigger', NULL, '2026-05-13 20:40:38'),
(39, 9, 'users', 9, 'UPDATE', '{\"account_status\": \"Active\", \"last_checkin_at\": \"2026-05-13 19:49:21\"}', '{\"account_status\": \"Active\", \"last_checkin_at\": \"2026-05-13 21:02:59\"}', 'trigger', 'trigger', NULL, '2026-05-13 21:02:59'),
(40, 9, 'users', 9, 'UPDATE', '{\"account_status\": \"Active\", \"last_checkin_at\": \"2026-05-13 21:02:59\"}', '{\"account_status\": \"Active\", \"last_checkin_at\": \"2026-02-02 21:02:59\"}', 'trigger', 'trigger', NULL, '2026-05-13 21:04:00'),
(41, 9, 'users', 9, 'UPDATE', '{\"account_status\": \"Active\", \"last_checkin_at\": \"2026-02-02 21:02:59\"}', '{\"account_status\": \"Flagged\", \"last_checkin_at\": \"2026-02-02 21:02:59\"}', 'trigger', 'trigger', NULL, '2026-05-13 21:04:42'),
(42, 9, 'users', 9, 'UPDATE', '{\"account_status\": \"Flagged\", \"last_checkin_at\": \"2026-02-02 21:02:59\"}', '{\"account_status\": \"Active\", \"last_checkin_at\": \"2026-05-13 21:05:41\"}', 'trigger', 'trigger', NULL, '2026-05-13 21:05:41');

-- --------------------------------------------------------

--
-- Table structure for table `beneficiaries`
--

CREATE TABLE `beneficiaries` (
  `beneficiary_id` int(11) NOT NULL,
  `full_name` varchar(150) NOT NULL,
  `email` varchar(200) NOT NULL,
  `phone` varchar(30) DEFAULT NULL,
  `relationship` varchar(100) DEFAULT NULL,
  `verification_token` varchar(100) DEFAULT NULL,
  `verification_status` enum('pending','verified') NOT NULL DEFAULT 'pending',
  `verified_at` datetime DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Asset recipients - independent of user accounts';

--
-- Dumping data for table `beneficiaries`
--

INSERT INTO `beneficiaries` (`beneficiary_id`, `full_name`, `email`, `phone`, `relationship`, `verification_token`, `verification_status`, `verified_at`, `created_at`) VALUES
(1, 'Ali Muhammad', 'ali@email.com', '+92-311-1111111', 'Brother', 'ben_tok_001', 'verified', '2026-03-19 11:03:36', '2026-04-13 11:03:36'),
(2, 'Mariam Khan', 'mariam@email.com', '+92-312-1111111', 'Sister', 'ben_tok_002', 'verified', '2026-03-22 11:03:36', '2026-04-13 11:03:36'),
(3, 'Nadia Bilal', 'nadia@email.com', '+92-314-3333333', 'Wife', 'ben_tok_003', 'verified', '2026-01-23 11:03:36', '2026-04-13 11:03:36'),
(4, 'Tariq Hassan', 'tariq@email.com', '+92-315-3333333', 'Son', 'ben_tok_004', 'verified', '2026-01-28 11:03:36', '2026-04-13 11:03:36'),
(5, 'Sana Bilal', 'sana@email.com', '+92-316-3333333', 'Daughter', 'ben_tok_005', 'verified', '2026-02-02 11:03:36', '2026-04-13 11:03:36'),
(6, 'Ayesha Foundation', 'foundation@email.com', '+92-319-0000000', 'Charity', 'ben_tok_006', 'verified', '2026-02-22 11:03:36', '2026-04-13 11:03:36'),
(7, 'Usman Zain', 'usman@email.com', '+92-317-5555555', 'Son', 'ben_tok_007', 'verified', '2026-03-04 11:03:36', '2026-04-13 11:03:36'),
(8, 'Khalid Sheikh', 'khalid@email.com', '+92-318-7777777', 'Son', 'ben_tok_008', 'verified', '2026-04-08 11:03:36', '2026-04-13 11:03:36'),
(9, 'Hanzala', 'hanzalamawahab@gmail.com', '03192401670', 'Brother', NULL, 'pending', NULL, '2026-04-22 20:58:49'),
(13, 'Donations', 'babababa@gmail.com', '-', '-', NULL, 'pending', NULL, '2026-04-23 10:04:32'),
(14, 'Son', 'bababab@gmail.com', '-', '-', NULL, 'pending', NULL, '2026-04-23 10:04:32'),
(15, 'Daughter', 'bababa@gmail.com', '-', '-', NULL, 'pending', NULL, '2026-04-23 10:04:32'),
(16, 'Hanzala M A Wahab', 'hanzalamaw@gmail.com', '03192401670', 'Son', NULL, 'pending', NULL, '2026-05-13 20:37:12'),
(17, 'Hanzala Wahab', 'test@gmail.com', '03192401670', 'Son', NULL, 'pending', NULL, '2026-05-13 20:37:12');

-- --------------------------------------------------------

--
-- Table structure for table `checkin_log`
--

CREATE TABLE `checkin_log` (
  `checkin_id` int(11) NOT NULL,
  `user_id` int(11) NOT NULL,
  `checkin_type` enum('login','manual_ping','api_call') NOT NULL DEFAULT 'login',
  `ip_address` varchar(45) DEFAULT NULL,
  `user_agent` varchar(500) DEFAULT NULL,
  `client_type` enum('web','socket_client','api') NOT NULL DEFAULT 'web',
  `checkin_at` datetime NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='User login and check-in activity log';

--
-- Dumping data for table `checkin_log`
--

INSERT INTO `checkin_log` (`checkin_id`, `user_id`, `checkin_type`, `ip_address`, `user_agent`, `client_type`, `checkin_at`) VALUES
(1, 1, 'login', '192.168.1.10', NULL, 'web', '2026-04-08 11:03:36'),
(2, 1, 'manual_ping', '192.168.1.10', NULL, 'web', '2026-04-11 11:03:36'),
(3, 2, 'login', '192.168.1.20', NULL, 'web', '2026-01-08 11:03:36'),
(4, 3, 'login', '10.0.0.30', NULL, 'web', '2025-09-25 11:03:36'),
(5, 4, 'login', '172.16.0.40', NULL, 'socket_client', '2026-04-03 11:03:36'),
(6, 5, 'login', '192.168.2.50', NULL, 'web', '2026-02-02 11:03:36'),
(7, 7, 'login', '192.168.3.70', NULL, 'web', '2026-04-11 11:03:36'),
(8, 2, 'login', '192.168.1.20', NULL, 'web', '2026-04-13 11:03:36'),
(9, 9, 'login', '::1', NULL, 'web', '2026-04-22 20:40:40'),
(10, 9, 'login', '::1', NULL, 'web', '2026-04-22 20:45:35'),
(11, 9, 'login', '::1', NULL, 'web', '2026-04-22 20:55:14'),
(12, 9, 'login', '::1', NULL, 'web', '2026-04-22 21:52:35'),
(13, 9, 'login', '::1', NULL, 'web', '2026-04-23 09:49:44'),
(14, 9, 'login', '::1', NULL, 'web', '2026-05-03 20:17:07'),
(15, 9, 'login', '::1', NULL, 'web', '2026-05-13 19:49:21'),
(16, 9, 'login', '::1', NULL, 'web', '2026-05-13 21:02:59'),
(17, 9, 'login', '::1', NULL, 'web', '2026-05-13 21:05:41');

--
-- Triggers `checkin_log`
--
DELIMITER $$
CREATE TRIGGER `trg_checkin_update_user` AFTER INSERT ON `checkin_log` FOR EACH ROW BEGIN
    UPDATE users
    SET
        last_checkin_at = NEW.checkin_at,
        account_status  = IF(account_status IN ('Flagged', 'Pending_Verification'),
                             'Active',
                             account_status)
    WHERE user_id = NEW.user_id;
END
$$
DELIMITER ;

-- --------------------------------------------------------

--
-- Table structure for table `contact_confirmations`
--

CREATE TABLE `contact_confirmations` (
  `confirmation_id` int(11) NOT NULL,
  `verification_id` int(11) NOT NULL,
  `contact_id` int(11) NOT NULL,
  `action` enum('confirmed','denied','no_response') NOT NULL DEFAULT 'no_response',
  `token_used` varchar(100) DEFAULT NULL,
  `ip_address` varchar(45) DEFAULT NULL,
  `responded_at` datetime DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Individual contact responses to verification requests';

--
-- Dumping data for table `contact_confirmations`
--

INSERT INTO `contact_confirmations` (`confirmation_id`, `verification_id`, `contact_id`, `action`, `token_used`, `ip_address`, `responded_at`) VALUES
(1, 1, 4, 'confirmed', 'conf_tok_nadia_001', '10.1.1.41', '2026-04-04 11:03:36'),
(2, 1, 5, 'confirmed', 'conf_tok_tariq_001', '10.1.1.42', '2026-04-05 11:03:36'),
(3, 1, 6, 'confirmed', 'conf_tok_sana_001', '10.1.1.43', '2026-04-06 11:03:36'),
(4, 2, 3, 'no_response', NULL, NULL, NULL),
(5, 3, 7, 'no_response', NULL, NULL, NULL);

-- --------------------------------------------------------

--
-- Table structure for table `death_trigger_rules`
--

CREATE TABLE `death_trigger_rules` (
  `rule_id` int(11) NOT NULL,
  `user_id` int(11) NOT NULL,
  `rule_type` enum('inactivity_timer','quorum_vote','manual_declaration','combined_and') NOT NULL,
  `inactivity_days` int(11) DEFAULT NULL COMMENT 'Days before flagging; NULL for quorum_vote only',
  `quorum_required` int(11) DEFAULT NULL COMMENT 'Contacts needed to confirm; NULL for inactivity_timer only',
  `grace_period_days` int(11) NOT NULL DEFAULT 7 COMMENT 'Days user has to cancel after a declaration',
  `logic_operator` enum('AND','OR') DEFAULT NULL COMMENT 'Only used for combined_and rule type',
  `is_active` tinyint(1) NOT NULL DEFAULT 1,
  `created_at` datetime NOT NULL DEFAULT current_timestamp()
) ;

--
-- Dumping data for table `death_trigger_rules`
--

INSERT INTO `death_trigger_rules` (`rule_id`, `user_id`, `rule_type`, `inactivity_days`, `quorum_required`, `grace_period_days`, `logic_operator`, `is_active`, `created_at`) VALUES
(1, 1, 'combined_and', 45, 2, 7, 'AND', 1, '2026-04-13 11:03:36'),
(2, 2, 'inactivity_timer', 90, NULL, 7, NULL, 1, '2026-04-13 11:03:36'),
(3, 3, 'quorum_vote', NULL, 3, 7, NULL, 0, '2026-04-13 11:03:36'),
(4, 4, 'inactivity_timer', 120, NULL, 14, NULL, 1, '2026-04-13 11:03:36'),
(5, 5, 'combined_and', 60, 1, 7, 'AND', 1, '2026-04-13 11:03:36'),
(6, 6, 'inactivity_timer', 30, NULL, 7, NULL, 0, '2026-04-13 11:03:36'),
(7, 7, 'manual_declaration', NULL, NULL, 30, NULL, 1, '2026-04-13 11:03:36'),
(8, 9, 'quorum_vote', NULL, 2, 7, NULL, 1, '2026-05-13 20:39:50'),
(9, 9, 'inactivity_timer', 61, NULL, 7, NULL, 0, '2026-05-13 20:40:00'),
(10, 9, 'inactivity_timer', 61, NULL, 7, NULL, 1, '2026-05-13 20:40:14');

-- --------------------------------------------------------

--
-- Table structure for table `death_verifications`
--

CREATE TABLE `death_verifications` (
  `verification_id` int(11) NOT NULL,
  `user_id` int(11) NOT NULL,
  `initiated_by` int(11) DEFAULT NULL COMMENT 'NULL if triggered by inactivity',
  `status` enum('initiated','awaiting_quorum','confirmed','cancelled','expired') NOT NULL DEFAULT 'initiated',
  `confirmations_received` int(11) NOT NULL DEFAULT 0,
  `confirmations_required` int(11) NOT NULL DEFAULT 1,
  `trigger_source` enum('inactivity_timer','contact_report','admin_override') NOT NULL,
  `initiated_at` datetime NOT NULL DEFAULT current_timestamp(),
  `confirmed_at` datetime DEFAULT NULL,
  `expires_at` datetime DEFAULT NULL,
  `cancelled_at` datetime DEFAULT NULL
) ;

--
-- Dumping data for table `death_verifications`
--

INSERT INTO `death_verifications` (`verification_id`, `user_id`, `initiated_by`, `status`, `confirmations_received`, `confirmations_required`, `trigger_source`, `initiated_at`, `confirmed_at`, `expires_at`, `cancelled_at`) VALUES
(1, 3, 4, 'confirmed', 3, 3, 'contact_report', '2026-04-03 11:03:36', NULL, '2026-05-03 11:03:36', NULL),
(2, 2, 3, 'awaiting_quorum', 0, 1, 'inactivity_timer', '2026-04-10 11:03:36', NULL, '2026-05-10 11:03:36', NULL),
(3, 5, 7, 'initiated', 0, 1, 'inactivity_timer', '2026-04-12 11:03:36', NULL, '2026-05-12 11:03:36', NULL);

-- --------------------------------------------------------

--
-- Stand-in structure for view `death_verification_status`
-- (See below for the actual view)
--
CREATE TABLE `death_verification_status` (
`verification_id` int(11)
,`user_name` varchar(150)
,`account_status` enum('Active','Flagged','Pending_Verification','Deceased','Executed')
,`verification_status` enum('initiated','awaiting_quorum','confirmed','cancelled','expired')
,`trigger_source` enum('inactivity_timer','contact_report','admin_override')
,`initiated_by_name` varchar(150)
,`confirmations_received` int(11)
,`confirmations_required` int(11)
,`confirmation_pct` decimal(15,1)
,`initiated_at` datetime
,`expires_at` datetime
,`confirmed_at` datetime
,`days_until_expiry` int(7)
);

-- --------------------------------------------------------

--
-- Table structure for table `digital_assets`
--

CREATE TABLE `digital_assets` (
  `asset_id` int(11) NOT NULL,
  `user_id` int(11) NOT NULL,
  `asset_name` varchar(200) NOT NULL,
  `asset_type` enum('bank_account','crypto_wallet','social_media','email','file_storage','subscription','domain','other') NOT NULL,
  `description` text DEFAULT NULL,
  `instructions` text DEFAULT NULL COMMENT 'What to do with this asset after death',
  `require_contact_verify` tinyint(1) NOT NULL DEFAULT 0 COMMENT 'If 1, trusted contacts must verify before release',
  `status` enum('active','pending_execution','executed','cancelled') NOT NULL DEFAULT 'active',
  `include_in_estate` tinyint(1) NOT NULL DEFAULT 1,
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  `updated_at` datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Digital assets registered for posthumous execution';

--
-- Dumping data for table `digital_assets`
--

INSERT INTO `digital_assets` (`asset_id`, `user_id`, `asset_name`, `asset_type`, `description`, `instructions`, `require_contact_verify`, `status`, `include_in_estate`, `created_at`, `updated_at`) VALUES
(1, 1, 'HBL Bank Account', 'bank_account', 'Main savings account at HBL', 'Transfer balance equally to Ali and Mariam. Contact branch manager.', 1, 'active', 1, '2026-04-13 11:03:36', '2026-04-13 11:03:36'),
(2, 1, 'Bitcoin Wallet', 'crypto_wallet', '0.5 BTC cold storage wallet', 'Import seed phrase into a hardware wallet. Split 60/40 between Ali and charity.', 1, 'active', 1, '2026-04-13 11:03:36', '2026-04-13 11:03:36'),
(3, 1, 'Gmail Personal', 'email', 'Personal gmail account', 'Download all emails. Delete account after 90 days.', 0, 'active', 1, '2026-04-13 11:03:36', '2026-04-13 11:03:36'),
(4, 1, 'Farewell Letter', 'other', 'Final message to family', 'Send this email to all family members immediately.', 0, 'active', 1, '2026-04-13 11:03:36', '2026-04-13 11:03:36'),
(5, 3, 'Meezan Bank Account', 'bank_account', 'Joint savings account', 'Transfer to Nadia. Contact bank with death certificate.', 1, 'pending_execution', 1, '2026-04-13 11:03:36', '2026-04-13 11:03:36'),
(6, 3, 'Ethereum Wallet', 'crypto_wallet', '2.3 ETH in MetaMask', 'Split equally among Nadia, Tariq, and Sana.', 1, 'pending_execution', 1, '2026-04-13 11:03:36', '2026-04-13 11:03:36'),
(7, 3, 'Google Drive Files', 'file_storage', '50GB family photos and documents', 'Download everything. Share family photos with Nadia. Delete personal files.', 0, 'pending_execution', 1, '2026-04-13 11:03:36', '2026-04-13 11:03:36'),
(8, 2, 'MCB Savings Account', 'bank_account', 'MCB savings', 'Transfer all funds to Ahmed.', 1, 'active', 1, '2026-04-13 11:03:36', '2026-04-13 11:03:36'),
(9, 4, 'Netflix Subscription', 'subscription', 'Family Netflix account', 'Cancel subscription. Share downloaded content links with family.', 0, 'active', 0, '2026-04-13 11:03:36', '2026-04-13 11:03:36'),
(10, 5, 'Coinbase Account', 'crypto_wallet', 'ETH and USDT on Coinbase', 'Transfer to Usman. Two-factor auth code needed.', 1, 'active', 1, '2026-04-13 11:03:36', '2026-04-13 11:03:36'),
(11, 8, 'Meezan\'s Account', 'bank_account', 'This is my main account', 'Should be distributed among my heirs', 1, 'active', 1, '2026-04-22 19:21:34', '2026-04-22 19:21:34'),
(12, 9, 'Meezan\'s Account', 'bank_account', 'This is my main account', 'Should be distributed among my heirs', 1, 'active', 1, '2026-04-22 20:58:49', '2026-05-13 20:40:37'),
(16, 10, 'zewar', 'other', NULL, NULL, 1, 'active', 1, '2026-04-23 10:04:32', '2026-04-23 10:05:33'),
(17, 9, 'Binance Account', 'crypto_wallet', 'Contains my bitcoins', 'Should be Divided Equally.', 1, 'active', 1, '2026-05-13 20:37:12', '2026-05-13 20:40:38');

--
-- Triggers `digital_assets`
--
DELIMITER $$
CREATE TRIGGER `trg_audit_digital_assets_update` AFTER UPDATE ON `digital_assets` FOR EACH ROW BEGIN
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
END
$$
DELIMITER ;

-- --------------------------------------------------------

--
-- Table structure for table `execution_jobs`
--

CREATE TABLE `execution_jobs` (
  `job_id` int(11) NOT NULL,
  `user_id` int(11) NOT NULL,
  `asset_id` int(11) NOT NULL,
  `beneficiary_id` int(11) NOT NULL,
  `status` enum('pending','awaiting_contact_verify','in_progress','completed','failed','cancelled') NOT NULL DEFAULT 'pending',
  `attempt_count` int(11) NOT NULL DEFAULT 0,
  `max_attempts` int(11) NOT NULL DEFAULT 3,
  `error_message` text DEFAULT NULL,
  `scheduled_at` datetime NOT NULL DEFAULT current_timestamp(),
  `last_attempted_at` datetime DEFAULT NULL,
  `executed_at` datetime DEFAULT NULL
) ;

--
-- Dumping data for table `execution_jobs`
--

INSERT INTO `execution_jobs` (`job_id`, `user_id`, `asset_id`, `beneficiary_id`, `status`, `attempt_count`, `max_attempts`, `error_message`, `scheduled_at`, `last_attempted_at`, `executed_at`) VALUES
(1, 3, 5, 3, 'awaiting_contact_verify', 0, 3, NULL, '2026-04-04 11:03:36', NULL, NULL),
(2, 3, 6, 3, 'awaiting_contact_verify', 0, 3, NULL, '2026-04-04 11:03:36', NULL, NULL),
(3, 3, 6, 4, 'awaiting_contact_verify', 0, 3, NULL, '2026-04-04 11:03:36', NULL, NULL),
(4, 3, 6, 5, 'awaiting_contact_verify', 0, 3, NULL, '2026-04-04 11:03:36', NULL, NULL),
(5, 3, 7, 3, 'completed', 1, 3, NULL, '2026-04-04 11:03:36', NULL, '2026-04-05 11:03:36'),
(6, 2, 8, 1, 'completed', 1, 3, NULL, '2025-03-19 11:03:36', NULL, '2025-03-24 11:03:36');

-- --------------------------------------------------------

--
-- Table structure for table `inactivity_reminders`
--

CREATE TABLE `inactivity_reminders` (
  `reminder_id` int(11) NOT NULL,
  `user_id` int(11) NOT NULL,
  `threshold_percent` int(11) NOT NULL COMMENT 'When days_since_checkin / inactivity_days >= this percent, fire reminder',
  `custom_message` text DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT current_timestamp()
) ;

--
-- Dumping data for table `inactivity_reminders`
--

INSERT INTO `inactivity_reminders` (`reminder_id`, `user_id`, `threshold_percent`, `custom_message`, `created_at`) VALUES
(2, 9, 50, 'None', '2026-05-13 20:40:14'),
(3, 9, 50, 'None', '2026-05-13 20:40:14');

-- --------------------------------------------------------

--
-- Table structure for table `inactivity_reminder_sends`
--

CREATE TABLE `inactivity_reminder_sends` (
  `send_id` int(11) NOT NULL,
  `user_id` int(11) NOT NULL,
  `reminder_id` int(11) DEFAULT NULL,
  `threshold_percent` int(11) NOT NULL,
  `sent_at` datetime NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Tracks which reminder thresholds have already fired';

-- --------------------------------------------------------

--
-- Table structure for table `notification_log`
--

CREATE TABLE `notification_log` (
  `notification_id` int(11) NOT NULL,
  `user_id` int(11) DEFAULT NULL,
  `recipient_email` varchar(200) NOT NULL,
  `recipient_name` varchar(150) DEFAULT NULL,
  `subject` varchar(255) NOT NULL,
  `body` text DEFAULT NULL,
  `category` enum('reminder','suspect_death','confirmed_death','beneficiary_grant','contact_request','other') NOT NULL DEFAULT 'other',
  `status` enum('queued','sent','failed') NOT NULL DEFAULT 'queued',
  `error_message` text DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  `sent_at` datetime DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Audit log of every notification the system attempts to send';

--
-- Dumping data for table `notification_log`
--

INSERT INTO `notification_log` (`notification_id`, `user_id`, `recipient_email`, `recipient_name`, `subject`, `body`, `category`, `status`, `error_message`, `created_at`, `sent_at`) VALUES
(1, 3, 'nadia@email.com', 'Nadia Bilal', 'DAMS: Bilal Khan has been confirmed deceased', 'Dear beneficiary,\n\nIt is with regret that we inform you that Bilal Khan has been confirmed deceased through the DAMS verification process.\n\nYour share of their digital estate is now being processed. You will receive a separate secure message with credentials and instructions for any assets assigned to you.\n\nThis is an automated notification.', 'confirmed_death', 'sent', NULL, '2026-05-13 21:02:59', '2026-05-13 21:03:02'),
(2, 3, 'tariq@email.com', 'Tariq Hassan', 'DAMS: Bilal Khan has been confirmed deceased', 'Dear beneficiary,\n\nIt is with regret that we inform you that Bilal Khan has been confirmed deceased through the DAMS verification process.\n\nYour share of their digital estate is now being processed. You will receive a separate secure message with credentials and instructions for any assets assigned to you.\n\nThis is an automated notification.', 'confirmed_death', 'sent', NULL, '2026-05-13 21:03:02', '2026-05-13 21:03:06'),
(3, 3, 'sana@email.com', 'Sana Bilal', 'DAMS: Bilal Khan has been confirmed deceased', 'Dear beneficiary,\n\nIt is with regret that we inform you that Bilal Khan has been confirmed deceased through the DAMS verification process.\n\nYour share of their digital estate is now being processed. You will receive a separate secure message with credentials and instructions for any assets assigned to you.\n\nThis is an automated notification.', 'confirmed_death', 'sent', NULL, '2026-05-13 21:03:06', '2026-05-13 21:03:09'),
(4, NULL, 'rgocerp@gmail.com', 'DAMS Tester', 'DAMS email test — 2026-05-13 18:06:29', 'If you can read this, DAMS SMTP delivery is working.\n\nSent by:   rgocerp@gmail.com\nTime:      Wed, 13 May 2026 18:06:29 +0200\nHost:      Hanzala\n', 'other', 'sent', NULL, '2026-05-13 21:06:29', '2026-05-13 21:06:32'),
(5, NULL, 'hanzalamawahab@gmail.com', 'DAMS Tester', 'DAMS email test — 2026-05-13 18:07:16', 'If you can read this, DAMS SMTP delivery is working.\n\nSent by:   rgocerp@gmail.com\nTime:      Wed, 13 May 2026 18:07:16 +0200\nHost:      Hanzala\n', 'other', 'sent', NULL, '2026-05-13 21:07:16', '2026-05-13 21:07:19');

-- --------------------------------------------------------

--
-- Stand-in structure for view `pending_executions`
-- (See below for the actual view)
--
CREATE TABLE `pending_executions` (
`user_id` int(11)
,`user_name` varchar(150)
,`asset_id` int(11)
,`asset_name` varchar(200)
,`asset_type` enum('bank_account','crypto_wallet','social_media','email','file_storage','subscription','domain','other')
,`require_contact_verify` tinyint(1)
,`beneficiary_id` int(11)
,`beneficiary_name` varchar(150)
,`beneficiary_email` varchar(200)
,`share_percentage` decimal(5,2)
,`notification_method` enum('email','sms','both')
,`job_id` int(11)
,`job_status` enum('pending','awaiting_contact_verify','in_progress','completed','failed','cancelled')
,`attempt_count` int(11)
,`max_attempts` int(11)
,`scheduled_at` datetime
,`last_attempted_at` datetime
);

-- --------------------------------------------------------

--
-- Table structure for table `status_transitions`
--

CREATE TABLE `status_transitions` (
  `transition_id` int(11) NOT NULL,
  `user_id` int(11) NOT NULL,
  `from_status` enum('Active','Flagged','Pending_Verification','Deceased','Executed') NOT NULL,
  `to_status` enum('Active','Flagged','Pending_Verification','Deceased','Executed') NOT NULL,
  `rule_id` int(11) DEFAULT NULL,
  `verification_id` int(11) DEFAULT NULL,
  `triggered_by` varchar(100) NOT NULL DEFAULT 'system',
  `notes` text DEFAULT NULL,
  `transitioned_at` datetime NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Immutable audit trail of all account status changes';

--
-- Dumping data for table `status_transitions`
--

INSERT INTO `status_transitions` (`transition_id`, `user_id`, `from_status`, `to_status`, `rule_id`, `verification_id`, `triggered_by`, `notes`, `transitioned_at`) VALUES
(1, 2, 'Flagged', 'Active', NULL, NULL, 'user_login', 'User logged in. Death verification process cancelled and account reactivated.', '2026-04-13 11:03:36'),
(2, 5, 'Pending_Verification', 'Active', NULL, NULL, 'user_login', 'User logged in. Death verification process cancelled and account reactivated.', '2026-04-13 11:03:36'),
(3, 2, 'Active', 'Flagged', NULL, NULL, 'event_scheduler', 'Inactivity threshold exceeded. Days since last check-in: 95', '2026-04-08 11:03:36'),
(4, 3, 'Active', 'Flagged', NULL, NULL, 'event_scheduler', 'Inactivity threshold exceeded. Days since last check-in: 140', '2026-02-12 11:03:36'),
(5, 3, 'Flagged', 'Pending_Verification', NULL, NULL, 'contact_report', 'Trusted contact Nadia filed death declaration.', '2026-04-03 11:03:36'),
(6, 3, 'Pending_Verification', 'Deceased', NULL, NULL, 'death_verification_confirmed', 'Quorum of 3 contacts reached. Execution jobs queued.', '2026-04-04 11:03:36'),
(7, 5, 'Active', 'Flagged', NULL, NULL, 'event_scheduler', 'Inactivity threshold exceeded.', '2026-04-11 11:03:36'),
(8, 5, 'Flagged', 'Pending_Verification', NULL, NULL, 'contact_report', 'Contact Usman filed declaration.', '2026-04-12 11:03:36'),
(9, 6, 'Active', 'Flagged', NULL, NULL, 'event_scheduler', 'Inactivity threshold exceeded.', '2025-03-09 11:03:36'),
(10, 6, 'Flagged', 'Pending_Verification', NULL, NULL, 'inactivity_timer', 'Quorum threshold met.', '2025-03-14 11:03:36'),
(11, 6, 'Pending_Verification', 'Deceased', NULL, NULL, 'death_verification_confirmed', 'Confirmed.', '2025-03-19 11:03:36'),
(12, 6, 'Deceased', 'Executed', NULL, NULL, 'execution_engine', 'All asset jobs completed successfully.', '2025-03-29 11:03:36'),
(13, 8, 'Active', 'Active', NULL, NULL, 'system', 'Account created via DAMS registration', '2026-04-22 19:19:46'),
(14, 9, 'Active', 'Active', NULL, NULL, 'system', 'Account created via DAMS registration', '2026-04-22 20:39:40'),
(15, 10, 'Active', 'Active', NULL, NULL, 'system', 'Account created via DAMS registration', '2026-04-23 09:59:21'),
(16, 11, 'Active', 'Active', NULL, NULL, 'system', 'Account created via DAMS registration', '2026-04-23 10:10:30'),
(17, 9, 'Active', 'Flagged', NULL, NULL, 'event_scheduler', 'Inactivity threshold exceeded. Days since last check-in: 100', '2026-05-13 21:04:42'),
(18, 9, 'Flagged', 'Active', NULL, NULL, 'user_login', 'User logged in. Death verification process cancelled and account reactivated.', '2026-05-13 21:05:41');

-- --------------------------------------------------------

--
-- Table structure for table `trusted_contacts`
--

CREATE TABLE `trusted_contacts` (
  `contact_id` int(11) NOT NULL,
  `user_id` int(11) NOT NULL,
  `full_name` varchar(150) NOT NULL,
  `email` varchar(200) NOT NULL,
  `phone` varchar(30) DEFAULT NULL,
  `verification_token` varchar(100) DEFAULT NULL,
  `verification_status` enum('pending','verified') NOT NULL DEFAULT 'pending',
  `priority_order` int(11) NOT NULL DEFAULT 1 COMMENT 'Lower number = notified first',
  `verified_at` datetime DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT current_timestamp()
) ;

--
-- Dumping data for table `trusted_contacts`
--

INSERT INTO `trusted_contacts` (`contact_id`, `user_id`, `full_name`, `email`, `phone`, `verification_token`, `verification_status`, `priority_order`, `verified_at`, `created_at`) VALUES
(1, 1, 'Ali Muhammad', 'ali@email.com', '+92-311-1111111', 'tok_ali_001', 'verified', 1, '2026-03-14 11:03:36', '2026-04-13 11:03:36'),
(2, 1, 'Mariam Khan', 'mariam@email.com', '+92-312-1111111', 'tok_mariam_001', 'verified', 2, '2026-03-16 11:03:36', '2026-04-13 11:03:36'),
(3, 2, 'Ahmed Raza', 'ahmed@email.com', '+92-313-2222222', 'tok_ahmed_001', 'verified', 1, '2026-02-12 11:03:36', '2026-04-13 11:03:36'),
(4, 3, 'Nadia Bilal', 'nadia@email.com', '+92-314-3333333', 'tok_nadia_001', 'verified', 1, '2026-01-13 11:03:36', '2026-04-13 11:03:36'),
(5, 3, 'Tariq Hassan', 'tariq@email.com', '+92-315-3333333', 'tok_tariq_001', 'verified', 2, '2026-01-18 11:03:36', '2026-04-13 11:03:36'),
(6, 3, 'Sana Bilal', 'sana@email.com', '+92-316-3333333', 'tok_sana_001', 'verified', 3, '2026-01-23 11:03:36', '2026-04-13 11:03:36'),
(7, 5, 'Usman Zain', 'usman@email.com', '+92-317-5555555', 'tok_usman_001', 'verified', 1, '2026-02-27 11:03:36', '2026-04-13 11:03:36'),
(9, 9, 'Hanzala M A Wahab', 'hanzalamawahab@gmail.com', '+923192401670', NULL, 'pending', 1, NULL, '2026-05-13 20:37:53');

-- --------------------------------------------------------

--
-- Table structure for table `users`
--

CREATE TABLE `users` (
  `user_id` int(11) NOT NULL,
  `full_name` varchar(150) NOT NULL,
  `email` varchar(200) NOT NULL,
  `password_hash` varchar(255) NOT NULL,
  `date_of_birth` date NOT NULL,
  `phone` varchar(30) DEFAULT NULL,
  `account_status` enum('Active','Flagged','Pending_Verification','Deceased','Executed') NOT NULL DEFAULT 'Active',
  `last_checkin_at` datetime NOT NULL DEFAULT current_timestamp(),
  `checkin_interval_days` int(11) NOT NULL DEFAULT 90 COMMENT 'Days of inactivity before flagging',
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  `updated_at` datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ;

--
-- Dumping data for table `users`
--

INSERT INTO `users` (`user_id`, `full_name`, `email`, `password_hash`, `date_of_birth`, `phone`, `account_status`, `last_checkin_at`, `checkin_interval_days`, `created_at`, `updated_at`) VALUES
(1, 'Hanzala Muhammad', 'hanzala@email.com', '$2b$12$abc123hashedpassword1', '1995-03-15', '+92-300-1111111', 'Active', '2026-04-11 11:03:36', 90, '2026-04-13 11:03:36', '2026-04-13 11:03:36'),
(2, 'Sara Ahmed', 'sara@email.com', '$2b$12$abc123hashedpassword2', '1988-07-22', '+92-301-2222222', 'Active', '2026-04-13 11:03:36', 90, '2026-04-13 11:03:36', '2026-04-13 11:03:36'),
(3, 'Bilal Khan', 'bilal@email.com', '$2b$12$abc123hashedpassword3', '1975-11-08', '+92-302-3333333', 'Deceased', '2025-09-25 11:03:36', 60, '2026-04-13 11:03:36', '2026-04-13 11:03:36'),
(4, 'Ayesha Siddiqui', 'ayesha@email.com', '$2b$12$abc123hashedpassword4', '1990-01-30', '+92-303-4444444', 'Active', '2026-04-03 11:03:36', 120, '2026-04-13 11:03:36', '2026-04-13 11:03:36'),
(5, 'Zain Ul Abidin', 'zain@email.com', '$2b$12$abc123hashedpassword5', '1982-09-14', '+92-304-5555555', 'Active', '2026-02-02 11:03:36', 60, '2026-04-13 11:03:36', '2026-04-13 11:03:36'),
(6, 'Fatima Malik', 'fatima@email.com', '$2b$12$abc123hashedpassword6', '1993-06-05', '+92-305-6666666', 'Executed', '2025-03-09 11:03:36', 30, '2026-04-13 11:03:36', '2026-04-13 11:03:36'),
(7, 'Omar Sheikh', 'omar@email.com', '$2b$12$abc123hashedpassword7', '1970-12-20', '+92-306-7777777', 'Active', '2026-04-11 11:03:36', 180, '2026-04-13 11:03:36', '2026-04-13 11:03:36'),
(8, 'Hanzala M A Wahab', 'hanzalamaw@gmail.com', '$2y$10$jBLdBjpXDjK0xEv87No1zuEzR14SmNKOly4YiKjDLZZPGve0v62Py', '2026-04-01', '+923192401670', 'Active', '2026-04-22 19:19:46', 90, '2026-04-22 19:19:46', '2026-04-22 19:19:46'),
(9, 'Hanzala M A Wahab', 'hanzalamawahab@gmail.com', '$2y$10$kyQmJiwNw7MZMcbOcbgDXe5V7v0IIp4XT8mI/cjEsPAR1Jcg9QFuy', '2026-04-22', '03192401670', 'Active', '2026-05-13 21:05:41', 90, '2026-04-22 20:39:40', '2026-05-13 21:05:41'),
(10, 'Syed Anoosh Uddin', 'anooshuuddin10@gmail.com', '$2y$10$fyLBU7HneRORHFn.Ybxe..QAlo3E1C8HMkyKlzSxZvaycG1TbvmnS', '2006-12-05', '03182210556', 'Active', '2026-04-23 09:59:21', 90, '2026-04-23 09:59:21', '2026-04-23 09:59:21'),
(11, 'HARSHA', 'HARSHA@gmail.com', '$2y$10$FbzHUgrBuU9Z16qnhetN/.DNo/QNDz0aNHY0E5mDJ9Fg42yxEUiKK', '2004-04-27', '03362618323', 'Active', '2026-04-23 10:10:30', 90, '2026-04-23 10:10:30', '2026-04-23 10:10:30');

--
-- Triggers `users`
--
DELIMITER $$
CREATE TRIGGER `trg_after_death_confirmed` AFTER UPDATE ON `users` FOR EACH ROW BEGIN
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
END
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `trg_after_user_flagged` AFTER UPDATE ON `users` FOR EACH ROW BEGIN
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
END
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `trg_after_user_reactivated` AFTER UPDATE ON `users` FOR EACH ROW BEGIN
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
END
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `trg_audit_users_update` AFTER UPDATE ON `users` FOR EACH ROW BEGIN
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
END
$$
DELIMITER ;

-- --------------------------------------------------------

--
-- Stand-in structure for view `user_estate_summary`
-- (See below for the actual view)
--
CREATE TABLE `user_estate_summary` (
`user_id` int(11)
,`full_name` varchar(150)
,`email` varchar(200)
,`account_status` enum('Active','Flagged','Pending_Verification','Deceased','Executed')
,`last_checkin_at` datetime
,`checkin_interval_days` int(11)
,`days_since_checkin` int(7)
,`total_assets` bigint(21)
,`total_beneficiaries` bigint(21)
,`assets_requiring_contact_verify` decimal(25,0)
,`total_execution_jobs` bigint(21)
,`completed_jobs` decimal(23,0)
,`pending_jobs` decimal(23,0)
);

-- --------------------------------------------------------

--
-- Table structure for table `vault_entries`
--

CREATE TABLE `vault_entries` (
  `vault_id` int(11) NOT NULL,
  `asset_id` int(11) NOT NULL,
  `field_name` varchar(100) NOT NULL COMMENT 'e.g. password, seed_phrase, recovery_key',
  `encrypted_value` text NOT NULL COMMENT 'AES-256-CBC ciphertext',
  `iv` varchar(64) NOT NULL COMMENT 'Initialization vector for decryption',
  `encryption_algo` varchar(30) NOT NULL DEFAULT 'AES-256-CBC',
  `created_at` datetime NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Encrypted credential vault for digital assets';

--
-- Dumping data for table `vault_entries`
--

INSERT INTO `vault_entries` (`vault_id`, `asset_id`, `field_name`, `encrypted_value`, `iv`, `encryption_algo`, `created_at`) VALUES
(1, 1, 'account_number', 'U2FsdGVkX19abc123HBL456', 'iv_hbl_001', 'AES-256-CBC', '2026-04-13 11:03:36'),
(2, 1, 'online_banking_password', 'U2FsdGVkX19xyz789HBLpass', 'iv_hbl_002', 'AES-256-CBC', '2026-04-13 11:03:36'),
(3, 2, 'seed_phrase', 'U2FsdGVkX19BTC24wordSeedPhrase', 'iv_btc_001', 'AES-256-CBC', '2026-04-13 11:03:36'),
(4, 2, 'wallet_password', 'U2FsdGVkX19BTCwalletpass', 'iv_btc_002', 'AES-256-CBC', '2026-04-13 11:03:36'),
(5, 3, 'email_password', 'U2FsdGVkX19gmailPasswordHash', 'iv_gml_001', 'AES-256-CBC', '2026-04-13 11:03:36'),
(6, 3, 'recovery_email', 'U2FsdGVkX19gmailRecovery', 'iv_gml_002', 'AES-256-CBC', '2026-04-13 11:03:36'),
(7, 4, 'letter_content', 'U2FsdGVkX19FarewellLetterEncrypted', 'iv_lttr_01', 'AES-256-CBC', '2026-04-13 11:03:36'),
(8, 5, 'account_number', 'U2FsdGVkX19MeezanAccNum', 'iv_mzn_001', 'AES-256-CBC', '2026-04-13 11:03:36'),
(9, 6, 'seed_phrase', 'U2FsdGVkX19ETHseedPhrase24words', 'iv_eth_001', 'AES-256-CBC', '2026-04-13 11:03:36'),
(10, 6, 'metamask_password', 'U2FsdGVkX19MetaMaskPass', 'iv_eth_002', 'AES-256-CBC', '2026-04-13 11:03:36'),
(11, 8, 'account_number', 'U2FsdGVkX19MCBaccountNum', 'iv_mcb_001', 'AES-256-CBC', '2026-04-13 11:03:36'),
(12, 10, 'api_key', 'U2FsdGVkX19CoinbaseAPIkey', 'iv_cb_001', 'AES-256-CBC', '2026-04-13 11:03:36'),
(13, 1, 'branch_code', 'U2FsdGVkX19HBLbranchCode', 'iv_hbl_003', 'AES-256-CBC', '2026-04-13 11:03:36'),
(14, 12, 'Usernae', 'hanzalamaw', 'hii', 'AES-256-CBC', '2026-04-22 20:58:49'),
(15, 12, 'passwword', 'hanzalamaw', 'hii', 'AES-256-CBC', '2026-04-22 20:58:49'),
(16, 17, 'Username', '5CCqNw3R6xvjsO1QWQCtxA==', 'Y/AImawk9HqQLpzXFY9pOg==', 'AES-256-CBC', '2026-05-13 20:37:12'),
(17, 17, 'Password', 'ypHnSnGBgg4z+FC73oUPaw==', '8VlvbmANnVP8s0ONQxSldA==', 'AES-256-CBC', '2026-05-13 20:37:12');

-- --------------------------------------------------------

--
-- Structure for view `death_verification_status`
--
DROP TABLE IF EXISTS `death_verification_status`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `death_verification_status`  AS SELECT `dv`.`verification_id` AS `verification_id`, `u`.`full_name` AS `user_name`, `u`.`account_status` AS `account_status`, `dv`.`status` AS `verification_status`, `dv`.`trigger_source` AS `trigger_source`, `tc`.`full_name` AS `initiated_by_name`, `dv`.`confirmations_received` AS `confirmations_received`, `dv`.`confirmations_required` AS `confirmations_required`, round(`dv`.`confirmations_received` / `dv`.`confirmations_required` * 100,1) AS `confirmation_pct`, `dv`.`initiated_at` AS `initiated_at`, `dv`.`expires_at` AS `expires_at`, `dv`.`confirmed_at` AS `confirmed_at`, to_days(`dv`.`expires_at`) - to_days(current_timestamp()) AS `days_until_expiry` FROM ((`death_verifications` `dv` join `users` `u` on(`dv`.`user_id` = `u`.`user_id`)) left join `trusted_contacts` `tc` on(`dv`.`initiated_by` = `tc`.`contact_id`)) WHERE `dv`.`status` in ('initiated','awaiting_quorum') ;

-- --------------------------------------------------------

--
-- Structure for view `pending_executions`
--
DROP TABLE IF EXISTS `pending_executions`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `pending_executions`  AS SELECT `u`.`user_id` AS `user_id`, `u`.`full_name` AS `user_name`, `a`.`asset_id` AS `asset_id`, `a`.`asset_name` AS `asset_name`, `a`.`asset_type` AS `asset_type`, `a`.`require_contact_verify` AS `require_contact_verify`, `b`.`beneficiary_id` AS `beneficiary_id`, `b`.`full_name` AS `beneficiary_name`, `b`.`email` AS `beneficiary_email`, `ab`.`share_percentage` AS `share_percentage`, `ab`.`notification_method` AS `notification_method`, `j`.`job_id` AS `job_id`, `j`.`status` AS `job_status`, `j`.`attempt_count` AS `attempt_count`, `j`.`max_attempts` AS `max_attempts`, `j`.`scheduled_at` AS `scheduled_at`, `j`.`last_attempted_at` AS `last_attempted_at` FROM ((((`execution_jobs` `j` join `digital_assets` `a` on(`j`.`asset_id` = `a`.`asset_id`)) join `users` `u` on(`j`.`user_id` = `u`.`user_id`)) join `beneficiaries` `b` on(`j`.`beneficiary_id` = `b`.`beneficiary_id`)) join `asset_beneficiaries` `ab` on(`ab`.`asset_id` = `j`.`asset_id` and `ab`.`beneficiary_id` = `j`.`beneficiary_id`)) WHERE `j`.`status` in ('pending','awaiting_contact_verify','failed') ;

-- --------------------------------------------------------

--
-- Structure for view `user_estate_summary`
--
DROP TABLE IF EXISTS `user_estate_summary`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `user_estate_summary`  AS SELECT `u`.`user_id` AS `user_id`, `u`.`full_name` AS `full_name`, `u`.`email` AS `email`, `u`.`account_status` AS `account_status`, `u`.`last_checkin_at` AS `last_checkin_at`, `u`.`checkin_interval_days` AS `checkin_interval_days`, to_days(current_timestamp()) - to_days(`u`.`last_checkin_at`) AS `days_since_checkin`, count(distinct `da`.`asset_id`) AS `total_assets`, count(distinct `ab`.`beneficiary_id`) AS `total_beneficiaries`, sum(`da`.`require_contact_verify`) AS `assets_requiring_contact_verify`, count(distinct `ej`.`job_id`) AS `total_execution_jobs`, sum(`ej`.`status` = 'completed') AS `completed_jobs`, sum(`ej`.`status` in ('pending','awaiting_contact_verify','failed')) AS `pending_jobs` FROM (((`users` `u` left join `digital_assets` `da` on(`da`.`user_id` = `u`.`user_id`)) left join `asset_beneficiaries` `ab` on(`ab`.`asset_id` = `da`.`asset_id`)) left join `execution_jobs` `ej` on(`ej`.`user_id` = `u`.`user_id`)) GROUP BY `u`.`user_id`, `u`.`full_name`, `u`.`email`, `u`.`account_status`, `u`.`last_checkin_at`, `u`.`checkin_interval_days` ;

--
-- Indexes for dumped tables
--

--
-- Indexes for table `asset_beneficiaries`
--
ALTER TABLE `asset_beneficiaries`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `uq_asset_beneficiary` (`asset_id`,`beneficiary_id`),
  ADD KEY `fk_ab_beneficiary_id` (`beneficiary_id`);

--
-- Indexes for table `audit_log`
--
ALTER TABLE `audit_log`
  ADD PRIMARY KEY (`log_id`),
  ADD KEY `idx_al_table_record` (`table_name`,`record_id`),
  ADD KEY `idx_al_user_time` (`user_id`,`changed_at`);

--
-- Indexes for table `beneficiaries`
--
ALTER TABLE `beneficiaries`
  ADD PRIMARY KEY (`beneficiary_id`);

--
-- Indexes for table `checkin_log`
--
ALTER TABLE `checkin_log`
  ADD PRIMARY KEY (`checkin_id`),
  ADD KEY `idx_checkin_user_time` (`user_id`,`checkin_at`);

--
-- Indexes for table `contact_confirmations`
--
ALTER TABLE `contact_confirmations`
  ADD PRIMARY KEY (`confirmation_id`),
  ADD UNIQUE KEY `uq_cc_verification_contact` (`verification_id`,`contact_id`) COMMENT 'One response per contact per verification',
  ADD KEY `fk_cc_contact_id` (`contact_id`);

--
-- Indexes for table `death_trigger_rules`
--
ALTER TABLE `death_trigger_rules`
  ADD PRIMARY KEY (`rule_id`),
  ADD KEY `fk_dtr_user_id` (`user_id`);

--
-- Indexes for table `death_verifications`
--
ALTER TABLE `death_verifications`
  ADD PRIMARY KEY (`verification_id`),
  ADD KEY `fk_dv_user_id` (`user_id`),
  ADD KEY `fk_dv_initiated_by` (`initiated_by`);

--
-- Indexes for table `digital_assets`
--
ALTER TABLE `digital_assets`
  ADD PRIMARY KEY (`asset_id`),
  ADD KEY `fk_da_user_id` (`user_id`);

--
-- Indexes for table `execution_jobs`
--
ALTER TABLE `execution_jobs`
  ADD PRIMARY KEY (`job_id`),
  ADD KEY `fk_ej_asset_id` (`asset_id`),
  ADD KEY `fk_ej_beneficiary_id` (`beneficiary_id`),
  ADD KEY `idx_ej_status` (`status`),
  ADD KEY `idx_ej_user_status` (`user_id`,`status`);

--
-- Indexes for table `inactivity_reminders`
--
ALTER TABLE `inactivity_reminders`
  ADD PRIMARY KEY (`reminder_id`),
  ADD KEY `fk_ir_user_id` (`user_id`);

--
-- Indexes for table `inactivity_reminder_sends`
--
ALTER TABLE `inactivity_reminder_sends`
  ADD PRIMARY KEY (`send_id`),
  ADD KEY `fk_irs_reminder_id` (`reminder_id`),
  ADD KEY `idx_irs_user_threshold` (`user_id`,`threshold_percent`);

--
-- Indexes for table `notification_log`
--
ALTER TABLE `notification_log`
  ADD PRIMARY KEY (`notification_id`),
  ADD KEY `idx_nl_user_category` (`user_id`,`category`,`created_at`);

--
-- Indexes for table `status_transitions`
--
ALTER TABLE `status_transitions`
  ADD PRIMARY KEY (`transition_id`),
  ADD KEY `fk_st_rule_id` (`rule_id`),
  ADD KEY `fk_st_verification_id` (`verification_id`),
  ADD KEY `idx_st_user_time` (`user_id`,`transitioned_at`);

--
-- Indexes for table `trusted_contacts`
--
ALTER TABLE `trusted_contacts`
  ADD PRIMARY KEY (`contact_id`),
  ADD KEY `fk_tc_user_id` (`user_id`);

--
-- Indexes for table `users`
--
ALTER TABLE `users`
  ADD PRIMARY KEY (`user_id`),
  ADD UNIQUE KEY `uq_users_email` (`email`);

--
-- Indexes for table `vault_entries`
--
ALTER TABLE `vault_entries`
  ADD PRIMARY KEY (`vault_id`),
  ADD KEY `fk_ve_asset_id` (`asset_id`);

--
-- AUTO_INCREMENT for dumped tables
--

--
-- AUTO_INCREMENT for table `asset_beneficiaries`
--
ALTER TABLE `asset_beneficiaries`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `audit_log`
--
ALTER TABLE `audit_log`
  MODIFY `log_id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=43;

--
-- AUTO_INCREMENT for table `beneficiaries`
--
ALTER TABLE `beneficiaries`
  MODIFY `beneficiary_id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=18;

--
-- AUTO_INCREMENT for table `checkin_log`
--
ALTER TABLE `checkin_log`
  MODIFY `checkin_id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=18;

--
-- AUTO_INCREMENT for table `contact_confirmations`
--
ALTER TABLE `contact_confirmations`
  MODIFY `confirmation_id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=6;

--
-- AUTO_INCREMENT for table `death_trigger_rules`
--
ALTER TABLE `death_trigger_rules`
  MODIFY `rule_id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `death_verifications`
--
ALTER TABLE `death_verifications`
  MODIFY `verification_id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `digital_assets`
--
ALTER TABLE `digital_assets`
  MODIFY `asset_id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=18;

--
-- AUTO_INCREMENT for table `execution_jobs`
--
ALTER TABLE `execution_jobs`
  MODIFY `job_id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `inactivity_reminders`
--
ALTER TABLE `inactivity_reminders`
  MODIFY `reminder_id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `inactivity_reminder_sends`
--
ALTER TABLE `inactivity_reminder_sends`
  MODIFY `send_id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `notification_log`
--
ALTER TABLE `notification_log`
  MODIFY `notification_id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=6;

--
-- AUTO_INCREMENT for table `status_transitions`
--
ALTER TABLE `status_transitions`
  MODIFY `transition_id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=19;

--
-- AUTO_INCREMENT for table `trusted_contacts`
--
ALTER TABLE `trusted_contacts`
  MODIFY `contact_id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `users`
--
ALTER TABLE `users`
  MODIFY `user_id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `vault_entries`
--
ALTER TABLE `vault_entries`
  MODIFY `vault_id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=18;

--
-- Constraints for dumped tables
--

--
-- Constraints for table `asset_beneficiaries`
--
ALTER TABLE `asset_beneficiaries`
  ADD CONSTRAINT `fk_ab_asset_id` FOREIGN KEY (`asset_id`) REFERENCES `digital_assets` (`asset_id`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `fk_ab_beneficiary_id` FOREIGN KEY (`beneficiary_id`) REFERENCES `beneficiaries` (`beneficiary_id`) ON UPDATE CASCADE;

--
-- Constraints for table `audit_log`
--
ALTER TABLE `audit_log`
  ADD CONSTRAINT `fk_al_user_id` FOREIGN KEY (`user_id`) REFERENCES `users` (`user_id`) ON DELETE SET NULL ON UPDATE CASCADE;

--
-- Constraints for table `checkin_log`
--
ALTER TABLE `checkin_log`
  ADD CONSTRAINT `fk_cl_user_id` FOREIGN KEY (`user_id`) REFERENCES `users` (`user_id`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Constraints for table `contact_confirmations`
--
ALTER TABLE `contact_confirmations`
  ADD CONSTRAINT `fk_cc_contact_id` FOREIGN KEY (`contact_id`) REFERENCES `trusted_contacts` (`contact_id`) ON UPDATE CASCADE,
  ADD CONSTRAINT `fk_cc_verification_id` FOREIGN KEY (`verification_id`) REFERENCES `death_verifications` (`verification_id`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Constraints for table `death_trigger_rules`
--
ALTER TABLE `death_trigger_rules`
  ADD CONSTRAINT `fk_dtr_user_id` FOREIGN KEY (`user_id`) REFERENCES `users` (`user_id`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Constraints for table `death_verifications`
--
ALTER TABLE `death_verifications`
  ADD CONSTRAINT `fk_dv_initiated_by` FOREIGN KEY (`initiated_by`) REFERENCES `trusted_contacts` (`contact_id`) ON DELETE SET NULL ON UPDATE CASCADE,
  ADD CONSTRAINT `fk_dv_user_id` FOREIGN KEY (`user_id`) REFERENCES `users` (`user_id`) ON UPDATE CASCADE;

--
-- Constraints for table `digital_assets`
--
ALTER TABLE `digital_assets`
  ADD CONSTRAINT `fk_da_user_id` FOREIGN KEY (`user_id`) REFERENCES `users` (`user_id`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Constraints for table `execution_jobs`
--
ALTER TABLE `execution_jobs`
  ADD CONSTRAINT `fk_ej_asset_id` FOREIGN KEY (`asset_id`) REFERENCES `digital_assets` (`asset_id`) ON UPDATE CASCADE,
  ADD CONSTRAINT `fk_ej_beneficiary_id` FOREIGN KEY (`beneficiary_id`) REFERENCES `beneficiaries` (`beneficiary_id`) ON UPDATE CASCADE,
  ADD CONSTRAINT `fk_ej_user_id` FOREIGN KEY (`user_id`) REFERENCES `users` (`user_id`) ON UPDATE CASCADE;

--
-- Constraints for table `inactivity_reminders`
--
ALTER TABLE `inactivity_reminders`
  ADD CONSTRAINT `fk_ir_user_id` FOREIGN KEY (`user_id`) REFERENCES `users` (`user_id`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Constraints for table `inactivity_reminder_sends`
--
ALTER TABLE `inactivity_reminder_sends`
  ADD CONSTRAINT `fk_irs_reminder_id` FOREIGN KEY (`reminder_id`) REFERENCES `inactivity_reminders` (`reminder_id`) ON DELETE SET NULL ON UPDATE CASCADE,
  ADD CONSTRAINT `fk_irs_user_id` FOREIGN KEY (`user_id`) REFERENCES `users` (`user_id`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Constraints for table `notification_log`
--
ALTER TABLE `notification_log`
  ADD CONSTRAINT `fk_nl_user_id` FOREIGN KEY (`user_id`) REFERENCES `users` (`user_id`) ON DELETE SET NULL ON UPDATE CASCADE;

--
-- Constraints for table `status_transitions`
--
ALTER TABLE `status_transitions`
  ADD CONSTRAINT `fk_st_rule_id` FOREIGN KEY (`rule_id`) REFERENCES `death_trigger_rules` (`rule_id`) ON DELETE SET NULL ON UPDATE CASCADE,
  ADD CONSTRAINT `fk_st_user_id` FOREIGN KEY (`user_id`) REFERENCES `users` (`user_id`) ON UPDATE CASCADE,
  ADD CONSTRAINT `fk_st_verification_id` FOREIGN KEY (`verification_id`) REFERENCES `death_verifications` (`verification_id`) ON DELETE SET NULL ON UPDATE CASCADE;

--
-- Constraints for table `trusted_contacts`
--
ALTER TABLE `trusted_contacts`
  ADD CONSTRAINT `fk_tc_user_id` FOREIGN KEY (`user_id`) REFERENCES `users` (`user_id`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Constraints for table `vault_entries`
--
ALTER TABLE `vault_entries`
  ADD CONSTRAINT `fk_ve_asset_id` FOREIGN KEY (`asset_id`) REFERENCES `digital_assets` (`asset_id`) ON DELETE CASCADE ON UPDATE CASCADE;

DELIMITER $$
--
-- Events
--
CREATE DEFINER=`root`@`localhost` EVENT `evt_daily_inactivity_check` ON SCHEDULE EVERY 1 DAY STARTS '2026-04-14 02:00:00' ON COMPLETION NOT PRESERVE ENABLE COMMENT 'Daily check: flags users who exceeded their inactivity threshold' DO BEGIN
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

CREATE DEFINER=`root`@`localhost` EVENT `evt_expire_stale_verifications` ON SCHEDULE EVERY 1 DAY STARTS '2026-04-14 03:00:00' ON COMPLETION NOT PRESERVE ENABLE COMMENT 'Expire verifications that missed their quorum deadline' DO BEGIN
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
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
