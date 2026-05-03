<?php
/**
 * ============================================================
 *  DAMS — Digital Afterlife Management System
 *  OS Lab Deliverable: Raw TCP Socket Server
 *  Run: php src/socket/SocketServer.php
 * ============================================================
 */

require_once __DIR__ . '/../../vendor/autoload.php';

use Dotenv\Dotenv;
use Firebase\JWT\JWT;
use Firebase\JWT\Key;
use DAMS\Config\Database;

$dotenv = Dotenv::createImmutable(__DIR__ . '/../../');
$dotenv->load();

$host = '0.0.0.0';
$port = (int)$_ENV['SOCKET_PORT'];

$server = socket_create(AF_INET, SOCK_STREAM, SOL_TCP);
socket_set_option($server, SOL_SOCKET, SO_REUSEADDR, 1);
socket_bind($server, $host, $port);
socket_listen($server, 5);

echo "[DAMS Socket Server] Listening on $host:$port\n";

while (true) {
    $client = socket_accept($server);
    if ($client === false) continue;

    $raw = socket_read($client, 4096, PHP_NORMAL_READ);
    $raw = trim($raw);

    echo "[DAMS Socket] Received: $raw\n";

    $response = handleMessage($raw);
    socket_write($client, json_encode($response) . "\n");
    socket_close($client);
}

function handleMessage(string $raw): array {
    try {
        $msg = json_decode($raw, true);
        if (!$msg || !isset($msg['action'])) {
            return ['status' => 'error', 'system' => 'DAMS', 'message' => 'Invalid message format'];
        }

        return match($msg['action']) {
            'ping'          => ['status' => 'ok', 'system' => 'DAMS', 'message' => 'pong', 'timestamp' => time()],
            'verify_token'  => verifyToken($msg['token'] ?? ''),
            'checkin'       => processCheckin($msg),
            'death_trigger' => processTrigger($msg),
            default         => ['status' => 'error', 'system' => 'DAMS', 'message' => 'Unknown action: ' . $msg['action']]
        };
    } catch (Exception $e) {
        return ['status' => 'error', 'system' => 'DAMS', 'message' => $e->getMessage()];
    }
}

function verifyToken(string $token): array {
    try {
        $decoded = JWT::decode($token, new Key($_ENV['JWT_SECRET'], 'HS256'));
        return ['status' => 'ok', 'system' => 'DAMS', 'user_id' => $decoded->user_id, 'email' => $decoded->email];
    } catch (Exception $e) {
        return ['status' => 'error', 'system' => 'DAMS', 'message' => 'Invalid token'];
    }
}

function processCheckin(array $msg): array {
    $pdo = Database::getConnection();
    $pdo->prepare('
        INSERT INTO checkin_log (user_id, checkin_method, checkin_time, ip_address)
        VALUES (?, "socket", NOW(), "socket-client")
    ')->execute([$msg['user_id'] ?? null]);

    return ['status' => 'ok', 'system' => 'DAMS', 'message' => 'Check-in recorded via socket', 'user_id' => $msg['user_id'] ?? null];
}

function processTrigger(array $msg): array {
    return ['status' => 'ok', 'system' => 'DAMS', 'message' => 'Death trigger evaluated', 'user_id' => $msg['user_id'] ?? null];
}