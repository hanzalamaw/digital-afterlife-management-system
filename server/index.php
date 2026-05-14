<?php
require_once __DIR__ . '/vendor/autoload.php';

use Dotenv\Dotenv;
use DAMS\Controllers\CronController;

$dotenv = Dotenv::createImmutable(__DIR__);
$dotenv->load();

header('Content-Type: application/json');
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

$uri = preg_replace('#^/server/index\.php#', '', $uri);
$uri = preg_replace('#^/index\.php#', '', $uri);
$uri = preg_replace('#^/server#', '', $uri);
$uri = rtrim($uri, '/');
if ($uri === '') {
    $uri = '/';
}

// Buffer the API response so we can flush it to the client BEFORE running
// the auto cron sweep. The client never waits on the sweep.
ob_start();
require_once __DIR__ . '/src/routes/api.php';
$response = ob_get_clean();

// Send the response and close the connection so the request appears instant
// to the browser, then keep working in the background.
ignore_user_abort(true);
header('Content-Length: ' . strlen($response));
header('Connection: close');
echo $response;
if (function_exists('fastcgi_finish_request')) {
    fastcgi_finish_request();
} else {
    @ob_end_flush();
    @flush();
}

// Auto cron — fires only if AUTO_SWEEP_INTERVAL_SECONDS has elapsed since
// the last sweep. Skip on the explicit cron endpoint to avoid double-runs.
if ($uri !== '/api/cron/inactivity-sweep') {
    @set_time_limit(60);
    CronController::runAutoIfDue();
}
