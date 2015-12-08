<?php
ob_start("ob_gzhandler");
session_start();
require_once('includes/main.inc');

if (!isset($_SESSION['language'])) @set_pref('language', 'en');
if (!isset($_SESSION['limit'])) @set_pref('limit', false);

head('browse');
?>
        <div id="main">
          <h2><?php print _("Browse"); ?></h2>
          <p><?php print _("You may browse through the loci and retrieve all related information."); ?></p>
<?php
  $sql = sql_connect($config['db']);
  $result = sql_query('SELECT a.prefix, a.id, a.name, a.functions, a.status, b.status FROM locus AS a, status AS b WHERE b.lang=\'' . get_pref('language') . '\' AND a.status=b.id' . (get_pref('limit')?(' AND a.status>0 AND a.status<=' . get_pref('limit')):'') . ' ORDER BY a.name ASC;', $sql);
  if ((!strlen($r = sql_last_error($sql))) && (sql_num_rows($result) > 0)) {
    print "          <ul class=\"result locus\">\n";
    while ($row = sql_fetch_row($result)) {
      if (!empty($row[4])) {
        print '            <li><a href="' . $config['server'] . '/locus/L' . decoct($row[0]) . '.' . decoct($row[1]) . '" title="L' . decoct($row[0]) . '.' . decoct($row[1]) . '" class="locus"><span class="name">' . $row[2] . '</span><span class="date"><img src="' . $config['server'] . '/images/status_' . $row[4] . '.png" height="8" width="8" alt="' . $row[5] . '" /></span><span class="description">' . ((strlen($row[3]) > 53)?(substr($row[3], 0, 50) . '...'):$row[3]) . "</span></a></li>\n";
      } else {
        print '            <li><span class="name">L' . decoct($row[0]) . '.' . decoct($row[1]) . '</span><span class="description"><em>' . _("Waiting for analyse, GeneID:") . ' ' . $row[2]. "</em></span></li>\n";
      }
    }
    print "          </ul>\n";
  } else {
    print '          <p>' . _("no result.") . "</p>\n";
  }
?>
        </div>
        <div id="side">
          <h2><?php print _("Browse"); ?></h2>
          <a href="<?php print $config['server'] . '/locus/add" title="' . _("Add a new locus") . '" class="go">' . _("Add a new locus"); ?></a>
          <a href="<?php print $config['server'] . '/new" title="' . _("Add a new prototype") . '" class="go">' . _("Add a new prototype"); ?></a>
          <h2 class="separated"><?php print _("Main menu"); ?></h2>
          <a href="<?php print $config['server']; ?>/browse" title="<?php print _("Browse in the database"); ?>" class="go"><?php print _("Browse"); ?></a>
          <a href="<?php print $config['server']; ?>/search" title="<?php print _("Direct web search"); ?>" class="go"><?php print _("Search"); ?></a>
          <a href="<?php print $config['server']; ?>/options" title="<?php print _("Preferences page"); ?>" class="go"><?php print _("Options"); ?></a>
        </div>
<?php

foot();
?>