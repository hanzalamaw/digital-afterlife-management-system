<?php
/**
 * One-shot CLI tool to verify the DAMS email pipeline.
 *
 *   php server/tools/test-email.php                  # sends to MAIL_FROM
 *   php server/tools/test-email.php you@example.com  # sends to a specific address
 *
 * Reports whether SMTP delivery succeeded and prints the notification_log
 * row it created so you can see exactly what the system tried to do.
 */
require_once __DIR__ . '/../vendor/autoload.php';

use Dotenv\Dotenv;
use DAMS\Config\Database;
use DAMS\Utils\Mailer;

Dotenv::createImmutable(__DIR__ . '/..')->load();

$recipient = $argv[1] ?? ($_ENV['MAIL_FROM'] ?? '');
if ($recipient === '') {
    fwrite(STDERR, "Usage: php server/tools/test-email.php <recipient-email>\n");
    fwrite(STDERR, "Or set MAIL_FROM in server/.env to use it as the default recipient.\n");
    exit(1);
}

echo "DAMS email smoke test\n";
echo "---------------------\n";
echo "MAIL_DRY_RUN : " . ($_ENV['MAIL_DRY_RUN'] ?? '0') . "\n";
echo "SMTP_HOST    : " . ($_ENV['SMTP_HOST'] ?? '(not set)') . "\n";
echo "SMTP_PORT    : " . ($_ENV['SMTP_PORT'] ?? '(not set)') . "\n";
echo "SMTP_SECURE  : " . ($_ENV['SMTP_SECURE'] ?? '(not set)') . "\n";
echo "SMTP_USER    : " . ($_ENV['SMTP_USER'] ?? '(not set)') . "\n";
echo "MAIL_FROM    : " . ($_ENV['MAIL_FROM'] ?? '(not set)') . "\n";
echo "Recipient    : {$recipient}\n";
echo "---------------------\n";

$subject = 'DAMS email test — ' . date('Y-m-d H:i:s');
$body    = "If you can read this, DAMS SMTP delivery is working.\n\n"
         . "Sent by:   " . ($_ENV['MAIL_FROM'] ?? 'unknown') . "\n"
         . "Time:      " . date('r') . "\n"
         . "Host:      " . gethostname() . "\n";

$ok = Mailer::send(
    null,
    $recipient,
    'DAMS Tester',
    $subject,
    $body,
    'other'
);

echo $ok ? "RESULT       : SENT ✓\n" : "RESULT       : FAILED ✗\n";

$pdo = Database::getConnection();
$row = $pdo->query('SELECT * FROM notification_log ORDER BY notification_id DESC LIMIT 1')->fetch();
echo "---------------------\n";
echo "notification_log row:\n";
foreach ($row as $k => $v) {
    if ($k === 'body') continue;
    echo str_pad((string)$k, 14) . ": " . ($v ?? '') . "\n";
}
echo "---------------------\n";
echo "Also check: server/logs/mail.log\n";

exit($ok ? 0 : 2);
