<?php
ob_start("ob_gzhandler");
session_start();
require_once('includes/main.inc');

if (!isset($_SESSION['language'])) @set_pref('language', 'en');

if (isset($_GET['edit']) && preg_match('/^A(\d+)\.(\d+)/', $_GET['edit'], $matches)) {
  $sql = sql_connect($config['db']);
  if (isset($_POST['remove']) && !empty($_POST['edit']) &&  ($_POST['edit'] == md5($matches[0]))) {
    $result = sql_query('SELECT prefix, id FROM primer WHERE alignment_prefix=' . octdec($matches[1]) . ' AND alignment_id=' . octdec($matches[2]) . ';', $sql);
    if ((!strlen($r = sql_last_error($sql))) && (sql_num_rows($result) > 0)) {
      while ($row2 = sql_fetch_row($result)) {
        $result = sql_query('DELETE FROM sequence WHERE primer_prefix=' . $row2[0] . ' AND primer_id=' . $row2[1] . ';', $sql);
      }
      $result = sql_query('DELETE FROM primer WHERE alignment_prefix=' . octdec($matches[1]) . ' AND alignment_id=' . octdec($matches[2]) . ';', $sql);
    }
    $result = sql_query('DELETE FROM alignment WHERE prefix=' . octdec($matches[1]) . ' AND id=' . octdec($matches[2]) . ';', $sql);
    header('Location: ' . $config['server'] . '/');
    exit(0);
  } elseif (isset($_POST['update']) && !empty($_POST['edit']) && ($_POST['edit'] == md5($matches[0])) && !empty($_POST['program']) && !empty($_POST['alignment']) && !empty($_POST['consensus']) && isset($_POST['sequences'][2])) {
      $entry['sequences'] = $_POST['sequences'];
      $entry['alignment'] = preg_replace('/&amp;(#x?[0-9a-f]+);/', '&\1', htmlentities(html_entity_decode($_POST['alignment']), ENT_QUOTES, 'ISO8859-1'));
      $entry['consensus'] = preg_replace('/[^\w]/', '', strtoupper($_POST['consensus']));
      $entry['program'] = preg_replace('/[^\d\w\.\-\_\ ]/', '', $_POST['program']);
      if (!empty($_POST['comments'])) {
        $entry['comments'] = ucfirst(preg_replace('/&amp;(#x?[0-9a-f]+);/', '&\1', htmlentities(html_entity_decode($_POST['comments']), ENT_QUOTES, 'ISO8859-1')));
      }
      $result = sql_query('UPDATE alignment SET sequences=\'' . implode(' ', $entry['sequences']) . '\', alignment=\'' . addslashes(base64_encode(bzcompress($entry['alignment']))) . '\', consensus=\'' . addslashes(base64_encode(bzcompress($entry['consensus']))) . '\', program=\'' . addslashes($entry['program']) . '\', comments=' . (isset($entry['comments'])?('\'' . addslashes($entry['comments']) . '\''):'NULL') . ', updated=NOW(), author=\'UniPrime/Web\' WHERE prefix=' . $matches[1] . ' AND id=' . $matches[2] . ';', $sql);
      if (!strlen($r = sql_last_error($sql))) {
        header('Location: ' . $config['server'] . '/alignment/' . $matches[0]);
        exit(0);
      }else {
        $msg = _("Entry invalid, check your data");
      }
  }
  $result = sql_query('SELECT a.prefix, a.id, b.name, a.sequences, a.program, a.comments, a.updated, a.alignment, a.consensus, a.locus_prefix, a.locus_id FROM alignment AS a, locus AS b WHERE a.prefix=' . octdec($matches[1]) . ' AND a.id=' . octdec($matches[2]) . ' AND b.prefix=a.locus_prefix AND b.id=a.locus_id;', $sql);
  if ((!strlen($r = sql_last_error($sql))) && (sql_num_rows($result) == 1)) {
    head($matches[0]);
    $row = sql_fetch_row($result);
    $row[3] = explode(' ', $row[3]);
?>
        <div id="main">
          <h2><?php print $row[2].' - '.date(_("m/d/Y"),strtotime($row[6])); ?></h2>
<?php if (!empty($msg)) { print "          <p><strong>$msg</strong></p>\n"; } ?>
          <form method="post" action="<?php print $config['server'].'/alignment/edit/'.$matches[0]; ?>" id="form">
            <div class="autoclear"><label for="program"><strong><?php print _("Program used"); ?></strong></label> <input type="text" name="program" id="program" maxlength="100" title="<?php print _("Program and version used"); ?>" <?php print (!empty($_POST['program'])?' value="'.$_POST['program'].'" ':((!isset($_POST['program']) && !empty($row[4]))?' value="'.$row[4].'" ':'')); ?>/><br /></div>
<?php
    $result = sql_query('SELECT a.prefix, a.id, a.name, a.organism, b.sequence_type FROM sequence AS a, sequence_type AS b WHERE a.sequence_type=b.id AND a.locus_prefix=' . $row[9] . ' AND a.locus_id=' . $row[10] . ' ORDER BY a.sequence_type, a.id, a.organism;', $sql);
    if ((!strlen($r = sql_last_error($sql))) && (sql_num_rows($result) > 0)) {
      print '            <div class="autoclear"><label for="sequences"><strong>' . _("Sequence used") . '</strong></label> <select name="sequences[]" id="sequences" title="' . _("Sequences used for the alignment") . '" multiple="multiple" class="multiple">';
      while ($row2 = sql_fetch_row($result)) {
        print '<option value="'.decoct($row2[0]).'.'.decoct($row2[1]).'"' . (((!empty($_POST['sequences']) && (array_search(decoct($row2[0]).'.'.decoct($row2[1]), $_POST['sequences'],true) !== false)) || (!isset($_POST['sequences']) && !empty($row[3]) && (array_search(decoct($row2[0]).'.'.decoct($row2[1]), $row[3],true) !== false)))?' selected="selected"':'') . ">$row2[2] ($row2[3] - $row2[4])</option>";
      }
      print "</select><br /></div>\n";
    }
?>
            <div class="autoclear"><label for="alignment"><strong><?php print _("Alignment"); ?></strong></label> <textarea name="alignment" id="alignment" cols="30" rows="6" title="<?php print _("Interleave ClustalW Alignment or Fasta Alignment"); ?>"><?php print (!empty($_POST['alignment'])?$_POST['alignment']:((!isset($_POST['alignment']) && !empty($row[7]))?bzdecompress(base64_decode($row[7])):'')); ?></textarea><br /></div>
            <div class="autoclear"><label for="consensus"><strong><?php print _("Consensus"); ?></strong></label> <textarea name="consensus" id="consensus" cols="30" rows="3" title="<?php print _("Consensus sequence (raw sequence only)"); ?>"><?php print (!empty($_POST['consensus'])?$_POST['consensus']:((!isset($_POST['consensus']) && !empty($row[8]))?bzdecompress(base64_decode($row[8])):'')); ?></textarea><br /></div>
            <div class="autoclear"><label for="comments"><?php print _("Comments"); ?></label> <textarea name="comments" id="comments" cols="30" rows="3" title="<?php print _("Primer pair comments"); ?>"><?php print (!empty($_POST['comments'])?$_POST['comments']:((!isset($_POST['comments']) && !empty($row[5]))?$row[5]:'')); ?></textarea><br /></div>
            <p class="autoclear">
              <input type="hidden" name="edit" value="<?php print md5($matches[0]); ?>" />
              <input type="reset" value="<?php print _("Clear"); ?>" accesskey="c" />&nbsp;<input type="submit" name="update" value="<?php print _("Update"); ?>" accesskey="u" />&nbsp;<input type="submit" name="remove" value="<?php print _("Remove"); ?>" onclick="return confirm('<?php print _("Are you sure you want to delete?"); ?>')" accesskey="r" />
            </p>
            <p class="autoclear"></p>
          </form>
        </div>
<?php
  }
} elseif (!empty($_GET['add']) && preg_match('/^L(\d+)\.(\d+)/', $_GET['add'], $matches)) {
  $sql = sql_connect($config['db']);
  if (!empty($_POST['uniprime']) && ($_POST['uniprime'] == md5('add')) && !empty($_POST['program']) && !empty($_POST['alignment']) && !empty($_POST['consensus']) && isset($_POST['sequences'][2])) {
      $entry['sequences'] = $_POST['sequences'];
      $entry['alignment'] = preg_replace('/&amp;(#x?[0-9a-f]+);/', '&\1', htmlentities(html_entity_decode($_POST['alignment']), ENT_QUOTES, 'ISO8859-1'));
      $entry['consensus'] = preg_replace('/[^\w]/', '', strtoupper($_POST['consensus']));
      $entry['program'] = preg_replace('/[^\d\w\.\-\_\ ]/', '', $_POST['program']);
      if (!empty($_POST['comments'])) {
        $entry['comments'] = ucfirst(preg_replace('/&amp;(#x?[0-9a-f]+);/', '&\1', htmlentities(html_entity_decode($_POST['comments']), ENT_QUOTES, 'ISO8859-1')));
      }
      $prefix = floor(((intval(date('Y', time())) - 2007) * 12 + intval(date('m', time())) - 1) / 1.5);
      $result = sql_query('INSERT INTO alignment (prefix, id, locus_prefix, locus_id, sequences, alignment, consensus, program, comments, author) SELECT ' . $prefix . ', CASE WHEN max(id)>=1 THEN max(id)+1 ELSE 1 END,' . octdec($matches[1]) . ',' . octdec($matches[2]) . ',\'' . implode(' ', $entry['sequences']) . '\',\'' . addslashes(base64_encode(bzcompress($entry['alignment']))) . '\',\'' . addslashes(base64_encode(bzcompress($entry['consensus']))) . '\',\'' . addslashes($entry['program']) . '\',' . (isset($entry['comments'])?('\'' . addslashes($entry['comments']) . '\''):'NULL') . ',\'UniPrime Web\' FROM alignment WHERE prefix=' . $prefix . ';', $sql);
      if (!strlen($r = sql_last_error($sql))) {
        header('Location: ' . $config['server'] . '/locus/' . $locus);
        exit(0);
      }else {
        $msg = _("Entry invalid, check your data");
      }
    }
    head('locus');
?>
        <div id="main">
          <h2><?php print _("New Alignment for the Locus") . ' ' . $matches[0]; ?></h2>
<?php if (!empty($msg)) { print "          <p><strong>$msg</strong></p>\n"; } ?>
          <form method="post" action="<?php print $config['server'] . '/alignment/add/'.$matches[0]; ?>" id="form">
            <div class="autoclear"><label for="program"><strong><?php print _("Program used"); ?></strong></label> <input type="text" name="program" id="program" maxlength="100" title="<?php print _("Program and version used"); ?>" <?php print (!empty($_POST['program'])?' value="' . $_POST['program'] . '" ':''); ?>/><br /></div>
<?php
    $result = sql_query('SELECT a.prefix, a.id, a.name, a.organism, b.sequence_type FROM sequence AS a, sequence_type AS b WHERE a.sequence_type=b.id AND a.locus_prefix=' . octdec($matches[1]) . ' AND a.locus_id=' . octdec($matches[2]) . ' ORDER BY a.sequence_type, a.organism;', $sql);
    if ((!strlen($r = sql_last_error($sql))) && (sql_num_rows($result) > 0)) {
      print '            <div class="autoclear"><label for="sequences"><strong>' . _("Sequence used") . '</strong></label> <select name="sequences[]" id="sequences" title="' . _("Sequences used for the alignment") . '" multiple="multiple" class="multiple">';
      while ($row = sql_fetch_row($result)) {
        print '<option value="'.decoct($row[0]).'.'.decoct($row[1]).'"' . ((isset($_POST['sequences']) && (array_search(decoct($row[0]).'.'.decoct($row[1]), $_POST['sequences'],true) !== false))?' selected="selected"':'') . ">$row[2] ($row[3] - $row[4])</option>";
      }
      print "</select><br /></div>\n";
    }
?>
            <div class="autoclear"><label for="alignment"><strong><?php print _("Alignment"); ?></strong></label> <textarea name="alignment" id="alignment" cols="30" rows="6" title="<?php print _("Interleave ClustalW Alignment or Fasta Alignment"); ?>"><?php print (!empty($_POST['alignment'])?$_POST['alignment']:''); ?></textarea><br /></div>
            <div class="autoclear"><label for="consensus"><strong><?php print _("Consensus"); ?></strong></label> <textarea name="consensus" id="consensus" cols="30" rows="3" title="<?php print _("Consensus sequence (raw sequence only)"); ?>"><?php print (!empty($_POST['consensus'])?$_POST['consensus']:''); ?></textarea><br /></div>
            <div class="autoclear"><label for="comments"><?php print _("Comments"); ?></label> <textarea name="comments" id="comments" cols="30" rows="3" title="<?php print _("Primer pair comments"); ?>"><?php print (!empty($_POST['comments'])?$_POST['comments']:''); ?></textarea><br /></div>
            <p class="autoclear">
              <input type="hidden" name="uniprime" value="<?php print md5('add'); ?>" />
              <input type="reset" value="<?php print _("Clear"); ?>" accesskey="c" />&nbsp;<input type="submit" value="<?php print _("Add"); ?>" accesskey="a" />
            </p>
            <p class="autoclear"></p>
          </form>
        </div>
        <div id="side">
          <h2><?php print _("Locus"); ?></h2>
          <a href="<?php print $config['server'] . '/locus/' . $matches[0] . '" title="' . _("Back...") . '" class="go">' . _("Back"); ?></a>
          <a href="<?php print $config['server'] . '/sequence/add/' . $matches[0] . '" title="' . _("Add a new sequence") . '" class="go">' . _("New sequence"); ?></a>
          <a href="<?php print $config['server'] . '/alignment/add/' . $matches[0] . '" title="' . _("Add a new aligment") . '" class="go">' . _("New alignment"); ?></a>
        </div>
<?php
}elseif (isset($_GET['alignment']) && preg_match('/^A(\d+)\.(\d+)/', $_GET['alignment'], $matches)) {
  head($matches[0]);
  $sql = sql_connect($config['db']);
  $result = sql_query('SELECT a.prefix, a.id, a.locus_prefix, a.locus_id, b.name, b.functions, a.sequences, a.program, a.comments, a.updated FROM alignment AS a, locus AS b WHERE a.prefix=' . octdec($matches[1]) . ' AND a.id=' . octdec($matches[2]) . ' AND b.prefix=a.locus_prefix AND b.id=a.locus_id;', $sql);
  if ((!strlen($r = sql_last_error($sql))) && (sql_num_rows($result) == 1)) {
    $row = sql_fetch_row($result);
?>
        <div id="main">
          <h2><?php print $row[4].' - '.date(_("m/d/Y"),strtotime($row[9])); ?></h2>
<?php
      print '          <h3>' . ("Locus") . "</h3>\n          <p>\n";
      print '            <span class="title">' . _("Name") . '</span> <span class="desc"><a href="' . $config['server'] . '/locus/L' . decoct($row[2]) . '.' . decoct($row[3]) . '">' . $row[4] . "</a></span><br />\n";
      if (!empty($row[5])) {
        print '            <span class="title">' . _("Functions") . '</span> <span class="desc">' . $row[5] . "</span><br />\n";
      }
      print "          </p>\n          <h3>" . _("Alignment") . "</h3>\n          <p>\n";
      print '            <span class="title">' . _("ID") . '</span> <span class="desc">A' . decoct($row[0]) . '.' . decoct($row[1]) . "</span><br />\n";
      print '            <span class="title">' .  _("Name") . '</span> <span class="desc">' . $row[4].' - '.date(_("m/d/Y"),strtotime($row[9])) . "</span><br />\n";


      if (!empty($row[7])) {
        print '            <span class="title">' . _("Program") . '</span> <span class="desc">' . $row[7] . "</span><br />\n";
      }
      print '            <span class="title">' . _("Release") . '</span> <span class="desc">' . date(_("m/d/Y"), strtotime($row[9])) . "</span><br />\n";
      print '            <span class="title">' . _("Alignment") . '</span> <span class="desc"><a href="#" onclick="window.open(\'' . $config['server'] . '/alignment/dna/' . $matches[0] . '\', \'' . _("Alignment") . '\', \'toolbar=no, location=no, directories=no, status=no, scrollbars=yes, resizable=yes, copyhistory=no, width=450, height=400, left=300, top=50\');return false;" title="' . _("Extract Alignment") . '">' . _("See Alignment") . "</a></span><br />\n";
      print '            <span class="title">' . _("Consensus") . '</span> <span class="desc"><a href="#" onclick="window.open(\'' . $config['server'] . '/consensus/dna/' . $matches[0] . '\', \'' . _("Consensus") . '\', \'toolbar=no, location=no, directories=no, status=no, scrollbars=yes, resizable=yes, copyhistory=no, width=450, height=400, left=300, top=50\');return false;" title="' . _("Extract Consensus sequence") . '">' . _("See Consensus sequence") . "</a></span><br />\n";
      if (!empty($row[8])) {
        print "          </p>\n            <h3>" . _("Comments") . "</h3>\n          <p>\n" . '            ' . $row[8] . "\n";
      }
      print "          </p>\n          <h3>" . _("Sequences") . "</h3>\n          <ul class=\"result sequence\">\n";
      foreach(explode(' ', $row[6]) as $seqs) {
        if (preg_match('/^(\d+)\.(\d+)/', $seqs, $seq)) {
          $result = sql_query('SELECT DISTINCT a.prefix, a.id, a.name, a.map, a.accession, a.organism, a.sequence_type, a.updated, a.organelle FROM sequence AS a, sequence_type AS b WHERE b.lang=\'' . get_pref('language') . '\' AND a.sequence_type=b.id AND a.prefix=' . octdec($seq[1]) . ' AND a.id=' . octdec($seq[2]) . ';', $sql);
          if ((!strlen($r = sql_last_error($sql))) && (sql_num_rows($result) > 0)) {
            while ($row2 = sql_fetch_row($result)) {
              $desc = '<em>' . ucfirst($row2[5]) . '</em>' . (isset($row2[3])?' - ' . $row2[3]:'') . (!empty($row2[4])?' (' . $row2[4] . ')':'') . (isset($row2[8])?' [' . $row2[8] . ']':'');
              print '              <li><a href="' . $config['server'] . '/sequence/S' . decoct($row2[0]) . '.' . decoct($row2[1]) . '" title="S' . decoct($row2[0]) . '.' . decoct($row2[1]) . '" class="sequence"><span class="name">' . $row2[2] . '</span><span class="date">' . date(_("m/d/Y"), strtotime($row2[7])) . '</span><span class="description">' . ((strlen($desc) > 53)?(substr($desc, 0, 50) . '...'):$desc) . "</span></a></li>\n";
            }
          }
        }
      }
      print "          </ul>\n";
      $result = sql_query('SELECT prefix, id, left_name, right_name, location, updated FROM primer WHERE alignment_prefix=' . octdec($matches[1]) . ' AND alignment_id=' . octdec($matches[2]) . ' ORDER BY penality;', $sql);
      if ((!strlen($r = sql_last_error($sql))) && (sql_num_rows($result) > 0)) {
        $res=true;
        print "          <h3>" . _("Primers") . "</h3>\n          <ul class=\"result primer\">\n";
        $i = 1;
        while ($row2 = sql_fetch_row($result)) {
          print '              <li><a href="' . $config['server'] . '/primer/X' . decoct($row2[0]) . '.' . decoct($row2[1]) . '" title="X' . decoct($row2[0]) . '.' . decoct($row2[1]) . '" class="primer"><span class="name">X' . decoct($row2[0]) . '.' . decoct($row2[1]) . '</span><span class="date">' . date(_("m/d/Y"), strtotime($row2[5])) . '</span><span class="description">' . substr($row2[4], 0, strpos($row2[4], '(')) . '</span><span class="type">' . ((isset($row2[2]) && isset($row2[3]))?($row2[2] . ' / ' . $row2[3]):'') . "</span></a></li>\n";
        }
        print "          </ul>\n";
      }

?>
        </div>
        <div id="side">
          <h2><?php print _("Alignment"); ?></h2>
          <a href="<?php print $config['server'] . '/alignment/edit/' . $matches[0] . '" title="' . _("Edit") . '" class="go">' . _("Edit"); ?></a>
          <a href="<?php print $config['server'] . '/primer/add/' . $matches[0] . '" title="' . _("Add a new primer") . '" class="go">' . _("New primer"); ?></a>
        </div>
<?php
  }
}

foot();
?>