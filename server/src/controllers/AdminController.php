<?php
namespace DAMS\Controllers;

use DAMS\Config\Database;
use DAMS\Middleware\JWTMiddleware;
use DAMS\Utils\Http;
use DAMS\Utils\Mailer;

class AdminController {
    private function requireAdmin(): int {
        $payload = JWTMiddleware::validateToken();
        $userId = (int)($payload['user_id'] ?? 0);

        $pdo = Database::getConnection();
        $columns = $pdo->query('SHOW COLUMNS FROM users')->fetchAll();
        $hasIsAdmin = false;
        foreach ($columns as $col) {
            if (($col['Field'] ?? '') === 'is_admin') {
                $hasIsAdmin = true;
                break;
            }
        }

        if (!$hasIsAdmin) {
            Http::json(['error' => 'Admin mode is not configured in this database schema'], 403);
            exit;
        }

        $stmt = $pdo->prepare('SELECT is_admin FROM users WHERE user_id = ?');
        $stmt->execute([$userId]);
        $row = $stmt->fetch();
        $isAdmin = (int)($row['is_admin'] ?? 0);
        if ($isAdmin !== 1) {
            Http::json(['error' => 'Forbidden'], 403);
            exit;
        }
        return $userId;
    }

    public function usersSummary(): void {
        $this->requireAdmin();
        $pdo = Database::getConnection();
        $rows = $pdo->query('SELECT * FROM user_estate_summary ORDER BY user_id')->fetchAll();
        Http::json(['users' => $rows]);
    }

    public function pendingExecutions(): void {
        $this->requireAdmin();
        $pdo = Database::getConnection();
        $rows = $pdo->query('SELECT * FROM pending_executions ORDER BY user_id, asset_id')->fetchAll();
        Http::json(['jobs' => $rows]);
    }

    public function deathVerifications(): void {
        $this->requireAdmin();
        $pdo = Database::getConnection();
        $rows = $pdo->query('SELECT * FROM death_verification_status ORDER BY initiated_at DESC')->fetchAll();
        Http::json(['verifications' => $rows]);
    }

    /**
     * POST /api/admin/users/{id}/notify-inheritors
     * Body: { stage: "suspect" | "confirmed" }
     * Sends emails to all beneficiaries of every asset belonging to the user.
     */
    public function notifyInheritors(int $targetUserId): void {
        $this->requireAdmin();
        $data = Http::readJsonBody();
        $stage = (string)($data['stage'] ?? 'suspect');
        if (!in_array($stage, ['suspect', 'confirmed'], true)) {
            Http::json(['error' => 'stage must be suspect or confirmed'], 400);
            return;
        }

        $pdo = Database::getConnection();
        $userStmt = $pdo->prepare('SELECT user_id, full_name, email FROM users WHERE user_id = ? LIMIT 1');
        $userStmt->execute([$targetUserId]);
        $user = $userStmt->fetch();
        if (!$user) {
            Http::json(['error' => 'User not found'], 404);
            return;
        }

        $stmt = $pdo->prepare('
            SELECT DISTINCT b.email, b.full_name
            FROM beneficiaries b
            JOIN asset_beneficiaries ab ON ab.beneficiary_id = b.beneficiary_id
            JOIN digital_assets a       ON a.asset_id = ab.asset_id
            WHERE a.user_id = ? AND a.include_in_estate = 1
        ');
        $stmt->execute([$targetUserId]);
        $beneficiaries = $stmt->fetchAll();

        if ($stage === 'suspect') {
            $subject = sprintf('DAMS: %s is suspected to have passed away', $user['full_name']);
            $body    = sprintf(
                "Dear beneficiary,\n\nThe Digital Afterlife Management System has flagged %s's account as inactive. The trusted-contact verification process is in progress. You may receive follow-up instructions once the death is confirmed.\n\nThis is an automated notification.",
                $user['full_name']
            );
            $category = 'suspect_death';
        } else {
            $subject = sprintf('DAMS: %s has been confirmed deceased', $user['full_name']);
            $body    = sprintf(
                "Dear beneficiary,\n\nThe trusted-contact quorum and administrator review have confirmed that %s has passed away. Your assigned share of their digital estate is being processed. You will receive a separate secure delivery for any credentials assigned to you.\n\nThis is an automated notification.",
                $user['full_name']
            );
            $category = 'confirmed_death';
        }

        $sent = 0;
        foreach ($beneficiaries as $b) {
            if (Mailer::send($targetUserId, $b['email'], $b['full_name'], $subject, $body, $category)) {
                $sent++;
            }
        }

        Http::json([
            'message' => 'Inheritor notifications dispatched',
            'attempts' => count($beneficiaries),
            'sent' => $sent,
        ]);
    }

    /**
     * POST /api/admin/users/{id}/set-status
     * Body: { status: "Active" | "Flagged" | "Deceased" }
     * Manually moves an account through the lifecycle. Useful for testing.
     */
    public function setUserStatus(int $targetUserId): void {
        $this->requireAdmin();
        $data = Http::readJsonBody();
        $status = (string)($data['status'] ?? '');
        $allowed = ['Active', 'Flagged', 'Pending_Verification', 'Deceased', 'Executed'];
        if (!in_array($status, $allowed, true)) {
            Http::json(['error' => 'Invalid status'], 400);
            return;
        }

        $pdo = Database::getConnection();
        $pdo->prepare('UPDATE users SET account_status = ? WHERE user_id = ?')->execute([$status, $targetUserId]);
        Http::json(['message' => 'Status updated', 'user_id' => $targetUserId, 'status' => $status]);
    }
}
