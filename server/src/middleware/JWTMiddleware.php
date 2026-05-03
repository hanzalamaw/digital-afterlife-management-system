<?php
namespace DAMS\Middleware;

use Firebase\JWT\JWT;
use Firebase\JWT\Key;
use Exception;

class JWTMiddleware {
    public static function generateToken(array $payload): string {
        $payload['iat'] = time();
        $payload['exp'] = time() + (int)$_ENV['JWT_EXPIRY'];
        $payload['iss'] = 'DAMS';

        return JWT::encode($payload, $_ENV['JWT_SECRET'], 'HS256');
    }

    public static function validateToken(): array {
        $headers = getallheaders();
        $authHeader = $headers['Authorization'] ?? $headers['authorization'] ?? '';

        if (!$authHeader || !str_starts_with($authHeader, 'Bearer ')) {
            http_response_code(401);
            die(json_encode(['error' => 'DAMS: No token provided']));
        }

        $token = substr($authHeader, 7);

        try {
            $decoded = JWT::decode($token, new Key($_ENV['JWT_SECRET'], 'HS256'));
            return (array) $decoded;
        } catch (Exception $e) {
            http_response_code(401);
            die(json_encode(['error' => 'DAMS: Invalid or expired token']));
        }
    }
}