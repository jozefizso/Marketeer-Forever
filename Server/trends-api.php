<?php
declare(strict_types=1);
header('Content-Type: application/json; charset=utf-8');
header('X-Content-Type-Options: nosniff');
header('Cache-Control: no-store');
$market = $_GET['market'] ?? '';
$item = $_GET['item'] ?? '';
if (!is_string($market) || !is_string($item) || !preg_match('~^forever/(normal|pvp|rp|rppvp)/(alliance|horde)/(us|eu|cn)$~D', $market) || !preg_match('/^[1-9][0-9]{0,9}$/D', $item) || (float)$item > 2147483647) {
    http_response_code(400); exit('{"error":"Invalid market or item"}');
}
$cmd = ['/usr/bin/python3', '/opt/marketeer-history/trends.py', '--db', '/var/lib/marketeer-history/trends.sqlite3', 'summary', $market, $item];
$proc = proc_open($cmd, [0=>['pipe','r'],1=>['pipe','w'],2=>['pipe','w']], $pipes);
if (!is_resource($proc)) { http_response_code(503); exit('{"error":"Trends unavailable"}'); }
fclose($pipes[0]); $out=stream_get_contents($pipes[1],100000); fclose($pipes[1]);
$err=stream_get_contents($pipes[2],100000); fclose($pipes[2]); $code=proc_close($proc);
if ($code !== 0 || !is_string($out) || json_decode($out, true) === null) { http_response_code(503); exit('{"error":"Trends unavailable"}'); }
echo $out;
