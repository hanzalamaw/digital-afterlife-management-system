<?php
namespace DAMS\Utils;

use DAMS\Config\Database;

/**
 * Lightweight email dispatcher.
 *
 * Delivery strategy (in order):
 *   1. If MAIL_DRY_RUN=1 in .env → skip network, only log.
 *   2. If SMTP_HOST is configured → deliver via the built-in Smtp client.
 *   3. Otherwise fall back to PHP's native mail() (rarely works on XAMPP).
 *
 * Every attempt is recorded in the notification_log table AND appended to
 * server/logs/mail.log, so you can audit what the system "would have" sent
 * even before SMTP is configured.
 */
final class Mailer {
    private static function logsDir(): string {
        $dir = __DIR__ . '/../../logs';
        if (!is_dir($dir)) {
            @mkdir($dir, 0775, true);
        }
        return $dir;
    }

    private static function fromAddress(): string {
        return (string)($_ENV['MAIL_FROM'] ?? 'no-reply@dams.local');
    }

    private static function fromName(): string {
        return (string)($_ENV['MAIL_FROM_NAME'] ?? 'DAMS');
    }

    private static function logToFile(string $to, string $subject, string $body, string $status): void {
        $line = sprintf(
            "[%s] %s | TO: %s | SUBJECT: %s\n%s\n----\n",
            date('Y-m-d H:i:s'),
            strtoupper($status),
            $to,
            $subject,
            $body
        );
        @file_put_contents(self::logsDir() . '/mail.log', $line, FILE_APPEND);
    }

    /**
     * Queue + send one email and persist to notification_log.
     */
    public static function send(
        ?int $userId,
        string $recipient,
        string $recipientName,
        string $subject,
        string $body,
        string $category = 'other'
    ): bool {
        $pdo = Database::getConnection();

        $logStmt = $pdo->prepare('
            INSERT INTO notification_log
                (user_id, recipient_email, recipient_name, subject, body, category, status)
            VALUES (?, ?, ?, ?, ?, ?, ?)
        ');
        $logStmt->execute([$userId, $recipient, $recipientName, $subject, $body, $category, 'queued']);
        $notificationId = (int)$pdo->lastInsertId();

        $html  = "<html><body style=\"font-family:Arial,Helvetica,sans-serif;color:#1f2937;line-height:1.5\">";
        $html .= "<div style=\"max-width:560px;margin:0 auto;padding:20px;border:1px solid #e5e7eb;border-radius:14px;background:#ffffff\">";
        $html .= "<div style=\"font-size:11px;letter-spacing:1px;color:#0A8C6D;text-transform:uppercase;margin-bottom:8px\">Digital Afterlife Management System</div>";
        $html .= "<h2 style=\"margin:0 0 12px;font-size:18px;color:#0A8C6D\">" . htmlspecialchars($subject) . "</h2>";
        $html .= "<div style=\"font-size:13px;white-space:pre-wrap\">" . nl2br(htmlspecialchars($body)) . "</div>";
        $html .= "<hr style=\"border:none;border-top:1px solid #e5e7eb;margin:18px 0\"/>";
        $html .= "<div style=\"font-size:11px;color:#6b7280\">This is an automated message from DAMS. Please do not reply.</div>";
        $html .= "</div></body></html>";

        $dryRun = (string)($_ENV['MAIL_DRY_RUN'] ?? '0') === '1';
        $smtpHost = (string)($_ENV['SMTP_HOST'] ?? '');

        $delivered = false;
        $error = null;

        if ($dryRun) {
            $error = 'MAIL_DRY_RUN=1';
        } elseif ($smtpHost !== '') {
            try {
                $smtp = new Smtp(
                    $smtpHost,
                    (int)($_ENV['SMTP_PORT'] ?? 587),
                    (string)($_ENV['SMTP_SECURE'] ?? 'tls')
                );
                $smtp->send(
                    self::fromAddress(),
                    self::fromName(),
                    $recipient,
                    $recipientName,
                    $subject,
                    $html,
                    (string)($_ENV['SMTP_USER'] ?? '') ?: null,
                    (string)($_ENV['SMTP_PASS'] ?? '') ?: null
                );
                $delivered = true;
            } catch (\Throwable $e) {
                $error = 'SMTP error: ' . $e->getMessage();
            }
        } elseif (function_exists('mail')) {
            $headers  = "MIME-Version: 1.0\r\n";
            $headers .= "Content-type: text/html; charset=UTF-8\r\n";
            $headers .= "From: " . self::fromName() . ' <' . self::fromAddress() . ">\r\n";
            $headers .= "X-Mailer: DAMS/1.0\r\n";
            try {
                $delivered = @mail($recipient, $subject, $html, $headers);
                if (!$delivered) {
                    $error = 'PHP mail() returned false (XAMPP often has no MTA)';
                }
            } catch (\Throwable $e) {
                $error = $e->getMessage();
            }
        } else {
            $error = 'mail() function unavailable and SMTP_HOST not configured';
        }

        if ($delivered) {
            self::logToFile($recipient, $subject, $body, 'sent');
            $pdo->prepare('UPDATE notification_log SET status = ?, sent_at = NOW() WHERE notification_id = ?')
                ->execute(['sent', $notificationId]);
            return true;
        }

        self::logToFile($recipient, $subject, $body, 'failed-fallback');
        $pdo->prepare('UPDATE notification_log SET status = ?, error_message = ?, sent_at = NOW() WHERE notification_id = ?')
            ->execute(['failed', $error, $notificationId]);
        return false;
    }
}
