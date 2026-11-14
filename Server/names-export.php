<?php
declare(strict_types=1);
header('Content-Type: text/plain; charset=utf-8');header('X-Content-Type-Options: nosniff');header('Cache-Control: no-store');
$cmd=['/usr/bin/python3','/opt/marketeer-history/names_export.py','/var/lib/marketeer-history/trends.sqlite3'];
$p=proc_open($cmd,[0=>['pipe','r'],1=>['pipe','w'],2=>['pipe','w']],$pipes);
if(!is_resource($p)){http_response_code(503);exit('Names unavailable');}
fclose($pipes[0]);$out=stream_get_contents($pipes[1],5000001);fclose($pipes[1]);$err=stream_get_contents($pipes[2],10000);fclose($pipes[2]);$status=proc_close($p);
if($status!==0 || !is_string($out) || strlen($out)>5000000){http_response_code(503);exit('Names unavailable');}echo $out;
