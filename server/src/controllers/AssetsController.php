<?php
namespace DAMS\Controllers;

use DAMS\Config\Database;
use DAMS\Middleware\JWTMiddleware;
use DAMS\Utils\Http;
use Throwable;

class AssetsController {
    public function listMine(): void {
        $payload = JWTMiddleware::validateToken();
        $userId = (int)($payload['user_id'] ?? 0);

        $pdo = Database::getConnection();
        $stmt = $pdo->prepare('
            SELECT asset_id, asset_name, asset_type, description, instructions,
                   require_contact_verify, status, include_in_estate, created_at, updated_at
            FROM digital_assets
            WHERE user_id = ?
            ORDER BY updated_at DESC
        ');
        $stmt->execute([$userId]);
        Http::json(['assets' => $stmt->fetchAll()]);
    }

    public function create(): void {
        $payload = JWTMiddleware::validateToken();
        $userId = (int)($payload['user_id'] ?? 0);
        $data = Http::readJsonBody();

        $assetName = trim((string)($data['asset_name'] ?? ''));
        $assetType = (string)($data['asset_type'] ?? '');
        if ($assetName === '' || $assetType === '') {
            Http::json(['error' => 'asset_name and asset_type are required'], 400);
            return;
        }

        $allowedTypes = ['bank_account','crypto_wallet','social_media','email','file_storage','subscription','domain','other'];
        if (!in_array($assetType, $allowedTypes, true)) {
            Http::json(['error' => 'Invalid asset_type'], 400);
            return;
        }

        $description = $data['description'] ?? null;
        $instructions = $data['instructions'] ?? null;
        $requireContactVerify = !empty($data['require_contact_verify']) ? 1 : 0;
        $includeInEstate = array_key_exists('include_in_estate', $data) ? (!empty($data['include_in_estate']) ? 1 : 0) : 1;

        $vaultEntries = is_array($data['vault_entries'] ?? null) ? $data['vault_entries'] : [];
        $beneficiaries = is_array($data['beneficiaries'] ?? null) ? $data['beneficiaries'] : [];

        $pdo = Database::getConnection();
        try {
            $pdo->beginTransaction();

            $stmt = $pdo->prepare('
                INSERT INTO digital_assets
                    (user_id, asset_name, asset_type, description, instructions, require_contact_verify, include_in_estate)
                VALUES (?, ?, ?, ?, ?, ?, ?)
            ');
            $stmt->execute([$userId, $assetName, $assetType, $description, $instructions, $requireContactVerify, $includeInEstate]);
            $assetId = (int)$pdo->lastInsertId();

            if (!empty($vaultEntries)) {
                $vaultStmt = $pdo->prepare('
                    INSERT INTO vault_entries (asset_id, field_name, encrypted_value, iv)
                    VALUES (?, ?, ?, ?)
                ');
                foreach ($vaultEntries as $entry) {
                    $fieldName = trim((string)($entry['field_name'] ?? ''));
                    $encrypted = trim((string)($entry['encrypted_value'] ?? ''));
                    $iv = trim((string)($entry['iv'] ?? ''));
                    if ($fieldName === '' || $encrypted === '' || $iv === '') {
                        continue;
                    }
                    $vaultStmt->execute([$assetId, $fieldName, $encrypted, $iv]);
                }
            }

            if (!empty($beneficiaries)) {
                $shareTotal = 0.0;
                foreach ($beneficiaries as $b) {
                    $name = trim((string)($b['full_name'] ?? ''));
                    $email = trim((string)($b['email'] ?? ''));
                    if ($name === '' || $email === '') {
                        continue;
                    }
                    $shareTotal += (float)($b['share_percentage'] ?? 0);
                }
                if ($shareTotal > 0 && abs($shareTotal - 100.0) > 0.01) {
                    $pdo->rollBack();
                    Http::json(['error' => 'Beneficiary shares must total 100'], 400);
                    return;
                }

                $findBeneficiary = $pdo->prepare('SELECT beneficiary_id FROM beneficiaries WHERE email = ? LIMIT 1');
                $createBeneficiary = $pdo->prepare('
                    INSERT INTO beneficiaries (full_name, email, phone, relationship, verification_status)
                    VALUES (?, ?, ?, ?, ?)
                ');
                $assetBeneficiaryStmt = $pdo->prepare('
                    INSERT INTO asset_beneficiaries
                        (asset_id, beneficiary_id, share_percentage, special_instructions, notification_method)
                    VALUES (?, ?, ?, ?, ?)
                ');

                foreach ($beneficiaries as $b) {
                    $name = trim((string)($b['full_name'] ?? ''));
                    $email = trim((string)($b['email'] ?? ''));
                    if ($name === '' || $email === '') {
                        continue;
                    }

                    $phone = isset($b['phone']) && $b['phone'] !== '' ? (string)$b['phone'] : null;
                    $relationship = isset($b['relationship']) && $b['relationship'] !== '' ? (string)$b['relationship'] : null;
                    $share = (float)($b['share_percentage'] ?? 0);
                    $notificationMethod = (string)($b['notification_method'] ?? 'email');
                    if (!in_array($notificationMethod, ['email', 'sms', 'both'], true)) {
                        $notificationMethod = 'email';
                    }
                    $instructionsForBeneficiary = isset($b['special_instructions']) && $b['special_instructions'] !== '' ? (string)$b['special_instructions'] : null;

                    $findBeneficiary->execute([$email]);
                    $existing = $findBeneficiary->fetch();
                    if ($existing) {
                        $beneficiaryId = (int)$existing['beneficiary_id'];
                    } else {
                        $createBeneficiary->execute([$name, $email, $phone, $relationship, 'pending']);
                        $beneficiaryId = (int)$pdo->lastInsertId();
                    }

                    $assetBeneficiaryStmt->execute([$assetId, $beneficiaryId, $share, $instructionsForBeneficiary, $notificationMethod]);
                }
            }

            $pdo->commit();
            Http::json(['message' => 'Asset created', 'asset_id' => $assetId], 201);
        } catch (Throwable $e) {
            if ($pdo->inTransaction()) {
                $pdo->rollBack();
            }
            Http::json(['error' => 'Failed to create asset with related records'], 500);
        }
    }

    public function update(int $assetId): void {
        $payload = JWTMiddleware::validateToken();
        $userId = (int)($payload['user_id'] ?? 0);
        $data = Http::readJsonBody();

        $pdo = Database::getConnection();
        $stmt = $pdo->prepare('SELECT asset_id FROM digital_assets WHERE asset_id = ? AND user_id = ?');
        $stmt->execute([$assetId, $userId]);
        if (!$stmt->fetch()) {
            Http::json(['error' => 'Asset not found'], 404);
            return;
        }

        $fields = [];
        $values = [];

        $map = [
            'asset_name' => fn($v) => trim((string)$v),
            'description' => fn($v) => $v === null ? null : (string)$v,
            'instructions' => fn($v) => $v === null ? null : (string)$v,
            'require_contact_verify' => fn($v) => !empty($v) ? 1 : 0,
            'include_in_estate' => fn($v) => !empty($v) ? 1 : 0,
            'status' => fn($v) => (string)$v,
        ];

        foreach ($map as $key => $transform) {
            if (array_key_exists($key, $data)) {
                if ($key === 'status') {
                    $allowedStatus = ['active','pending_execution','executed','cancelled'];
                    $val = $transform($data[$key]);
                    if (!in_array($val, $allowedStatus, true)) {
                        Http::json(['error' => 'Invalid status'], 400);
                        return;
                    }
                    $fields[] = "$key = ?";
                    $values[] = $val;
                    continue;
                }
                $val = $transform($data[$key]);
                if ($key === 'asset_name' && $val === '') {
                    Http::json(['error' => 'asset_name cannot be empty'], 400);
                    return;
                }
                $fields[] = "$key = ?";
                $values[] = $val;
            }
        }

        if (count($fields) === 0) {
            Http::json(['message' => 'No changes']);
            return;
        }

        $values[] = $assetId;
        $values[] = $userId;
        $sql = 'UPDATE digital_assets SET ' . implode(', ', $fields) . ' WHERE asset_id = ? AND user_id = ?';
        $pdo->prepare($sql)->execute($values);

        Http::json(['message' => 'Asset updated']);
    }

    public function details(int $assetId): void {
        $payload = JWTMiddleware::validateToken();
        $userId = (int)($payload['user_id'] ?? 0);

        $pdo = Database::getConnection();
        $assetStmt = $pdo->prepare('
            SELECT asset_id, asset_name, asset_type, description, instructions,
                   require_contact_verify, status, include_in_estate, created_at, updated_at
            FROM digital_assets
            WHERE asset_id = ? AND user_id = ?
            LIMIT 1
        ');
        $assetStmt->execute([$assetId, $userId]);
        $asset = $assetStmt->fetch();
        if (!$asset) {
            Http::json(['error' => 'Asset not found'], 404);
            return;
        }

        $vaultStmt = $pdo->prepare('
            SELECT vault_id, field_name, encrypted_value, iv, encryption_algo, created_at
            FROM vault_entries
            WHERE asset_id = ?
            ORDER BY vault_id ASC
        ');
        $vaultStmt->execute([$assetId]);
        $vaultEntries = $vaultStmt->fetchAll();

        $beneficiaryStmt = $pdo->prepare('
            SELECT
                ab.id AS asset_beneficiary_id,
                ab.share_percentage,
                ab.special_instructions,
                ab.notification_method,
                b.beneficiary_id,
                b.full_name,
                b.email,
                b.phone,
                b.relationship,
                b.verification_status
            FROM asset_beneficiaries ab
            JOIN beneficiaries b ON b.beneficiary_id = ab.beneficiary_id
            WHERE ab.asset_id = ?
            ORDER BY ab.id ASC
        ');
        $beneficiaryStmt->execute([$assetId]);
        $beneficiaries = $beneficiaryStmt->fetchAll();

        Http::json([
            'asset' => $asset,
            'vault_entries' => $vaultEntries,
            'beneficiaries' => $beneficiaries,
        ]);
    }

    public function delete(int $assetId): void {
        $payload = JWTMiddleware::validateToken();
        $userId = (int)($payload['user_id'] ?? 0);

        $pdo = Database::getConnection();
        $stmt = $pdo->prepare('DELETE FROM digital_assets WHERE asset_id = ? AND user_id = ?');
        $stmt->execute([$assetId, $userId]);

        if ($stmt->rowCount() === 0) {
            Http::json(['error' => 'Asset not found'], 404);
            return;
        }
        Http::json(['message' => 'Asset deleted']);
    }
}

