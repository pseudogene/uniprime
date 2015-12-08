<?php
ob_start("ob_gzhandler");
session_start();
require_once('includes/main.inc');

$table = array('L' => 'locus', 'S' => 'sequence', 'A' => 'alignment', 'R' => 'mrna', 'X' => 'primer');

if (!isset($_SESSION['language'])) @set_pref('language', 'en');
if (!isset($_SESSION['limit'])) @set_pref('limit', false);
if (isset($_GET['history']) && !empty($_SESSION['search'][intval($_GET['history'])])) $_POST['query']=$_SESSION['search'][intval($_GET['history'])];
if (isset($_GET['query']) && preg_match('/(\w)(\d+)\.(\d+)/', strtoupper($_GET['query']), $matches) && array_key_exists($matches[1], $table)) {
  header('Location: ' . $config['server'] . '/' . $table[$matches[1]] . '/' . $matches[0]);
  exit;
} elseif (!empty($_POST['query']))  {
  $query = preg_replace('/&amp;(#x?[0-9a-f]+);/', '&\1', htmlentities(html_entity_decode(trim($_POST['query'])), ENT_QUOTES, 'ISO8859-1'));
  if (!isset($_GET['history'])) $_SESSION['search'][] = $query;
}
head('search');
?>
        <div id="main">
          <h2><?php print _("Search"); ?></h2>
          <p><?php print _("Retrieve a locus, a sequence, an alignment or a primer set. You may provide a reference number, a primer name, or a keyword."); ?></p>
          <form method="post" action="<?php print $config['server']; ?>/search" id="q">
            <p>
              <label for="query"><?php print _("Enter your query:"); ?></label>
              <input type="text" name="query" id="query" maxlength="50" title="<?php print _("Locus, Sequence or Primer name"); ?>" value="<?php print (empty($query) ? '' : $query ); ?>" accept="text/plain" accesskey="q" tabindex="1" />
              <input type="submit" value="<?php print _("Search"); ?>" accesskey="s" tabindex="2" />
            </p>
          <p class="autoclear"></p>
          </form>
          <h2 class="separated">
            <?php print _("Result"); ?>
          </h2>
