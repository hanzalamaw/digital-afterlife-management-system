<?php
namespace DAMS\Controllers;

use DAMS\Config\Database;
use DAMS\Middleware\JWTMiddleware;
use DAMS\Utils\Http;

/**
 * Aggregated dashboard data so the React client only needs ONE round-trip.
 */
class DashboardController {
    public function summary(): void {
        $payload = JWTMiddleware::validateToken();
        $userId  = (int)($payload['user_id'] ?? 0);

        $pdo = Database::getConnection();

        // --- User snapshot ----------------------------------------------------
        $userStmt = $pdo->prepare('
            SELECT user_id, full_name, email, account_status, last_checkin_at,
                   DATEDIFF(NOW(), last_checkin_at) AS days_since_checkin,
                   created_at
            FROM users WHERE user_id = ? LIMIT 1
        ');
        $userStmt->execute([$userId]);
        $user = $userStmt->fetch() ?: [];

        // --- Assets aggregates -----------------------------------------------
        $assetsAgg = $pdo->prepare('
            SELECT
                COUNT(*)                                                AS total,
                COALESCE(SUM(include_in_estate = 1), 0)                 AS included,
                COALESCE(SUM(include_in_estate = 0), 0)                 AS excluded,
                COALESCE(SUM(require_contact_verify = 1), 0)            AS gated,
                COALESCE(SUM(status = "active"), 0)                     AS active,
                COALESCE(SUM(status = "pending_execution"), 0)          AS pending_execution,
                COALESCE(SUM(status = "executed"), 0)                   AS executed,
                COALESCE(SUM(status = "cancelled"), 0)                  AS cancelled,
                COALESCE(SUM(beneficiary_count), 0)                     AS beneficiary_links,
                COALESCE(SUM(vault_count), 0)                           AS vault_entries
            FROM asset_summary WHERE user_id = ?
        ');
        $assetsAgg->execute([$userId]);
        $assets = $assetsAgg->fetch() ?: [];

        // --- Asset type breakdown --------------------------------------------
        $typeStmt = $pdo->prepare('
            SELECT asset_type, COUNT(*) AS cnt
            FROM digital_assets WHERE user_id = ?
            GROUP BY asset_type ORDER BY cnt DESC
        ');
        $typeStmt->execute([$userId]);
        $byType = [];
        foreach ($typeStmt->fetchAll() as $r) {
            $byType[$r['asset_type']] = (int)$r['cnt'];
        }

        // --- Beneficiaries (unique people across all this user's assets) ----
        $beneficiaryStmt = $pdo->prepare('
            SELECT COUNT(DISTINCT b.beneficiary_id) AS unique_count,
                   COUNT(DISTINCT b.email)          AS unique_emails
            FROM beneficiaries b
            JOIN asset_beneficiaries ab ON ab.beneficiary_id = b.beneficiary_id
            JOIN digital_assets a       ON a.asset_id = ab.asset_id
            WHERE a.user_id = ?
        ');
        $beneficiaryStmt->execute([$userId]);
        $beneficiaries = $beneficiaryStmt->fetch() ?: ['unique_count' => 0, 'unique_emails' => 0];

        // --- Trusted contacts -------------------------------------------------
        $tcStmt = $pdo->prepare('
            SELECT
                COUNT(*)                                                AS total,
                COALESCE(SUM(verification_status = "verified"), 0)      AS verified,
                COALESCE(SUM(verification_status = "pending"), 0)       AS pending
            FROM trusted_contacts WHERE user_id = ?
        ');
        $tcStmt->execute([$userId]);
        $contacts = $tcStmt->fetch() ?: ['total' => 0, 'verified' => 0, 'pending' => 0];

        // --- Death rules ------------------------------------------------------
        $inactivityStmt = $pdo->prepare("
            SELECT rule_id, inactivity_days, grace_period_days, is_active
            FROM death_trigger_rules
            WHERE user_id = ? AND rule_type = 'inactivity_timer'
            ORDER BY is_active DESC, created_at DESC LIMIT 1
        ");
        $inactivityStmt->execute([$userId]);
        $inactivity = $inactivityStmt->fetch() ?: null;

        $quorumStmt = $pdo->prepare("
            SELECT rule_id, quorum_required, grace_period_days, is_active
            FROM death_trigger_rules
            WHERE user_id = ? AND rule_type = 'quorum_vote'
            ORDER BY is_active DESC, created_at DESC LIMIT 1
        ");
        $quorumStmt->execute([$userId]);
        $quorum = $quorumStmt->fetch() ?: null;

        $remindersStmt = $pdo->prepare('
            SELECT COUNT(*) AS total FROM inactivity_reminders WHERE user_id = ?
        ');
        $remindersStmt->execute([$userId]);
        $remindersCount = (int)($remindersStmt->fetch()['total'] ?? 0);

        $firedStmt = $pdo->prepare('
            SELECT COUNT(*) AS fired FROM inactivity_reminder_sends WHERE user_id = ?
        ');
        $firedStmt->execute([$userId]);
        $remindersFired = (int)($firedStmt->fetch()['fired'] ?? 0);

        // --- Inactivity progress ---------------------------------------------
        $daysInactive = (int)($user['days_since_checkin'] ?? 0);
        $budget       = $inactivity ? (int)$inactivity['inactivity_days'] : 0;
        $pctUsed      = ($budget > 0) ? min(100, (int)round(($daysInactive / $budget) * 100)) : 0;
        $daysRemain   = max(0, $budget - $daysInactive);

        // --- Notifications stats ---------------------------------------------
        $notifStmt = $pdo->prepare('
            SELECT category, status, COUNT(*) AS cnt
            FROM notification_log
            WHERE user_id = ? OR user_id IS NULL
            GROUP BY category, status
        ');
        $notifStmt->execute([$userId]);
        $notifByCategory = [];
        $totalSent = 0;
        $totalFailed = 0;
        foreach ($notifStmt->fetchAll() as $row) {
            $cat = $row['category'];
            $status = $row['status'];
            $cnt = (int)$row['cnt'];
            if (!isset($notifByCategory[$cat])) $notifByCategory[$cat] = ['sent' => 0, 'failed' => 0, 'queued' => 0];
            $notifByCategory[$cat][$status] = $cnt;
            if ($status === 'sent') $totalSent += $cnt;
            if ($status === 'failed') $totalFailed += $cnt;
        }

        // --- Recent activity --------------------------------------------------
        $recentTransitions = $pdo->prepare('
            SELECT transition_id, from_status, to_status, triggered_by, notes, transitioned_at
            FROM status_transitions
            WHERE user_id = ?
            ORDER BY transitioned_at DESC LIMIT 5
        ');
        $recentTransitions->execute([$userId]);

        $recentNotifications = $pdo->prepare('
            SELECT notification_id, recipient_email, recipient_name, subject,
                   category, status, created_at, sent_at
            FROM notification_log
            WHERE user_id = ? OR user_id IS NULL
            ORDER BY notification_id DESC LIMIT 5
        ');
        $recentNotifications->execute([$userId]);

        // --- Open death verifications ----------------------------------------
        $verifStmt = $pdo->prepare("
            SELECT verification_id, status, confirmations_received, confirmations_required,
                   trigger_source, initiated_at, expires_at
            FROM death_verifications
            WHERE user_id = ? AND status IN ('initiated','awaiting_quorum')
            ORDER BY initiated_at DESC LIMIT 5
        ");
        $verifStmt->execute([$userId]);

        Http::json([
            'user'        => $user,
            'assets'      => [
                'total'             => (int)($assets['total'] ?? 0),
                'included'          => (int)($assets['included'] ?? 0),
                'excluded'          => (int)($assets['excluded'] ?? 0),
                'gated'             => (int)($assets['gated'] ?? 0),
                'active'            => (int)($assets['active'] ?? 0),
                'pending_execution' => (int)($assets['pending_execution'] ?? 0),
                'executed'          => (int)($assets['executed'] ?? 0),
                'cancelled'         => (int)($assets['cancelled'] ?? 0),
                'beneficiary_links' => (int)($assets['beneficiary_links'] ?? 0),
                'vault_entries'     => (int)($assets['vault_entries'] ?? 0),
                'by_type'           => $byType,
            ],
            'beneficiaries' => [
                'unique_count'  => (int)$beneficiaries['unique_count'],
                'unique_emails' => (int)$beneficiaries['unique_emails'],
            ],
            'trusted_contacts' => [
                'total'    => (int)$contacts['total'],
                'verified' => (int)$contacts['verified'],
                'pending'  => (int)$contacts['pending'],
            ],
            'death_rules' => [
                'inactivity' => $inactivity ?: null,
                'quorum'     => $quorum ?: null,
                'reminders_configured' => $remindersCount,
                'reminders_fired'      => $remindersFired,
            ],
            'inactivity' => [
                'days_used'      => $daysInactive,
                'days_remaining' => $daysRemain,
                'percent_used'   => $pctUsed,
                'budget'         => $budget,
            ],
            'notifications' => [
                'total_sent'   => $totalSent,
                'total_failed' => $totalFailed,
                'by_category'  => $notifByCategory,
            ],
            'recent_transitions'   => $recentTransitions->fetchAll(),
            'recent_notifications' => $recentNotifications->fetchAll(),
            'open_verifications'   => $verifStmt->fetchAll(),
        ]);
    }
}
