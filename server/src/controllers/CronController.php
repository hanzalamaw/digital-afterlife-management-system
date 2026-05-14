<?php
namespace DAMS\Controllers;

use DAMS\Config\Database;
use DAMS\Utils\Http;
use DAMS\Utils\Mailer;

/**
 * Scheduled-job style controller.
 *
 * Three ways the sweep runs:
 *
 *  1) AUTO (preferred): server/index.php silently calls
 *     CronController::runAutoIfDue() on every API request. A timestamp file
 *     at server/logs/.last_sweep throttles it to AUTO_SWEEP_INTERVAL_SECONDS.
 *     No external scheduler required.
 *
 *  2) MANUAL HTTP: POST /api/cron/inactivity-sweep?token=<CRON_SECRET>
 *     for triggering from Task Scheduler / curl.
 *
 *  3) ADMIN BUTTON (optional): you can wire this to an admin UI later.
 *
 * The actual work lives in performSweep() so all three paths share code.
 */
class CronController {
    /**
     * Public HTTP endpoint. Requires the CRON_SECRET token.
     */
    public function runInactivitySweep(): void {
        $expected = (string)($_ENV['CRON_SECRET'] ?? '');
        if ($expected === '') {
            Http::json(['error' => 'CRON_SECRET not configured'], 503);
            return;
        }
        $provided = $_GET['token']
            ?? ($_SERVER['HTTP_X_CRON_TOKEN'] ?? '');
        if (!hash_equals($expected, (string)$provided)) {
            Http::json(['error' => 'Forbidden'], 403);
            return;
        }
        $result = $this->performSweep();
        Http::json([
            'message' => 'Inactivity sweep completed',
            'mode'    => 'manual',
        ] + $result);
    }

    /**
     * Called from server/index.php on every API hit. Returns silently and
     * does nothing if the throttle window hasn't elapsed.
     */
    public static function runAutoIfDue(): void {
        $intervalSec = (int)($_ENV['AUTO_SWEEP_INTERVAL_SECONDS'] ?? 900);
        if ($intervalSec <= 0) return; // disabled

        $logsDir = __DIR__ . '/../../logs';
        if (!is_dir($logsDir)) @mkdir($logsDir, 0775, true);
        $stamp = $logsDir . '/.last_sweep';

        $last = is_file($stamp) ? (int)@file_get_contents($stamp) : 0;
        $now  = time();
        if (($now - $last) < $intervalSec) return;

        // Reserve the slot up front so concurrent requests don't both run it.
        @file_put_contents($stamp, (string)$now, LOCK_EX);

        try {
            (new self())->performSweep();
        } catch (\Throwable $e) {
            @file_put_contents(
                $logsDir . '/cron.log',
                sprintf("[%s] auto-sweep error: %s\n", date('Y-m-d H:i:s'), $e->getMessage()),
                FILE_APPEND
            );
        }
    }

