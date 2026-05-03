<?php
use DAMS\Controllers\AuthController;
use DAMS\Controllers\RulesController;
use DAMS\Controllers\AssetsController;
use DAMS\Controllers\ContactsController;
use DAMS\Controllers\AdminController;
use DAMS\Middleware\JWTMiddleware;

$auth = new AuthController();
$rules = new RulesController();
$assets = new AssetsController();
$contacts = new ContactsController();
$admin = new AdminController();

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

    // Rules (no "manual declaration" rule exposed)
    $uri === '/api/rules' && $_SERVER['REQUEST_METHOD'] === 'GET'
        => $rules->getMyRules(),
    $uri === '/api/rules/active' && $_SERVER['REQUEST_METHOD'] === 'PUT'
        => $rules->upsertMyActiveRule(),

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

    // Trusted contacts (contacts can confirm when asked, but cannot start a verification)
    $uri === '/api/contacts' && $_SERVER['REQUEST_METHOD'] === 'GET'
        => $contacts->listMine(),
    $uri === '/api/contacts' && $_SERVER['REQUEST_METHOD'] === 'POST'
        => $contacts->create(),
    preg_match('#^/api/contacts/(\\d+)$#', $uri, $m) && $_SERVER['REQUEST_METHOD'] === 'PUT'
        => $contacts->update((int)$m[1]),
    preg_match('#^/api/contacts/(\\d+)$#', $uri, $m) && $_SERVER['REQUEST_METHOD'] === 'DELETE'
        => $contacts->delete((int)$m[1]),

    // Admin reporting
    $uri === '/api/admin/users' && $_SERVER['REQUEST_METHOD'] === 'GET'
        => $admin->usersSummary(),
    $uri === '/api/admin/pending-executions' && $_SERVER['REQUEST_METHOD'] === 'GET'
        => $admin->pendingExecutions(),
    $uri === '/api/admin/death-verifications' && $_SERVER['REQUEST_METHOD'] === 'GET'
        => $admin->deathVerifications(),

    default => (function() {
        http_response_code(404);
        echo json_encode(['error' => 'DAMS: Route not found']);
    })()
};