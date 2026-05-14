<?php
namespace DAMS\Controllers;

use DAMS\Config\Database;
use DAMS\Middleware\JWTMiddleware;
use DAMS\Utils\Http;
use Throwable;

class AuthController {
    private static ?array $usersColumns = null;

    private function getUsersColumns(): array {
        if (self::$usersColumns !== null) {
            return self::$usersColumns;
        }

        $pdo = Database::getConnection();
        $rows = $pdo->query('SHOW COLUMNS FROM users')->fetchAll();
        self::$usersColumns = array_map(
            static fn($row) => (string)($row['Field'] ?? ''),
            $rows ?: []
        );
        return self::$usersColumns;
    }

    private function hasUsersColumn(string $name): bool {
        return in_array($name, $this->getUsersColumns(), true);
    }

    public function register(): void {
        $data = json_decode(file_get_contents('php://input'), true);
        if (!is_array($data)) {
            Http::json(['error' => 'Invalid request payload'], 400);
            return;
        }

        $required = ['full_name', 'email', 'password', 'date_of_birth'];
        foreach ($required as $field) {
            if (empty($data[$field])) {
                Http::json(['error' => "Missing required field: $field"], 400);
                return;
            }
        }

        if (strlen($data['password']) < 8) {
            Http::json(['error' => 'Password must be at least 8 characters'], 400);
            return;
        }

        try {
            $pdo = Database::getConnection();

            $stmt = $pdo->prepare('SELECT user_id FROM users WHERE email = ?');
            $stmt->execute([$data['email']]);
            if ($stmt->fetch()) {
                Http::json(['error' => 'Email already registered'], 409);
                return;
            }

            $hashed = password_hash($data['password'], PASSWORD_BCRYPT);

            $columns = ['full_name', 'email', 'password_hash', 'date_of_birth'];
            $values = [
                $data['full_name'],
                $data['email'],
                $hashed,
                $data['date_of_birth'],
            ];

            if ($this->hasUsersColumn('phone')) {
                $columns[] = 'phone';
                $values[] = isset($data['phone_number']) ? (string)$data['phone_number'] : null;
            }
            if ($this->hasUsersColumn('country')) {
                $columns[] = 'country';
                $values[] = isset($data['country']) ? (string)$data['country'] : null;
            }
            if ($this->hasUsersColumn('recovery_email')) {
                $columns[] = 'recovery_email';
                $values[] = isset($data['recovery_email']) ? (string)$data['recovery_email'] : null;
            }
            if ($this->hasUsersColumn('account_status')) {
                $columns[] = 'account_status';
                $values[] = 'Active';
            }

            $placeholders = implode(', ', array_fill(0, count($columns), '?'));
            $sql = sprintf(
                'INSERT INTO users (%s) VALUES (%s)',
                implode(', ', $columns),
                $placeholders
            );
            $stmt = $pdo->prepare($sql);
            $stmt->execute($values);

            $userId = (int) $pdo->lastInsertId();

            $pdo->prepare('
                INSERT INTO status_transitions (user_id, from_status, to_status, triggered_by, notes, transitioned_at)
                VALUES (?, ?, ?, ?, ?, NOW())
            ')->execute([
                $userId,
                'Active',
                'Active',
                'system',
                'Account created via DAMS registration',
            ]);

            $token = JWTMiddleware::generateToken([
                'user_id' => $userId,
                'email'   => $data['email'],
                'full_name' => $data['full_name'],
                'is_admin'  => 0,
            ]);

            Http::json([
                'message' => 'Account created successfully',
                'token'   => $token,
                'user'    => [
                    'id'        => $userId,
                    'email'     => $data['email'],
                    'full_name' => $data['full_name'],
                    'is_admin'  => 0,
                ],
            ], 201);
        } catch (Throwable $e) {
            Http::json(['error' => 'Registration failed. Please verify your database schema.'], 500);
        }
    }

    public function login(): void {
        $data = json_decode(file_get_contents('php://input'), true);
        if (!is_array($data)) {
            Http::json(['error' => 'Invalid request payload'], 400);
            return;
        }

        if (empty($data['email']) || empty($data['password'])) {
            Http::json(['error' => 'Email and password are required'], 400);
            return;
        }

        try {
            $pdo  = Database::getConnection();
            $select = ['user_id', 'full_name', 'email', 'password_hash', 'account_status'];
            if ($this->hasUsersColumn('is_admin')) {
                $select[] = 'is_admin';
            }

            $stmt = $pdo->prepare(sprintf(
                'SELECT %s FROM users WHERE email = ?',
                implode(', ', $select)
            ));
            $stmt->execute([$data['email']]);
            $user = $stmt->fetch();

            if (!$user || !password_verify($data['password'], $user['password_hash'])) {
                Http::json(['error' => 'Invalid email or password'], 401);
                return;
            }

            if (in_array($user['account_status'], ['Deceased', 'Executed'], true)) {
                Http::json(['error' => 'Account status is: ' . $user['account_status']], 403);
                return;
            }

            $pdo->prepare('
                INSERT INTO checkin_log (user_id, checkin_type, ip_address, client_type)
                VALUES (?, ?, ?, ?)
            ')->execute([
                $user['user_id'],
                'login',
                $_SERVER['REMOTE_ADDR'] ?? null,
                'web',
            ]);

            // Cancel any open death verifications — the user is clearly alive.
            // (The DB trigger trg_checkin_update_user also does this, but we
            // run it from PHP too so older installations without migration 004
            // still behave correctly.)
            $pdo->prepare("
                UPDATE death_verifications
                SET status = 'cancelled', cancelled_at = NOW()
                WHERE user_id = ? AND status IN ('initiated','awaiting_quorum')
            ")->execute([$user['user_id']]);

            $isAdmin = (int)($user['is_admin'] ?? 0);
            $token = JWTMiddleware::generateToken([
                'user_id' => $user['user_id'],
                'email'   => $user['email'],
                'full_name' => $user['full_name'],
                'is_admin'  => $isAdmin,
            ]);

            Http::json([
                'message' => 'Welcome back',
                'token'   => $token,
                'user'    => [
                    'id'        => (int) $user['user_id'],
                    'email'     => $user['email'],
                    'full_name' => $user['full_name'],
                    'is_admin'  => $isAdmin,
                ],
            ]);
        } catch (Throwable $e) {
            Http::json(['error' => 'Login failed. Please verify your database schema.'], 500);
        }
    }
}