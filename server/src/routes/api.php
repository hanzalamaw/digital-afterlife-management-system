<?php
use DAMS\Controllers\AuthController;
use DAMS\Controllers\RulesController;
use DAMS\Controllers\AssetsController;
use DAMS\Controllers\ContactsController;
use DAMS\Controllers\AdminController;
use DAMS\Controllers\CronController;
use DAMS\Controllers\DashboardController;
use DAMS\Middleware\JWTMiddleware;

$auth = new AuthController();
$rules = new RulesController();
$assets = new AssetsController();
$contacts = new ContactsController();
$admin = new AdminController();
$cron = new CronController();
$dashboard = new DashboardController();

match(true) {
    $uri === '/api/auth/register' && $_SERVER['REQUEST_METHOD'] === 'POST'
        => $auth->register(),

    $uri === '/api/auth/login' && $_SERVER['REQUEST_METHOD'] === 'POST'
        => $auth->login(),

    $uri === '/api/user/me' && $_SERVER['REQUEST_METHOD'] === 'GET'
        => (function() {
            $payload = JWTMiddleware::validateToken();
            echo json_encode(['user' => $payload, 'system' => 'DAMS']);
        })(),

    // Legacy single-active-rule endpoints (kept for compatibility)
    $uri === '/api/rules' && $_SERVER['REQUEST_METHOD'] === 'GET'
        => $rules->getMyRules(),
    $uri === '/api/rules/active' && $_SERVER['REQUEST_METHOD'] === 'PUT'
        => $rules->upsertMyActiveRule(),

    // New death-rules endpoints used by the "Manage Death Rules" page
    $uri === '/api/death-rules' && $_SERVER['REQUEST_METHOD'] === 'GET'
        => $rules->getDeathRules(),
    $uri === '/api/death-rules/inactivity' && $_SERVER['REQUEST_METHOD'] === 'PUT'
        => $rules->saveInactivity(),
    $uri === '/api/death-rules/quorum' && $_SERVER['REQUEST_METHOD'] === 'PUT'
        => $rules->saveQuorum(),

    // Dashboard (aggregated)
    $uri === '/api/dashboard/summary' && $_SERVER['REQUEST_METHOD'] === 'GET'
        => $dashboard->summary(),

    // Assets
    $uri === '/api/assets' && $_SERVER['REQUEST_METHOD'] === 'GET'
        => $assets->listMine(),
    $uri === '/api/assets' && $_SERVER['REQUEST_METHOD'] === 'POST'
        => $assets->create(),
    preg_match('#^/api/assets/(\\d+)/details$#', $uri, $m) && $_SERVER['REQUEST_METHOD'] === 'GET'
        => $assets->details((int)$m[1]),
    preg_match('#^/api/assets/(\\d+)$#', $uri, $m) && $_SERVER['REQUEST_METHOD'] === 'PUT'
        => $assets->update((int)$m[1]),
    preg_match('#^/api/assets/(\\d+)$#', $uri, $m) && $_SERVER['REQUEST_METHOD'] === 'DELETE'
        => $assets->delete((int)$m[1]),

    // Trusted contacts
    $uri === '/api/contacts' && $_SERVER['REQUEST_METHOD'] === 'GET'
        => $contacts->listMine(),
    $uri === '/api/contacts' && $_SERVER['REQUEST_METHOD'] === 'POST'
        => $contacts->create(),
    preg_match('#^/api/contacts/(\\d+)$#', $uri, $m) && $_SERVER['REQUEST_METHOD'] === 'PUT'
        => $contacts->update((int)$m[1]),
    preg_match('#^/api/contacts/(\\d+)$#', $uri, $m) && $_SERVER['REQUEST_METHOD'] === 'DELETE'
        => $contacts->delete((int)$m[1]),

    // Admin
    $uri === '/api/admin/users' && $_SERVER['REQUEST_METHOD'] === 'GET'
        => $admin->usersSummary(),
    $uri === '/api/admin/pending-executions' && $_SERVER['REQUEST_METHOD'] === 'GET'
        => $admin->pendingExecutions(),
    $uri === '/api/admin/death-verifications' && $_SERVER['REQUEST_METHOD'] === 'GET'
        => $admin->deathVerifications(),
    preg_match('#^/api/admin/users/(\\d+)/notify-inheritors$#', $uri, $m) && $_SERVER['REQUEST_METHOD'] === 'POST'
        => $admin->notifyInheritors((int)$m[1]),
    preg_match('#^/api/admin/users/(\\d+)/set-status$#', $uri, $m) && $_SERVER['REQUEST_METHOD'] === 'POST'
        => $admin->setUserStatus((int)$m[1]),

    // Scheduled jobs (token-protected, no JWT)
    $uri === '/api/cron/inactivity-sweep' && $_SERVER['REQUEST_METHOD'] === 'POST'
        => $cron->runInactivitySweep(),

    default => (function() {
        http_response_code(404);
        echo json_encode(['error' => 'DAMS: Route not found']);
    })()
};
