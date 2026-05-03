<?php
namespace DAMS\Controllers;

use DAMS\Config\Database;
use DAMS\Middleware\JWTMiddleware;
use DAMS\Utils\Http;

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
}

