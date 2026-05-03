<?php
require_once __DIR__ . '/vendor/autoload.php';

use Dotenv\Dotenv;

$dotenv = Dotenv::createImmutable(__DIR__);
$dotenv->load();

header('Content-Type: application/json');
// Support local frontend dev origins (Vite and similar).
$origin = $_SERVER['HTTP_ORIGIN'] ?? '';
$isLocalOrigin = preg_match('#^https?://(localhost|127\.0\.0\.1)(:\d+)?$#', $origin) === 1;
header('Access-Control-Allow-Origin: ' . ($isLocalOrigin ? $origin : 'http://localhost:5173'));
header('Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization, X-Client');
header('Vary: Origin');
header('X-Powered-By: DAMS/1.0');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(204);
    exit;
}

$uri = parse_url($_SERVER['REQUEST_URI'], PHP_URL_PATH) ?? '/';

// Normalize URI for different local server modes:
// - php -S localhost:8000 server/index.php            => /api/...
// - php -S localhost:8000 (root) + /server/index.php  => /server/index.php/api/...
// - Apache/XAMPP subfolder                            => /server/api/...
$uri = preg_replace('#^/server/index\.php#', '', $uri);
$uri = preg_replace('#^/index\.php#', '', $uri);
$uri = preg_replace('#^/server#', '', $uri);
$uri = rtrim($uri, '/');
if ($uri === '') {
    $uri = '/';
}

require_once __DIR__ . '/src/routes/api.php';