<?php
namespace DAMS\Utils;

final class Http {
    public static function readJsonBody(): array {
        $raw = file_get_contents('php://input');
        $data = json_decode($raw ?: '[]', true);
        return is_array($data) ? $data : [];
    }

    public static function json(array $payload, int $statusCode = 200): void {
        http_response_code($statusCode);
        echo json_encode($payload);
    }
}

