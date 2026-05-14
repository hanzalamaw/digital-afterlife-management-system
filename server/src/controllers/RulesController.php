<?php
namespace DAMS\Controllers;

use DAMS\Config\Database;
use DAMS\Middleware\JWTMiddleware;
use DAMS\Utils\Http;

class RulesController {
    public function getMyRules(): void {
        $payload = JWTMiddleware::validateToken();
        $userId = (int)($payload['user_id'] ?? 0);

        $pdo = Database::getConnection();
        $stmt = $pdo->prepare('
            SELECT rule_id, rule_type, inactivity_days, quorum_required, grace_period_days, logic_operator, is_active, created_at
            FROM death_trigger_rules
            WHERE user_id = ?
            ORDER BY is_active DESC, created_at DESC
        ');
        $stmt->execute([$userId]);
        Http::json(['rules' => $stmt->fetchAll()]);
    }

    public function upsertMyActiveRule(): void {
        $payload = JWTMiddleware::validateToken();
        $userId = (int)($payload['user_id'] ?? 0);
        $data = Http::readJsonBody();

        $ruleType = (string)($data['rule_type'] ?? '');
        $allowed = ['inactivity_timer', 'quorum_vote', 'combined_and'];
        if (!in_array($ruleType, $allowed, true)) {
            Http::json(['error' => 'Invalid rule_type'], 400);
            return;
        }

        $inactivityDays = isset($data['inactivity_days']) ? (int)$data['inactivity_days'] : null;
        $quorumRequired = isset($data['quorum_required']) ? (int)$data['quorum_required'] : null;
        $gracePeriodDays = isset($data['grace_period_days']) ? (int)$data['grace_period_days'] : 7;

        if ($gracePeriodDays < 1 || $gracePeriodDays > 3650) {
            Http::json(['error' => 'grace_period_days out of range'], 400);
            return;
        }

        if ($ruleType === 'inactivity_timer') {
            if ($inactivityDays === null || $inactivityDays < 7) {
                Http::json(['error' => 'inactivity_days must be >= 7'], 400);
                return;
            }
            $quorumRequired = null;
        } elseif ($ruleType === 'quorum_vote') {
            if ($quorumRequired === null || $quorumRequired < 1) {
                Http::json(['error' => 'quorum_required must be >= 1'], 400);
                return;
            }
            $inactivityDays = null;
        } else {
            if ($inactivityDays === null || $inactivityDays < 7) {
                Http::json(['error' => 'inactivity_days must be >= 7'], 400);
                return;
            }
            if ($quorumRequired === null || $quorumRequired < 1) {
                Http::json(['error' => 'quorum_required must be >= 1'], 400);
                return;
            }
        }

        $pdo = Database::getConnection();
        $pdo->beginTransaction();
        try {
            $pdo->prepare('UPDATE death_trigger_rules SET is_active = 0 WHERE user_id = ?')->execute([$userId]);

            $stmt = $pdo->prepare('
                INSERT INTO death_trigger_rules
                    (user_id, rule_type, inactivity_days, quorum_required, grace_period_days, logic_operator, is_active)
                VALUES (?, ?, ?, ?, ?, ?, 1)
            ');
            $stmt->execute([
                $userId,
                $ruleType,
                $inactivityDays,
                $quorumRequired,
                $gracePeriodDays,
                $ruleType === 'combined_and' ? 'AND' : null,
            ]);

            $pdo->commit();
            Http::json(['message' => 'Rule saved']);
        } catch (\Throwable $e) {
            $pdo->rollBack();
            Http::json(['error' => 'Failed to save rule'], 500);
        }
    }

    /**
     * GET /api/death-rules
     * Returns BOTH rules (inactivity + quorum) and the list of reminders.
     * If a rule has never been saved, sensible defaults are returned.
     */
    public function getDeathRules(): void {
        $payload = JWTMiddleware::validateToken();
        $userId = (int)($payload['user_id'] ?? 0);

        $pdo = Database::getConnection();

        $inactivity = $pdo->prepare("
            SELECT rule_id, inactivity_days, grace_period_days, is_active
            FROM death_trigger_rules
            WHERE user_id = ? AND rule_type = 'inactivity_timer'
            ORDER BY is_active DESC, created_at DESC
            LIMIT 1
        ");
        $inactivity->execute([$userId]);
        $inactivityRule = $inactivity->fetch() ?: null;

        $quorum = $pdo->prepare("
            SELECT rule_id, quorum_required, grace_period_days, is_active
            FROM death_trigger_rules
            WHERE user_id = ? AND rule_type = 'quorum_vote'
            ORDER BY is_active DESC, created_at DESC
            LIMIT 1
        ");
        $quorum->execute([$userId]);
        $quorumRule = $quorum->fetch() ?: null;

        $reminderStmt = $pdo->prepare('
            SELECT reminder_id, threshold_percent, custom_message, created_at
            FROM inactivity_reminders
            WHERE user_id = ?
            ORDER BY threshold_percent ASC, reminder_id ASC
        ');
        $reminderStmt->execute([$userId]);
        $reminders = $reminderStmt->fetchAll();

        Http::json([
            'inactivity' => $inactivityRule ?: [
                'rule_id' => null,
                'inactivity_days' => 60,
                'grace_period_days' => 7,
                'is_active' => 0,
            ],
            'quorum' => $quorumRule ?: [
                'rule_id' => null,
                'quorum_required' => 2,
                'grace_period_days' => 7,
                'is_active' => 0,
            ],
            'reminders' => $reminders,
        ]);
    }

    /**
     * PUT /api/death-rules/inactivity
     * Body: { inactivity_days, grace_period_days, reminders: [{ threshold_percent, custom_message }] }
     */
    public function saveInactivity(): void {
        $payload = JWTMiddleware::validateToken();
        $userId = (int)($payload['user_id'] ?? 0);
        $data = Http::readJsonBody();

        $inactivityDays = isset($data['inactivity_days']) ? (int)$data['inactivity_days'] : 0;
        $gracePeriodDays = isset($data['grace_period_days']) ? (int)$data['grace_period_days'] : 7;

        if ($inactivityDays < 7 || $inactivityDays > 3650) {
            Http::json(['error' => 'Pronounce-dead days must be between 7 and 3650.'], 400);
            return;
        }
        if ($gracePeriodDays < 1 || $gracePeriodDays > 3650) {
            Http::json(['error' => 'Grace period out of range.'], 400);
            return;
        }

        $reminders = is_array($data['reminders'] ?? null) ? $data['reminders'] : [];
        foreach ($reminders as $r) {
            $t = (int)($r['threshold_percent'] ?? 0);
            if ($t < 1 || $t > 99) {
                Http::json(['error' => 'Each reminder threshold must be between 1 and 99 percent.'], 400);
                return;
            }
        }

        $pdo = Database::getConnection();
        $pdo->beginTransaction();
        try {
            $pdo->prepare("UPDATE death_trigger_rules SET is_active = 0 WHERE user_id = ? AND rule_type = 'inactivity_timer'")
                ->execute([$userId]);

            $pdo->prepare("
                INSERT INTO death_trigger_rules
                    (user_id, rule_type, inactivity_days, quorum_required, grace_period_days, logic_operator, is_active)
                VALUES (?, 'inactivity_timer', ?, NULL, ?, NULL, 1)
            ")->execute([$userId, $inactivityDays, $gracePeriodDays]);

            // Replace reminders wholesale (simpler than diffing).
            $pdo->prepare('DELETE FROM inactivity_reminders WHERE user_id = ?')->execute([$userId]);
            $insertReminder = $pdo->prepare('
                INSERT INTO inactivity_reminders (user_id, threshold_percent, custom_message)
                VALUES (?, ?, ?)
            ');
            foreach ($reminders as $r) {
                $msg = isset($r['custom_message']) && trim((string)$r['custom_message']) !== ''
                    ? (string)$r['custom_message']
                    : null;
                $insertReminder->execute([$userId, (int)$r['threshold_percent'], $msg]);
            }

            // Clear the send-log because settings changed.
            $pdo->prepare('DELETE FROM inactivity_reminder_sends WHERE user_id = ?')->execute([$userId]);

            $pdo->commit();
            Http::json(['message' => 'Inactivity rule saved.']);
        } catch (\Throwable $e) {
            $pdo->rollBack();
            Http::json(['error' => 'Failed to save inactivity rule.'], 500);
        }
    }

    /**
     * PUT /api/death-rules/quorum
     * Body: { quorum_required, grace_period_days }
     */
    public function saveQuorum(): void {
        $payload = JWTMiddleware::validateToken();
        $userId = (int)($payload['user_id'] ?? 0);
        $data = Http::readJsonBody();

        $quorumRequired = isset($data['quorum_required']) ? (int)$data['quorum_required'] : 0;
        $gracePeriodDays = isset($data['grace_period_days']) ? (int)$data['grace_period_days'] : 7;

        if ($quorumRequired < 1 || $quorumRequired > 50) {
            Http::json(['error' => 'Quorum required must be between 1 and 50.'], 400);
            return;
        }
        if ($gracePeriodDays < 1 || $gracePeriodDays > 3650) {
            Http::json(['error' => 'Grace period out of range.'], 400);
            return;
        }

        $pdo = Database::getConnection();
        $pdo->beginTransaction();
        try {
            $pdo->prepare("UPDATE death_trigger_rules SET is_active = 0 WHERE user_id = ? AND rule_type = 'quorum_vote'")
                ->execute([$userId]);

            $pdo->prepare("
                INSERT INTO death_trigger_rules
                    (user_id, rule_type, inactivity_days, quorum_required, grace_period_days, logic_operator, is_active)
                VALUES (?, 'quorum_vote', NULL, ?, ?, NULL, 1)
            ")->execute([$userId, $quorumRequired, $gracePeriodDays]);

            $pdo->commit();
            Http::json(['message' => 'Trusted-contacts rule saved.']);
        } catch (\Throwable $e) {
            $pdo->rollBack();
            Http::json(['error' => 'Failed to save quorum rule.'], 500);
        }
    }
}