    /**
     * The actual sweep logic. Returns counters for the manual response.
     */
    private function performSweep(): array {
        $pdo = Database::getConnection();

        $remindersSent     = 0;
        $suspectedFlagged  = 0;
        $confirmedExecuted = 0;
        $totalEmails       = 0;

        $usersStmt = $pdo->query("
            SELECT u.user_id, u.full_name, u.email, u.account_status,
                   u.last_checkin_at,
                   DATEDIFF(NOW(), u.last_checkin_at) AS days_inactive,
                   r.inactivity_days, r.grace_period_days
            FROM users u
            JOIN death_trigger_rules r
              ON r.user_id = u.user_id
             AND r.rule_type = 'inactivity_timer'
             AND r.is_active = 1
            WHERE u.account_status = 'Active'
        ");
        $users = $usersStmt->fetchAll();

        $sentLogStmt   = $pdo->prepare('
            SELECT 1 FROM inactivity_reminder_sends
            WHERE user_id = ? AND threshold_percent = ? LIMIT 1
        ');
        $logSendStmt   = $pdo->prepare('
            INSERT INTO inactivity_reminder_sends (user_id, reminder_id, threshold_percent)
            VALUES (?, ?, ?)
        ');
        $remindersStmt = $pdo->prepare('
            SELECT reminder_id, threshold_percent, custom_message
            FROM inactivity_reminders WHERE user_id = ?
            ORDER BY threshold_percent ASC
        ');

        foreach ($users as $u) {
            $userId = (int)$u['user_id'];
            $days   = max(0, (int)$u['days_inactive']);
            $budget = (int)$u['inactivity_days'];
            if ($budget <= 0) continue;
            $pct = (int)floor(($days / $budget) * 100);

            $remindersStmt->execute([$userId]);
            $reminders = $remindersStmt->fetchAll();

            foreach ($reminders as $r) {
                if ($pct < (int)$r['threshold_percent']) continue;
                $sentLogStmt->execute([$userId, (int)$r['threshold_percent']]);
                if ($sentLogStmt->fetch()) continue;

                $subject = sprintf(
                    'DAMS Check-in Reminder (%d%% of inactivity threshold reached)',
                    (int)$r['threshold_percent']
                );
                $body = ($r['custom_message'] && trim($r['custom_message']) !== '')
                    ? (string)$r['custom_message']
                    : sprintf(
                        "Hello %s,\n\nWe noticed you have not checked in for %d days. Your account will be flagged after %d days of inactivity.\nLog in to reset the timer.\n",
                        $u['full_name'], $days, $budget
                    );

                if (Mailer::send($userId, $u['email'], $u['full_name'], $subject, $body, 'reminder')) {
                    $remindersSent++;
                    $totalEmails++;
                }
                $logSendStmt->execute([$userId, $r['reminder_id'] ?? null, (int)$r['threshold_percent']]);
            }

            if ($days >= $budget) {
                $pdo->prepare("UPDATE users SET account_status = 'Flagged' WHERE user_id = ? AND account_status = 'Active'")
                    ->execute([$userId]);
                $suspectedFlagged++;

                // Open a death_verifications row so the grace period can be tracked
                // and trusted contacts have something to vote against. Only create
                // one if there isn't already an open one.
                $hasOpen = $pdo->prepare("
                    SELECT verification_id FROM death_verifications
                    WHERE user_id = ? AND status IN ('initiated','awaiting_quorum')
                    LIMIT 1
                ");
                $hasOpen->execute([$userId]);
                if (!$hasOpen->fetch()) {
                    $grace = (int)($u['grace_period_days'] ?? 7);
                    $quorumStmt = $pdo->prepare("
                        SELECT quorum_required FROM death_trigger_rules
                        WHERE user_id = ? AND rule_type='quorum_vote' AND is_active=1
                        ORDER BY created_at DESC LIMIT 1
                    ");
                    $quorumStmt->execute([$userId]);
                    $quorumRequired = (int)($quorumStmt->fetch()['quorum_required'] ?? 1);

                    $pdo->prepare("
                        INSERT INTO death_verifications
                          (user_id, status, confirmations_received, confirmations_required,
                           trigger_source, initiated_at, expires_at)
                        VALUES (?, 'awaiting_quorum', 0, ?, 'inactivity_timer', NOW(),
                                DATE_ADD(NOW(), INTERVAL ? DAY))
                    ")->execute([$userId, max(1, $quorumRequired), max(1, $grace)]);
                }

                $totalEmails += $this->emailBeneficiaries(
                    $userId,
                    sprintf('DAMS: %s is suspected to have passed away', $u['full_name']),
                    sprintf(
                        "Dear beneficiary,\n\n%s has not checked in to their Digital Afterlife Management account for %d days, which exceeds their %d-day inactivity threshold. Their account is now Flagged.\n\nIf you believe this is a mistake, please contact the user directly.\nIf the trusted contact quorum confirms, asset transfer instructions will follow.\n\nThis is an automated notification.",
                        $u['full_name'], $days, $budget
                    ),
                    'suspect_death'
                );

                $totalEmails += $this->emailTrustedContacts(
                    $userId,
                    sprintf('DAMS: Action requested — confirm status of %s', $u['full_name']),
                    sprintf(
                        "Hello,\n\nYou were listed as a trusted contact for %s. Their account has crossed the inactivity threshold (%d days). Please verify whether they are still active and use your DAMS confirmation portal to respond.\n\nThis is an automated notification.",
                        $u['full_name'], $budget
                    ),
                    'contact_request'
                );
            }
        }

        // Expire grace periods: if a verification has been open longer than its
        // expires_at and the user hasn't returned, mark it expired. We do NOT
        // auto-confirm death — that requires quorum.
        $pdo->exec("
            UPDATE death_verifications
            SET status = 'expired'
            WHERE status IN ('initiated','awaiting_quorum')
              AND expires_at IS NOT NULL
              AND expires_at < NOW()
        ");

        // Confirmed-deceased mail-out (idempotent via notification_log).
        $deceased = $pdo->query("
            SELECT u.user_id, u.full_name, u.email
            FROM users u
            WHERE u.account_status = 'Deceased'
              AND NOT EXISTS (
                  SELECT 1 FROM notification_log nl
                  WHERE nl.user_id = u.user_id AND nl.category = 'confirmed_death'
              )
        ")->fetchAll();

        foreach ($deceased as $u) {
            $userId = (int)$u['user_id'];
            $totalEmails += $this->emailBeneficiaries(
                $userId,
                sprintf('DAMS: %s has been confirmed deceased', $u['full_name']),
                sprintf(
                    "Dear beneficiary,\n\nIt is with regret that we inform you that %s has been confirmed deceased through the DAMS verification process.\n\nYour share of their digital estate is now being processed. You will receive a separate secure message with credentials and instructions for any assets assigned to you.\n\nThis is an automated notification.",
                    $u['full_name']
                ),
                'confirmed_death'
            );
            $confirmedExecuted++;
        }

        return [
            'reminders_sent'      => $remindersSent,
            'users_flagged'       => $suspectedFlagged,
            'confirmed_processed' => $confirmedExecuted,
            'emails_attempted'    => $totalEmails,
        ];
    }

    private function emailBeneficiaries(int $userId, string $subject, string $body, string $category): int {
        $pdo = Database::getConnection();
        $stmt = $pdo->prepare('
            SELECT DISTINCT b.email, b.full_name
            FROM beneficiaries b
            JOIN asset_beneficiaries ab ON ab.beneficiary_id = b.beneficiary_id
            JOIN digital_assets a       ON a.asset_id = ab.asset_id
            WHERE a.user_id = ? AND a.include_in_estate = 1
        ');
        $stmt->execute([$userId]);
        $count = 0;
        foreach ($stmt->fetchAll() as $row) {
            if (Mailer::send($userId, $row['email'], $row['full_name'], $subject, $body, $category)) {
                $count++;
            }
        }
        return $count;
    }

    private function emailTrustedContacts(int $userId, string $subject, string $body, string $category): int {
        $pdo = Database::getConnection();
        $stmt = $pdo->prepare('
            SELECT email, full_name FROM trusted_contacts WHERE user_id = ? ORDER BY priority_order ASC
        ');
        $stmt->execute([$userId]);
        $count = 0;
        foreach ($stmt->fetchAll() as $row) {
            if (Mailer::send($userId, $row['email'], $row['full_name'], $subject, $body, $category)) {
                $count++;
            }
        }
        return $count;
    }
}
