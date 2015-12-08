<?php
ob_start("ob_gzhandler");
session_start();
require_once('includes/main.inc');

if (!empty($_GET['sequence']) || !empty($_GET['mrna']) || !empty($_GET['primer'])) {
  $sql = sql_connect($config['db']);
  if (!empty($_GET['sequence']) && preg_match('/[SRX](\d+)\.(\d+)/', rawurldecode($_GET['sequence']), $matches)) {
    $result = sql_query('SELECT structure FROM sequence WHERE prefix=' . octdec(intval($matches[1])) . ' AND id=' . octdec(intval($matches[2])) . ';', $sql);
  }elseif (!empty($_GET['mrna']) && preg_match('/R(\d+)\.(\d+)/', rawurldecode($_GET['mrna']), $matches)) {
    $result = sql_query('SELECT location FROM mrna WHERE prefix=' . octdec(intval($matches[1])) . ' AND id=' . octdec(intval($matches[2])) . ';', $sql);
  }elseif (!empty($_GET['primer']) && preg_match('/X(\d+)\.(\d+)/', rawurldecode($_GET['primer']), $matches)) {
    $result = sql_query('SELECT b.structure, a.left_data, a.right_data FROM primer AS a, alignment AS b WHERE a.prefix=' . octdec(intval($matches[1])) . ' AND a.id=' . octdec(intval($matches[2])) . ' AND a.alignment_prefix=b.prefix AND a.alignment_id=b.id;', $sql);
  }
  if ((!strlen($r = sql_last_error($sql))) && (sql_num_rows($result) == 1)) {
    $row = sql_fetch_row($result);
    if (isset($row[0])) {
      header('Content-type: image/png');
      $img = imagecreatetruecolor(300, (isset($row[1])?19:9));
      $trans = imagecolorallocate($img, 255, 255, 255);
      imagefilledrectangle($img, 0, 0, 299, 19, $trans);
      imagecolortransparent($img, $trans);
      $yellow = imagecolorallocate($img, 243, 213, 139);
      $blue = imagecolorallocate($img, 108, 188, 233);
      imagefilledrectangle($img, 0, 0, 299, 9, imagecolorallocate($img, 204, 222, 243));
      if (preg_match_all('/(\d+)\.\.(\d+)/', $row[0], $chars)) {
        $scale = 300 / end($chars[2]);
        for($i = 0; $i < count($chars[1]); $i++) {
          imagefilledrectangle($img, ($chars[1][$i] * $scale), 0, ($chars[2][$i] * $scale) + 1, 9, $blue);
        }
        if (isset($row[1]) && isset($row[2])) {
          list($left) = explode('|', $row[1]);
          list($right) = explode('|', $row[2]);
          if (!empty($right) && !empty($left)) imagefilledrectangle($img, ($left * $scale), 12, ($right * $scale) + 1, 19, $yellow);
        }
        imagepng($img);
        imagedestroy($img);
      }
    }
  }
}
?>