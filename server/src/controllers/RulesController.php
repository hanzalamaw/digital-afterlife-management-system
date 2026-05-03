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
        } else { // combined_and
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
}

