<?php
namespace DAMS\Utils;

/**
 * AES-256-CBC helpers used by the vault.
 * The encryption key comes from the VAULT_ENCRYPTION_KEY env var.
 * If it is short or missing, we derive a stable 32-byte key from it.
 */
final class Crypto {
    private static function key(): string {
        $raw = $_ENV['VAULT_ENCRYPTION_KEY'] ?? '';
        if ($raw === '' || $raw === null) {
            $raw = 'dams-default-key-please-change-in-env';
        }
        return substr(hash('sha256', $raw, true), 0, 32);
    }

    /**
     * Encrypts a plaintext string. Returns an array with base64-encoded
     * ciphertext + base64-encoded IV. Both are safe to store in TEXT/VARCHAR.
     *
     * @return array{ciphertext:string,iv:string}
     */
    public static function encrypt(string $plaintext): array {
        $iv = openssl_random_pseudo_bytes(16);
        $cipher = openssl_encrypt(
            $plaintext,
            'AES-256-CBC',
            self::key(),
            OPENSSL_RAW_DATA,
            $iv
        );
        if ($cipher === false) {
            throw new \RuntimeException('Vault encryption failed.');
        }
        return [
            'ciphertext' => base64_encode($cipher),
            'iv'         => base64_encode($iv),
        ];
    }

    /**
     * Decrypts a previously encrypted base64 ciphertext using the stored
     * base64 IV. Returns the plaintext, or null if decryption fails.
     */
    public static function decrypt(string $base64Cipher, string $base64Iv): ?string {
        $cipher = base64_decode($base64Cipher, true);
        $iv     = base64_decode($base64Iv, true);
        if ($cipher === false || $iv === false) return null;

        $plain = openssl_decrypt(
            $cipher,
            'AES-256-CBC',
            self::key(),
            OPENSSL_RAW_DATA,
            $iv
        );
        return $plain === false ? null : $plain;
    }
}
