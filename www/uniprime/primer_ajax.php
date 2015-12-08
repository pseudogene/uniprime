<?php
session_start();
require_once('includes/main.inc');

$answer=false;
if (isset($_GET['primer']) && preg_match('/X(\d+)\.(\d+)/', strtoupper(utf8_decode($_GET['primer'])), $matches)) {
  $sql = sql_connect($config['db']);
  $result = sql_query('SELECT prefix, id FROM primer WHERE prefix=' . octdec(intval($matches[1])) . ' AND id=' . octdec(intval($matches[2])) . ';', $sql);
  if ((!strlen($r = sql_last_error($sql))) && (sql_num_rows($result) == 1)) {
    $answer=true;
  }
}

print '<'.'?xml version="1.0" ?'.">\n";
print '<answer>'.(($answer) ? 'true' : 'false' ).'</answer>';
?>