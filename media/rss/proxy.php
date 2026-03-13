<?php
header('Access-Control-Allow-Origin: *');
header('Content-Type: application/xml; charset=utf-8');

$url = $_GET['url'] ?? '';
if (!$url || !filter_var($url, FILTER_VALIDATE_URL)) {
    http_response_code(400);
    die('Invalid or missing URL');
}

$ch = curl_init($url);
curl_setopt_array($ch, [
    CURLOPT_RETURNTRANSFER => true,
    CURLOPT_FOLLOWLOCATION => true,
    CURLOPT_TIMEOUT => 15,
    CURLOPT_USERAGENT => 'Psi-RSS-Reader/1.0',
    CURLOPT_SSL_VERIFYPEER => false, // only if target has bad cert
]);
$content = curl_exec($ch);
$httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
curl_close($ch);

if ($httpCode >= 400) {
    http_response_code($httpCode);
    die("Upstream error: $httpCode");
}

echo $content;
?>
