<?php
namespace DAMS\Controllers;

use DAMS\Config\Database;
use DAMS\Middleware\JWTMiddleware;
use DAMS\Utils\Http;

class ContactsController {
    public function listMine(): void {
        $payload = JWTMiddleware::validateToken();
        $userId = (int)($payload['user_id'] ?? 0);

        $pdo = Database::getConnection();
        $stmt = $pdo->prepare('
            SELECT contact_id, full_name, email, phone, verification_status, priority_order, verified_at, created_at
            FROM trusted_contacts
            WHERE user_id = ?
            ORDER BY priority_order ASC, created_at DESC
        ');
        $stmt->execute([$userId]);
        Http::json(['contacts' => $stmt->fetchAll()]);
    }

    public function create(): void {
        $payload = JWTMiddleware::validateToken();
        $userId = (int)($payload['user_id'] ?? 0);
        $data = Http::readJsonBody();

        $name = trim((string)($data['full_name'] ?? ''));
        $email = trim((string)($data['email'] ?? ''));
        $phone = array_key_exists('phone', $data) ? (string)$data['phone'] : null;
        $priority = isset($data['priority_order']) ? (int)$data['priority_order'] : 1;

        if ($name === '' || $email === '') {
            Http::json(['error' => 'full_name and email are required'], 400);
            return;
        }
        if ($priority < 1) {
            Http::json(['error' => 'priority_order must be >= 1'], 400);
            return;
        }

        $pdo = Database::getConnection();
        $stmt = $pdo->prepare('
            INSERT INTO trusted_contacts (user_id, full_name, email, phone, verification_status, priority_order)
            VALUES (?, ?, ?, ?, ?, ?)
        ');
        $stmt->execute([$userId, $name, $email, $phone, 'pending', $priority]);

        Http::json(['message' => 'Contact added', 'contact_id' => (int)$pdo->lastInsertId()], 201);
    }

    public function update(int $contactId): void {
        $payload = JWTMiddleware::validateToken();
        $userId = (int)($payload['user_id'] ?? 0);
        $data = Http::readJsonBody();

        $pdo = Database::getConnection();
        $stmt = $pdo->prepare('SELECT contact_id FROM trusted_contacts WHERE contact_id = ? AND user_id = ?');
        $stmt->execute([$contactId, $userId]);
        if (!$stmt->fetch()) {
            Http::json(['error' => 'Contact not found'], 404);
            return;
        }

        $fields = [];
        $values = [];

        if (array_key_exists('full_name', $data)) {
            $name = trim((string)$data['full_name']);
            if ($name === '') {
                Http::json(['error' => 'full_name cannot be empty'], 400);
                return;
            }
            $fields[] = 'full_name = ?';
            $values[] = $name;
        }
        if (array_key_exists('email', $data)) {
            $email = trim((string)$data['email']);
            if ($email === '') {
                Http::json(['error' => 'email cannot be empty'], 400);
                return;
            }
            $fields[] = 'email = ?';
            $values[] = $email;
        }
        if (array_key_exists('phone', $data)) {
            $fields[] = 'phone = ?';
            $values[] = $data['phone'] === null ? null : (string)$data['phone'];
        }
        if (array_key_exists('priority_order', $data)) {
            $priority = (int)$data['priority_order'];
            if ($priority < 1) {
                Http::json(['error' => 'priority_order must be >= 1'], 400);
                return;
            }
            $fields[] = 'priority_order = ?';
            $values[] = $priority;
        }

        if (count($fields) === 0) {
            Http::json(['message' => 'No changes']);
            return;
        }

        $values[] = $contactId;
        $values[] = $userId;
        $sql = 'UPDATE trusted_contacts SET ' . implode(', ', $fields) . ' WHERE contact_id = ? AND user_id = ?';
        $pdo->prepare($sql)->execute($values);
        Http::json(['message' => 'Contact updated']);
    }

    public function delete(int $contactId): void {
        $payload = JWTMiddleware::validateToken();
        $userId = (int)($payload['user_id'] ?? 0);

        $pdo = Database::getConnection();
        $stmt = $pdo->prepare('DELETE FROM trusted_contacts WHERE contact_id = ? AND user_id = ?');
        $stmt->execute([$contactId, $userId]);

        if ($stmt->rowCount() === 0) {
            Http::json(['error' => 'Contact not found'], 404);
            return;
        }
        Http::json(['message' => 'Contact removed']);
    }
}