<?php
  if (!empty($query)) {
    $query = addslashes($query);
    $sql = sql_connect($config['db']);
    preg_match('/^(\w)(\d+)\.(\d+)/', $query, $matches);
// locus
    $result = sql_query('SELECT DISTINCT a.prefix, a.id, a.name, a.functions, a.status, b.status FROM locus AS a,  status AS b WHERE b.lang=\'' . get_pref('language') . '\' AND a.status=b.id' . ((isset($matches[1]) && ($matches[1] == 'L'))?' AND a.prefix=' . octdec(intval($matches[2])) . ' AND a.id=' . octdec(intval($matches[3])):(get_pref('limit')?(' AND a.status>0 AND a.status<=' . get_pref('limit')):'') . ' AND (a.name' . sql_reg($query) . ' OR a.alias' . sql_reg($query) . ' OR a.functions' . sql_reg($query) . ' OR a.comments' . sql_reg($query) . ')') . ' ORDER BY a.name;', $sql);
    if ((!strlen($r = sql_last_error($sql))) && (sql_num_rows($result) > 0)) {
      $res=true;
      print "          <h3>" . _("Locus") . "</h3>\n          <ul class=\"result locus\">\n";
      while ($row = sql_fetch_row($result)) {
        if (!empty($row[4])) {
          print '            <li><a href="' . $config['server'] . '/locus/L' . decoct($row[0]) . '.' . decoct($row[1]) . '" title="L' . decoct($row[0]) . '.' . decoct($row[1]) . '" class="locus"><span class="name">' . $row[2] . '</span><span class="date"><img src="' . $config['server'] . '/images/status_' . $row[4] . '.png" height="8" width="8" alt="' . $row[5] . '" /></span><span class="description">' . ((strlen($row[3]) > 53)?(substr($row[3], 0, 50) . '...'):$row[3]) . "</span></a></li>\n";
        } else {
          print '            <li><span class="name">L' . decoct($row[0]) . '.' . decoct($row[1]) . '</span><span class="description"><em>' . _("Waiting for analayse, GeneID:") . ' ' . $row[2]. "</em></span></li>\n";
        }
      }
      print "          </ul>\n";
    }
// sequences
    $result = sql_query('SELECT DISTINCT a.prefix, a.id, a.name, a.map, a.accession, a.organism, a.sequence_type, a.updated, a.organelle FROM sequence AS a, sequence_type AS b WHERE b.lang=\'' . get_pref('language') . '\' AND a.sequence_type=b.id AND ' . ((isset($matches[1]) && ($matches[1] == 'S'))?'a.prefix=' . octdec(intval($matches[2])) . ' AND a.id=' . octdec(intval($matches[3])):('(a.name' . sql_reg($query) . ' OR a.alias' . sql_reg($query) . ' OR a.comments' . sql_reg($query) . ')')) . ' ORDER BY a.updated;', $sql);
    if ((!strlen($r = sql_last_error($sql))) && (sql_num_rows($result) > 0)) {
      $res=true;
      print "          <h3>" . _("Sequences") . "</h3>\n          <ul class=\"result sequence\">\n";
      while ($row = sql_fetch_row($result)) {
        $desc = '<em>' . ucfirst($row[5]) . '</em>' . (isset($row[3])?' - ' . $row[3]:'') . (!empty($row[4])?' (' . $row[4] . ')':'') . (isset($row[8])?' [' . $row[8] . ']':'');
        print '              <li><a href="' . $config['server'] . '/sequence/S' . decoct($row[0]) . '.' . decoct($row[1]) . '" title="S' . decoct($row[0]) . '.' . decoct($row[1]) . '" class="sequence"><span class="name">' . $row[2] . '</span><span class="date">' . date(_("m/d/Y"), strtotime($row[7])) . '</span><span class="description">' . ((strlen($desc) > 53)?(substr($desc, 0, 50) . '...'):$desc) . "</span></a></li>\n";
      }
      print "          </ul>\n";
    }
// primers
    $result = sql_query('SELECT a.prefix, a.id, b.name, a.left_name, a.right_name, a.location, a.updated FROM primer AS a, locus AS b WHERE ' . ((isset($matches[1]) && ($matches[1] == 'X'))?'a.prefix=' . octdec(intval($matches[2])) . ' AND a.id=' . octdec(intval($matches[3])):('(a.left_name' . sql_reg($query) . ' OR a.right_name' . sql_reg($query) . ' OR a.comments' . sql_reg($query) . ')')) . ' AND b.prefix=a.locus_prefix AND b.id=a.locus_id;', $sql);
    if ((!strlen($r = sql_last_error($sql))) && (sql_num_rows($result) > 0)) {
      $res=true;
      print "          <h3>" . _("Primers") . "</h3>\n          <ul class=\"result primer\">\n";
      $i = 1;
      while ($row = sql_fetch_row($result)) {
        print '              <li><a href="' . $config['server'] . '/primer/X' . decoct($row[0]) . '.' . decoct($row[1]) . '" title="X' . decoct($row[0]) . '.' . decoct($row[1]) . '" class="primer"><span class="name">' . $row[2] . '</span><span class="date">' . date(_("m/d/Y"), strtotime($row[6])) . '</span><span class="description">' . substr($row[5], 0, strpos($row[5], '(')) . '</span><span class="type">' . ((isset($row[3]) && isset($row[4]))?($row[3] . ' / ' . $row[4]):'') . "</span></a></li>\n";
      }
      print "          </ul>\n";
    }
  }
  if (!isset($res)) {
?>
          <p><?php print _("no result."); ?></p>
<?php
  }
?>
        </div>
        <div id="side">
<?php
 if ( isset($_SESSION['search']) ) {
    print '          <h2>' . _("Search"). "</h2>\n";
    print '          <p>' . ( (count($_SESSION['search'])>1) ? _("Last searches") : _("Last search") ) . "</p>\n";
    foreach ($_SESSION['search'] as $key => $history) {
      print '          <a href="' . $config['server'] .'/search?history=' . $key . '" class="go">' . $history . "</a>\n";
    }
    print '           <h2 class="separated">' . _("Main menu") . "</h2>\n";
  } else {
    print '           <h2>' . _("Main menu") . "</h2>\n";
  }
?>
          <a href="<?php print $config['server']; ?>/browse" title="<?php print _("Browse in the database"); ?>" class="go"><?php print _("Browse"); ?></a>
          <a href="<?php print $config['server']; ?>/search" title="<?php print _("Direct web search"); ?>" class="go"><?php print _("Search"); ?></a>
          <a href="<?php print $config['server']; ?>/options" title="<?php print _("Preferences page"); ?>" class="go"><?php print _("Options"); ?></a>
        </div>
<?php

foot();
?>