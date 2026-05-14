<?php
namespace DAMS\Utils;

/**
 * Minimal SMTP client.
 *
 * Supports:
 *   - Plain TCP (port 25 / no auth)
 *   - STARTTLS upgrade (port 587, SMTP_SECURE=tls)
 *   - Implicit TLS (port 465, SMTP_SECURE=ssl)
 *   - AUTH LOGIN (base64 user/pass) — works with Gmail, Mailtrap, etc.
 *
 * Intentionally dependency-free so XAMPP users don't need composer changes.
 * For production you can swap this for PHPMailer/Symfony Mailer; the public
 * signature of Mailer::send() does not need to change.
 */
final class Smtp {
    private $socket;
    private string $host;
    private int $port;
    private string $secure;
    private int $timeout;

    public function __construct(string $host, int $port, string $secure = 'tls', int $timeout = 15) {
        $this->host    = $host;
        $this->port    = $port;
        $this->secure  = strtolower($secure);
        $this->timeout = $timeout;
    }

    private function connect(): void {
        $transport = ($this->secure === 'ssl') ? 'ssl' : 'tcp';
        $errno = 0; $errstr = '';
        $context = stream_context_create([
            'ssl' => [
                'verify_peer'       => false,
                'verify_peer_name'  => false,
                'allow_self_signed' => true,
            ],
        ]);
        $this->socket = @stream_socket_client(
            sprintf('%s://%s:%d', $transport, $this->host, $this->port),
            $errno, $errstr,
            $this->timeout,
            STREAM_CLIENT_CONNECT,
            $context
        );
        if (!$this->socket) {
            throw new \RuntimeException("SMTP connect failed: $errstr ($errno)");
        }
        stream_set_timeout($this->socket, $this->timeout);
        $this->expect(220);
    }

    private function write(string $line): void {
        fwrite($this->socket, $line . "\r\n");
    }

    private function read(): string {
        $data = '';
        while (!feof($this->socket)) {
            $chunk = fgets($this->socket, 1024);
            if ($chunk === false) break;
            $data .= $chunk;
            if (isset($chunk[3]) && $chunk[3] === ' ') break;
        }
        return $data;
    }

    private function expect(int $code): string {
        $resp = $this->read();
        if ((int)substr($resp, 0, 3) !== $code) {
            throw new \RuntimeException("SMTP expected $code, got: " . trim($resp));
        }
        return $resp;
    }

    public function send(
        string $fromEmail,
        string $fromName,
        string $toEmail,
        string $toName,
        string $subject,
        string $htmlBody,
        ?string $user = null,
        ?string $pass = null
    ): void {
        $this->connect();

        $ehloHost = $_SERVER['HTTP_HOST'] ?? 'localhost';
        $this->write("EHLO {$ehloHost}");
        $this->expect(250);

        if ($this->secure === 'tls') {
            $this->write('STARTTLS');
            $this->expect(220);
            if (!stream_socket_enable_crypto(
                $this->socket,
                true,
                STREAM_CRYPTO_METHOD_TLSv1_2_CLIENT
                | STREAM_CRYPTO_METHOD_TLSv1_1_CLIENT
                | STREAM_CRYPTO_METHOD_TLS_CLIENT
            )) {
                throw new \RuntimeException('STARTTLS upgrade failed');
            }
            $this->write("EHLO {$ehloHost}");
            $this->expect(250);
        }

        if ($user !== null && $user !== '' && $pass !== null) {
            $this->write('AUTH LOGIN');
            $this->expect(334);
            $this->write(base64_encode($user));
            $this->expect(334);
            $this->write(base64_encode($pass));
            $this->expect(235);
        }

        $this->write("MAIL FROM:<{$fromEmail}>");
        $this->expect(250);
        $this->write("RCPT TO:<{$toEmail}>");
        $this->expect(250);
        $this->write('DATA');
        $this->expect(354);

        $headers  = "From: " . self::encodeAddress($fromName, $fromEmail) . "\r\n";
        $headers .= "To: "   . self::encodeAddress($toName, $toEmail) . "\r\n";
        $headers .= "Subject: " . self::encodeHeader($subject) . "\r\n";
        $headers .= "MIME-Version: 1.0\r\n";
        $headers .= "Content-Type: text/html; charset=UTF-8\r\n";
        $headers .= "Content-Transfer-Encoding: 8bit\r\n";
        $headers .= "Date: " . date('r') . "\r\n";
        $headers .= "Message-ID: <" . bin2hex(random_bytes(8)) . "@dams>\r\n";
        $headers .= "X-Mailer: DAMS/1.0\r\n";

        // Dot-stuff (RFC 5321): any line starting with "." must be doubled.
        $body = preg_replace('/^\./m', '..', $htmlBody);

        $this->write($headers . "\r\n" . $body . "\r\n.");
        $this->expect(250);

        $this->write('QUIT');
        @fclose($this->socket);
    }

    private static function encodeAddress(string $name, string $email): string {
        if ($name === '') return "<{$email}>";
        return self::encodeHeader($name) . " <{$email}>";
    }

    private static function encodeHeader(string $text): string {
        if (preg_match('/[^\x20-\x7e]/', $text)) {
            return '=?UTF-8?B?' . base64_encode($text) . '?=';
        }
        return $text;
    }
}
