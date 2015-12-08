<?php
ob_start("ob_gzhandler");
session_start();
require_once('includes/main.inc');

if (isset($_GET['vpcr']) && preg_match('/^X(\d+)\.(\d+)/', $_GET['vpcr'], $matches)) {
    $sql = sql_connect($config['db']);
    $result = sql_query('SELECT b.mrna FROM sequence AS a, mrna as b, primer AS c WHERE c.prefix=' . octdec($matches[1]) . ' AND c.id=' . octdec($matches[2]) . ' AND a.locus_prefix=c.locus_prefix AND a.locus_id=c.locus_id AND b.sequence_prefix=a.prefix AND b.sequence_id=a.id AND a.sequence_type=1 ORDER BY b.prefix, b.id;', $sql);
    if ((!strlen($r = sql_last_error($sql))) && (sql_num_rows($result) >= 1)) {
      header('Powered by: ' . $config['powered']);
      header('Content-Type: chemical/seq-na-fasta');
      header('Content-Disposition: attachment; filename="'.$matches[0].'.fasta"');
      $row = sql_fetch_row($result);
      print ">Reference_mRNA\n".bzdecompress(base64_decode($row[0]))."\n\n";
      $result = sql_query('SELECT organism, sequence FROM sequence WHERE primer_prefix=' . octdec($matches[1]) . ' AND primer_id=' . octdec($matches[2]) . ';', $sql);
      if ((!strlen($r = sql_last_error($sql))) && (sql_num_rows($result) > 0)) {
        while ($row = sql_fetch_row($result)) {
          print '>'.strtr($row[0],' ','_')."\n".bzdecompress(base64_decode($row[1]))."\n\n";
        }
      }
    }
    exit(0);
} elseif (isset($_GET['edit']) && preg_match('/^X(\d+)\.(\d+)/', $_GET['edit'], $matches)) {
  $sql = sql_connect($config['db']);
  if (isset($_POST['remove']) && !empty($_POST['edit']) && ($_POST['edit'] == md5($matches[0]))) {
    $result = sql_query('DELETE FROM sequence WHERE primer_prefix=' . octdec($matches[1]) . ' AND primer_id=' . octdec($matches[3]) . ';', $sql);
    $result = sql_query('DELETE FROM primer WHERE prefix=' . octdec($matches[1]) . ' AND id=' . octdec($matches[2]) . ';', $sql);
    header('Location: ' . $config['server'] . '/');
    exit(0);
  } elseif (isset($_POST['update']) && !empty($_POST['edit']) && ($_POST['edit'] == md5($matches[0])) && !empty($_POST['left_seq']) && !empty($_POST['right_seq'])) {
      $entry['left_seq'] = preg_replace('/[^\w]/', '', strtoupper($_POST['left_seq']));
      if (!empty($_POST['left_name'])) {
        $entry['left_name'] = preg_replace('/[^\d\w\.\-\_\ ]/', '', $_POST['left_name']);
      }
      $entry['left_penality'] = ((!empty($_POST['left_penality']) && (floatval($_POST['left_penality']) > 0))?floatval($_POST['left_penality']):0);
      $entry['right_seq'] = preg_replace('/[^\w]/', '', strtoupper($_POST['right_seq']));
      if (!empty($_POST['right_name'])) {
        $entry['right_name'] = preg_replace('/[^\d\w\.\-\_\ ]/', '', $_POST['right_name']);
      }
      $entry['right_penality'] = ((!empty($_POST['right_penality']) && (floatval($_POST['right_penality']) > 0))?floatval($_POST['right_penality']):0);
      if (!empty($_POST['location'])) {
        $entry['location'] = preg_replace('/[^\d\w\.\-\_\ ]/', '', $_POST['location']);
      }
      if (!empty($_POST['comments'])) {
        $entry['comments'] = ucfirst(preg_replace('/&amp;(#x?[0-9a-f]+);/', '&\1', htmlentities(html_entity_decode($_POST['comments']), ENT_QUOTES, 'ISO8859-1')));
      }
      if (!empty($_POST['pcr'])) {
        $entry['pcr'] = preg_replace('/&amp;(#x?[0-9a-f]+);/', '&\1', htmlentities(html_entity_decode($_POST['pcr']), ENT_QUOTES, 'ISO8859-1'));
      }
      if (isset($_POST['left_pos']) && (intval($_POST['left_pos']) > 0)) $entry['left_pos'] = intval($_POST['left_pos']);
      if (isset($_POST['right_pos']) && (intval($_POST['right_pos']) > 0)) $entry['right_pos'] = intval($_POST['right_pos']);

      $entry['right_tm'] = Tm($entry['right_seq']);
      $entry['left_tm'] = Tm($entry['left_seq']);
      $entry['right_gc'] = CG($entry['right_seq']);
      $entry['left_gc'] = CG($entry['left_seq']);
      $result = sql_query('UPDATE primer SET penality=' . ($entry['left_penality'] + $entry['right_penality']) . ', left_seq=\'' . addslashes($entry['left_seq']) . '\', left_data=\'' . addslashes((isset($entry['left_pos']) ? $entry['left_pos'] : 0 ) . '|' . strlen($entry['left_seq']) . '|' . $entry['left_tm'] . '|' . $entry['left_gc'] . '|' . $entry['left_penality']) . '\', left_name=' . (isset($entry['left_name'])?('\'' . addslashes($entry['left_name']) . '\''):'NULL') . ', right_seq=\'' . addslashes($entry['right_seq']) . '\', right_data=\'' . addslashes((isset($entry['right_pos']) ? $entry['right_pos'] : 0 ) . '|' . strlen($entry['right_seq']) . '|' . $entry['right_tm'] . '|' . $entry['right_gc'] . '|' . $entry['right_penality']) . '\', right_name=' . (isset($entry['right_name'])?('\'' . addslashes($entry['right_name']) . '\''):'NULL') . ', location=' . (isset($entry['location'])?('\'' . addslashes($entry['location']) . '\''):'NULL') . ', pcr=' . (isset($entry['pcr'])?('\'' . addslashes($entry['pcr']) . '\''):'NULL') . ', comments=' . (isset($entry['comments'])?('\'' . addslashes($entry['comments']) . '\''):'NULL') . ', updated=NOW(), author=\'UniPrime Web\' WHERE prefix=' . octdec($matches[1]) . ' AND id=' . octdec($matches[2]) . ';', $sql);
      if (!strlen($r = sql_last_error($sql))) {
         header('Location: ' . $config['server'] . '/primer/' . $matches[0]);
         exit(0);
      }else {
          $msg = _("Entry invalid, check your data") ;
      }
  }
  $result = sql_query('SELECT prefix, id, left_seq, left_data, left_name, right_seq, right_data, right_name, location, pcr, comments FROM primer WHERE prefix=' . octdec($matches[1]) . ' AND id=' . octdec($matches[2]) . ';', $sql);
  if ((!strlen($r = sql_last_error($sql))) && (sql_num_rows($result) == 1)) {
    head($matches[0]);
    $row = sql_fetch_row($result);
    $row[3] = explode('|', $row[3]);
    $row[6] = explode('|', $row[6]);
?>
        <div id="main">
          <h2>X<?php print decoct($row[0]) . '.' . decoct($row[1]); ?></h2>
<?php if (!empty($msg)) { print "          <p><strong>$msg</strong></p>\n"; } ?>
          <form method="post" action="<?php print $config['server'].'/primer/edit/'.$matches[0]; ?>" id="form">
            <h3><?php print _("Forward primer"); ?></h2>
            <div class="autoclear"><label for="left_name"><?php print _("Primer name"); ?></label> <input type="text" name="left_name" id="left_name" maxlength="50" title="<?php print _("Reference name"); ?>" <?php print (!empty($_POST['left_name'])?' value="'.$_POST['left_name'].'" ':((!isset($_POST['left_name']) && !empty($row[4]))?' value="'.$row[4].'" ':'')); ?>/><br /></div>
            <div class="autoclear"><label for="left_seq"><strong><?php print _("Sequence"); ?></strong></label> <input type="text" name="left_seq" id="left_seq" maxlength="50" title="<?php print _("DNA sequence"); ?>" <?php print (!empty($_POST['left_seq'])?' value="'.$_POST['left_seq'].'" ':((!isset($_POST['left_seq']) && !empty($row[2]))?' value="'.$row[2].'" ':'')); ?>/><br /></div>
            <div class="autoclear"><label for="left_pos"><?php print _("Position"); ?></label> <input type="text" name="left_pos" id="left_pos" maxlength="10" title="<?php print _("Start position of the primer in the alignment"); ?>" <?php print (!empty($_POST['left_pos'])?' value="'.$_POST['left_pos'].'" ':((!isset($_POST['left_pos']) && !empty($row[3][0]))?' value="'.$row[3][0].'" ':'')); ?>/><br /></div>
            <div class="autoclear"><label for="left_penality"><?php print _("Primer penalty:"); ?></label> <input type="text" name="left_penality" id="left_penality" maxlength="10" title="<?php print _("Primer penalty (defined by Primer3)"); ?>" <?php print (!empty($_POST['left_penality'])?' value="'.$_POST['left_penality'].'" ':((!isset($_POST['left_penality']) && !empty($row[3][4]))?' value="'.$row[3][4].'" ':'')); ?>/><br /></div>
            <h3><?php print _("Reverse primer"); ?></h3>
            <div class="autoclear"><label for="right_name"><?php print _("Primer name"); ?></label> <input type="text" name="right_name" id="right_name" maxlength="50" title="<?php print _("Reference name"); ?>" <?php print (!empty($_POST['right_name'])?' value="'.$_POST['right_name'].'" ':((!isset($_POST['right_name']) && !empty($row[7]))?' value="'.$row[7].'" ':'')); ?>/><br /></div>
            <div class="autoclear"><label for="right_seq"><strong><?php print _("Sequence"); ?></strong></label> <input type="text" name="right_seq" id="right_seq" maxlength="50" title="<?php print _("DNA sequence"); ?>" <?php print (!empty($_POST['right_seq'])?' value="'.$_POST['right_seq'].'" ':((!isset($_POST['right_seq']) && !empty($row[5]))?' value="'.$row[5].'" ':'')); ?>/><br /></div>
            <div class="autoclear"><label for="right_pos"><?php print _("Position"); ?></label> <input type="text" name="right_pos" id="right_pos" maxlength="10" title="<?php print _("Start position of the primer in the alignment"); ?>" <?php print (!empty($_POST['right_pos'])?' value="'.$_POST['right_pos'].'" ':((!isset($_POST['right_pos']) && !empty($row[6][0]))?' value="'.$row[6][0].'" ':'')); ?>/><br /></div>
            <div class="autoclear"><label for="right_penality"><?php print _("Primer penalty"); ?></label> <input type="text" name="right_penality" id="right_penality" maxlength="10" title="<?php print _("Primer penalty (defined by Primer3)"); ?>" <?php print (!empty($_POST['right_penality'])?' value="'.$_POST['right_penality'].'" ':((!isset($_POST['right_penality']) && !empty($row[6][4]))?' value="'.$row[6][4].'" ':'')); ?>/><br /></div>
            <h3><?php print _("General"); ?></h3>
            <div class="autoclear"><label for="pcr"><?php print _("PCR conditions"); ?></label> <input type="text" name="pcr" id="pcr" title="<?php print _("PCR conditions"); ?>" <?php print (!empty($_POST['pcr'])?' value="'.$_POST['pcr'].'" ':((!isset($_POST['pcr']) && !empty($row[9]))?' value="'.$row[9].'" ':'')); ?>/><br /></div>
            <div class="autoclear"><label for="location"><?php print _("Product location"); ?></label> <input type="text" name="location" id="location" title="<?php print _("Product location (ex. intron1-exon2)"); ?>" <?php print (!empty($_POST['location'])?' value="'.$_POST['location'].'" ':((!isset($_POST['location']) && !empty($row[8]))?' value="'.$row[8].'" ':'')); ?>/><br /></div>
            <div class="autoclear"><label for="comments"><?php print _("Comments"); ?></label> <textarea name="comments" id="comments" cols="30" rows="3" title="<?php print _("Primer pair comments"); ?>"><?php print (!empty($_POST['comments'])?$_POST['comments']:((!isset($_POST['comments']) && !empty($row[10]))?$row[10]:'')); ?></textarea><br /></div>
            <p class="autoclear">
              <input type="hidden" name="edit" value="<?php print md5($matches[0]); ?>" />
              <input type="reset" value="<?php print _("Clear"); ?>" accesskey="c" />&nbsp;<input type="submit" name="update" value="<?php print _("Update"); ?>" accesskey="u" />&nbsp;<input type="submit" name="remove" value="<?php print _("Remove"); ?>" onclick="return confirm('<?php print _("Are you sure you want to delete?"); ?>')" accesskey="r" />
            </p>
            <p class="autoclear"></p>
          </form>
        </div>
<?php
  }
} elseif (!empty($_GET['add']) && preg_match('/^A(\d+)\.(\d+)/', $_GET['add'], $matches)) {
  $sql = sql_connect($config['db']);
  if (!empty($_POST['uniprime']) && ($_POST['uniprime'] == md5('add')) && !empty($_POST['left_seq']) && !empty($_POST['right_seq'])) {
      $entry['left_seq'] = preg_replace('/[^\w]/', '', strtoupper($_POST['left_seq']));
      if (!empty($_POST['left_name'])) {
        $entry['left_name'] = preg_replace('/[^\d\w\.\-\_\ ]/', '', $_POST['left_name']);
      }
      $entry['left_penality'] = ((!empty($_POST['left_penality']) && (floatval($_POST['left_penality']) > 0))?floatval($_POST['left_penality']):0);
      $entry['right_seq'] = preg_replace('/[^\w]/', '', strtoupper($_POST['right_seq']));
      if (!empty($_POST['right_name'])) {
        $entry['right_name'] = preg_replace('/[^\d\w\.\-\_\ ]/', '', $_POST['right_name']);
      }
      $entry['right_penality'] = ((!empty($_POST['right_penality']) && (floatval($_POST['right_penality']) > 0))?floatval($_POST['right_penality']):0);
      if (!empty($_POST['location'])) {
        $entry['location'] = preg_replace('/[^\d\w\.\-\_\ ]/', '', $_POST['location']);
      }
      if (!empty($_POST['comments'])) {
        $entry['comments'] = ucfirst(preg_replace('/&amp;(#x?[0-9a-f]+);/', '&\1', htmlentities(html_entity_decode($_POST['comments']), ENT_QUOTES, 'ISO8859-1')));
      }
      if (!empty($_POST['pcr'])) {
        $entry['pcr'] = preg_replace('/&amp;(#x?[0-9a-f]+);/', '&\1', htmlentities(html_entity_decode($_POST['pcr']), ENT_QUOTES, 'ISO8859-1'));
      }
      if (isset($_POST['left_pos']) && (intval($_POST['left_pos']) > 0)) $entry['left_pos'] = intval($_POST['left_pos']);
      if (isset($_POST['right_pos']) && (intval($_POST['right_pos']) > 0)) $entry['right_pos'] = intval($_POST['right_pos']);
      $result = sql_query('SELECT locus_prefix, locus_id FROM alignment WHERE prefix='.octdec($matches[1]).' AND id=' . octdec($matches[2]) . ';', $sql);
      if ((!strlen($r = sql_last_error($sql))) && (sql_num_rows($result) == 1)) {
        $row = sql_fetch_row($result);
        $prefix = floor(((intval(date('Y', time())) - 2007) * 12 + intval(date('m', time())) - 1) / 1.5);
        $entry['right_tm'] = Tm($entry['right_seq']);
        $entry['left_tm'] = Tm($entry['left_seq']);
        $entry['right_gc'] = CG($entry['right_seq']);
        $entry['left_gc'] = CG($entry['left_seq']);
        $result = sql_query('INSERT INTO primer (prefix, id, locus_prefix, locus_id, alignment_prefix, alignment_id, penality, left_seq, left_data, left_name, right_seq, right_data, right_name, location, pcr, comments, author) SELECT ' . $prefix . ', CASE WHEN max(id)>=1 THEN max(id)+1 ELSE 1 END, ' . $row[0] . ',' . $row[1] . ',' . octdec($matches[1]). ','. octdec($matches[2]) . ',' . ($entry['left_penality'] + $entry['right_penality']) . ',\'' . addslashes($entry['left_seq']) . '\',\'' . addslashes((isset($entry['left_pos']) ? $entry['left_pos'] : 0 ) . '|' . strlen($entry['left_seq']) . '|' . $entry['left_tm'] . '|' . $entry['left_gc'] . '|' . $entry['left_penality']) . '\',' . (isset($entry['left_name'])?('\'' . addslashes($entry['left_name']) . '\''):'NULL') . ',\'' . addslashes($entry['right_seq']) . '\',\'' . addslashes((isset($entry['right_pos']) ? $entry['right_pos'] : 0 ) . '|' . strlen($entry['right_seq']) . '|' . $entry['right_tm'] . '|' . $entry['right_gc'] . '|' . $entry['right_penality']) . '\',' . (isset($entry['right_name'])?('\'' . addslashes($entry['right_name']) . '\''):'NULL') . ',' . (isset($entry['location'])?('\'' . addslashes($entry['location']) . '\''):'NULL') . ',' . (isset($entry['pcr'])?('\'' . addslashes($entry['pcr']) . '\''):'NULL') . ',' . (isset($entry['comments'])?('\'' . addslashes($entry['comments']) . '\''):'NULL') . ',\'UniPrime Web\' FROM primer WHERE prefix=' . $prefix . ';', $sql);
        if (!strlen($r = sql_last_error($sql))) {
          header('Location: ' . $config['server'] . '/alignment/' . $matches[0]);
          exit(0);
        }else {
          $msg = _("Entry invalid, check your data") ;
        }
      }else {
        $msg = _("Entry invalid, check your data");
      }
  }

  head('primer', true);
?>
        <div id="main">
          <h2><?php print _("New primers for the Alignment") . ' ' . $matches[0]; ?></h2>
<?php if (!empty($msg)) { print "          <p><strong>$msg</strong></p>\n"; } ?>
          <form method="post" action="<?php print $config['server'].'/primer/add/'.$matches[0]; ?>" id="form">
            <div class="autoclear"><label for="advanced"><?php print _("Advanced"); ?></label> <input type="checkbox" name="advanced" id="advanced" rel="advanced"<?php print (!empty($_POST['advanced'])?' checked="checked"':''); ?> /><br /></div>
            <h3><?php print _("Forward primer"); ?></h2>
            <div class="autoclear" rel="advanced"><label for="left_name"><?php print _("Primer name"); ?></label> <input type="text" name="left_name" id="left_name" maxlength="50" title="<?php print _("Reference name"); ?>" <?php print (!empty($_POST['left_name'])?' value="' . $_POST['left_name'] . '" ':''); ?>/><br /></div>
            <div class="autoclear"><label for="left_seq"><strong><?php print _("Sequence"); ?></strong></label> <input type="text" name="left_seq" id="left_seq" maxlength="50" title="<?php print _("DNA sequence"); ?>" <?php print (!empty($_POST['left_seq'])?' value="' . $_POST['left_seq'] . '" ':''); ?>/><br /></div>
            <div class="autoclear" rel="advanced"><label for="left_pos"><?php print _("Position"); ?></label> <input type="text" name="left_pos" id="left_pos" maxlength="10" title="<?php print _("Start position of the primer in the alignment"); ?>" <?php print (!empty($_POST['left_pos'])?' value="' . $_POST['left_pos'] . '" ':''); ?>/><br /></div>
            <div class="autoclear" rel="advanced"><label for="left_penality"><?php print _("Primer penalty:"); ?></label> <input type="text" name="left_penality" id="left_penality" maxlength="10" title="<?php print _("Primer penalty (defined by Primer3)"); ?>" <?php print (!empty($_POST['left_penality'])?' value="' . $_POST['left_penality'] . '" ':''); ?>/><br /></div>
            <h3><?php print _("Reverse primer"); ?></h3>
            <div class="autoclear" rel="advanced"><label for="right_name"><?php print _("Primer name"); ?></label> <input type="text" name="right_name" id="right_name" maxlength="50" title="<?php print _("Reference name"); ?>" <?php print (!empty($_POST['right_name'])?' value="' . $_POST['right_name'] . '" ':''); ?>/><br /></div>
            <div class="autoclear"><label for="right_seq"><strong><?php print _("Sequence"); ?></strong></label> <input type="text" name="right_seq" id="right_seq" maxlength="50" title="<?php print _("DNA sequence"); ?>" <?php print (!empty($_POST['right_seq'])?' value="' . $_POST['right_seq'] . '" ':''); ?>/><br /></div>
            <div class="autoclear" rel="advanced"><label for="right_pos"><?php print _("Position"); ?></label> <input type="text" name="right_pos" id="right_pos" maxlength="10" title="<?php print _("Start position of the primer in the alignment"); ?>" <?php print (isset($_POST['right_pos'])?' value="' . $_POST['right_pos'] . '" ':''); ?>/><br /></div>
            <div class="autoclear" rel="advanced"><label for="right_penality"><?php print _("Primer penalty"); ?></label> <input type="text" name="right_penality" id="right_penality" maxlength="10" title="<?php print _("Primer penalty (defined by Primer3)"); ?>" <?php print (!empty($_POST['right_penality'])?' value="' . $_POST['right_penality'] . '" ':''); ?>/><br /></div>
            <h3><?php print _("General"); ?></h3>
            <div class="autoclear" rel="advanced"><label for="pcr"><?php print _("PCR conditions"); ?></label> <input type="text" name="pcr" id="pcr" title="<?php print _("PCR conditions"); ?>" <?php print (!empty($_POST['pcr'])?' value="' . $_POST['pcr'] . '" ':''); ?>/><br /></div>
            <div class="autoclear"><label for="location"><?php print _("Product location"); ?></label> <input type="text" name="location" id="location" title="<?php print _("Product location (ex. intron1-exon2)"); ?>" <?php print (!empty($_POST['location'])?' value="' . $_POST['location'] . '" ':''); ?>/><br /></div>
            <div class="autoclear"><label for="comments"><?php print _("Comments"); ?></label> <textarea name="comments" id="comments" cols="30" rows="3" title="<?php print _("Primer pair comments"); ?>"><?php print (!empty($_POST['comments'])?$_POST['comments']:''); ?></textarea><br /></div>
            <p class="autoclear">
              <input type="hidden" name="uniprime" value="<?php print md5('add'); ?>" />
              <input type="reset" value="<?php print _("Clear"); ?>" accesskey="c" />&nbsp;<input type="submit" value="<?php print _("Add"); ?>" accesskey="a" />
            </p>
            <p class="autoclear"></p>
          </form>
        </div>
        <div id="side">
          <h2><?php print _("Alignment"); ?></h2>
          <a href="<?php print $config['server'] . '/alignment/' . $matches[0] . '" title="' . _("Back...") . '" class="go">' . _("Back"); ?></a>
          <a href="<?php print $config['server'] . '/primer/add/' . $matches[0] . '" title="' . _("Add a new primer set") . '" class="go">' . _("New primers"); ?></a>
        </div>
<?php
}elseif (isset($_GET['primer']) && preg_match('/^X(\d+)\.(\d+)/', $_GET['primer'], $matches)) {
  head($matches[0]);
  $sql = sql_connect($config['db']);
  $result = sql_query('SELECT a.prefix, a.id, a.locus_prefix, a.locus_id, b.name, b.functions, a.alignment_prefix, a.alignment_id, c.updated, a.penality, a.left_seq, a.left_data, a.left_name, a.right_seq, a.right_data, a.right_name, a.location, a.pcr, a.updated, a.comments FROM primer AS a, locus AS b, alignment AS c WHERE b.prefix=a.locus_prefix AND b.id=a.locus_id AND a.prefix=' . octdec($matches[1]) . ' AND a.id=' . octdec($matches[2]) . ' AND c.prefix=a.alignment_prefix AND c.id=a.alignment_id;', $sql);
  if ((!strlen($r = sql_last_error($sql))) && (sql_num_rows($result) == 1)) {
    $row = sql_fetch_row($result);
?>
        <div id="main">
          <h2>X<?php print decoct($row[0]) . '.' . decoct($row[1]); ?></h2>
<?php
      print '          <h3>' . ("Locus") . "</h3>\n          <p>\n";
      print '            <span class="title">' . _("Name") . '</span> <span class="desc"><a href="' . $config['server'] . '/locus/L' . decoct($row[2]) . '.' . decoct($row[3]) . '">' . $row[4] . "</a></span><br />\n";
      if (!empty($row[5])) {
        print '            <span class="title">' . _("Functions") . '</span> <span class="desc">' . $row[5] . "</span><br />\n";
      }
      print "          </p>\n          <h3>" . ("Alignment") . "</h3>\n          <p>\n";
      print '            <span class="title">' . _("Name") . '</span> <span class="desc"><a href="' . $config['server'] . '/alignment/A' . decoct($row[6]) . '.' . decoct($row[7]) . '">' . $row[4] . ' - ' . date(_("m/d/Y"), strtotime($row[8])) . "</a></span><br />\n";
      print "          </p>\n          <h3>" . ("Primer set") . "</h3>\n          <p>\n";
      print '            <img src="' . $config['server'] . '/primer/draw/' . $matches[0] . "\" alt=\"\" class=\"right\" />\n";
      print '            <span class="title">' . _("ID") . '</span> <span class="desc">X' . decoct($row[0]) . '.' . decoct($row[1]) . "</span><br />\n";
      print '            <span class="title">' . _("Location") . '</span> <span class="desc">' . $row[16] . "</span><br />\n";
      print '            <span class="title">' . _("Release") . '</span> <span class="desc">' . date(_("m/d/Y"), strtotime($row[18])) . "</span><br />\n";
      print '            <span class="title">' . _("Primer set") . '</span> <span class="desc"><a href="#" onclick="window.open(\'' . $config['server'] . '/primer/xml/' . $matches[0] . '\', \'' . _("Primer set") . '\', \'toolbar=no, location=no, directories=no, status=no, scrollbars=yes, resizable=yes, copyhistory=no, width=450, height=400, left=300, top=50\');return false;" title="' . _("Export primer set") . '">' . _("Export") . "</a></span><br />\n";
      if (!empty($row[9])) print '            <span class="title">' . _("Primer penalty") . '</span> <span class="desc">' . $row[9] . "</span><br />\n";
      print "          </p>\n          <h3>" . ("Forward") . "</h3>\n          <p>\n";
      $data = explode('|', $row[11]);
      if (!empty($row[12])) print '            <span class="title">' . _("Name") . '</span> <span class="desc">' . $row[12] . "</span><br />\n";
      print '            <span class="title">' . _("Sequence") . '</span> <span class="desc">' .  $row[10] . "</span><br />\n";
      print '            <span class="title">' . _("Size") . '</span> <span class="desc">' . $data[1] . " nt</span><br />\n";
      print '            <span class="title">' . _("CG") . '</span> <span class="desc">' . $data[3] . "%</span><br />\n";
      if (!empty($data[4])) print '            <span class="title">' . _("Penalty") . '</span> <span class="desc">' . $data[4] . "</span><br />\n";
      print '            <span class="title">' . _("TM") . '</span> <span class="desc">' . $data[2] . "&deg;C</span><br />\n";
      if (!empty($data[0])) print '            <span class="title">' . _("Position") . '</span> <span class="desc">' . $data[0] . "</span><br />\n";
      print "          </p>\n          <h3>" . ("Reverse") . "</h3>\n          <p>\n";
      $data = explode('|', $row[14]);
      if (!empty($row[12])) print '            <span class="title">' . _("Name") . '</span> <span class="desc">' . $row[15] . "</span><br />\n";
      print '            <span class="title">' . _("Sequence") . '</span> <span class="desc">' .  $row[13] . "</span><br />\n";
      print '            <span class="title">' . _("Size") . '</span> <span class="desc">' . $data[1] . " nt</span><br />\n";
      print '            <span class="title">' . _("CG") . '</span> <span class="desc">' . $data[3] . "%</span><br />\n";
      if (!empty($data[4])) print '            <span class="title">' . _("Penalty") . '</span> <span class="desc">' . $data[4] . "</span><br />\n";
      print '            <span class="title">' . _("TM") . '</span> <span class="desc">' . $data[2] . "&deg;C</span><br />\n";
      if (!empty($data[0])) print '            <span class="title">' . _("Position") . '</span> <span class="desc">' . $data[0] . "</span><br />\n";
      if (!empty($row[17])) print "          </p>\n          <h3>" . _("PCR Conditions") . "</h3>\n          <p>\n            " . $row[17];
      if (!empty($row[19])) print "          </p>\n          <h3>" . _("Comments") . "</h3>\n          <p>\n            " . $row[19];
      print "          </p>\n";
      $result = sql_query('SELECT DISTINCT a.prefix, a.id, a.name, a.map, a.accession, a.organism, a.sequence_type, a.updated, a.organelle FROM sequence AS a, sequence_type AS b WHERE b.lang=\'' . get_pref('language') . '\' AND a.sequence_type=b.id AND a.primer_prefix=' . octdec($matches[1]) . ' AND a.primer_id=' . octdec($matches[2]) . ' AND a.sequence_type>=3 ORDER BY a.updated;', $sql);
      if ((!strlen($r = sql_last_error($sql))) && (sql_num_rows($result) > 0)) {
        print "          <h3>" . _("Sequences") . "</h3>\n          <p>\n";
        print '            <span class="title">' . _("Sequences") . '</span> <span class="desc"><a href="' . $config['server'] . '/vpcr/' . $matches[0] . '">' . _("Export in Fasta format") . "</a></span><br />\n";
        print "          </p>\n          <ul class=\"result sequence\">\n";
        while ($row = sql_fetch_row($result)) {
          $desc = '<em>' . ucfirst($row[5]) . '</em>' . (isset($row[3])?' - ' . $row[3]:'') . (!empty($row[4])?' (' . $row[4] . ')':'') . (isset($row[8])?' [' . $row[8] . ']':'');
          print '              <li><a href="' . $config['server'] . '/sequence/S' . decoct($row[0]) . '.' . decoct($row[1]) . '" title="S' . decoct($row[0]) . '.' . decoct($row[1]) . '" class="sequence"><span class="name">' . $row[2] . '</span><span class="date">' . date(_("m/d/Y"), strtotime($row[7])) . '</span><span class="description">' . ((strlen($desc) > 53)?(substr($desc, 0, 50) . '...'):$desc) . "</span></a></li>\n";
        }
        print "          </ul>\n";
      }

?>
        </div>
        <div id="side">
          <h2><?php print _("Primer"); ?></h2>
          <a href="<?php print $config['server'] . '/primer/edit/' . $matches[0] . '" title="' . _("Edit") . '" class="go">' . _("Edit"); ?></a>
        </div>
<?php
  }
}

foot();
?>