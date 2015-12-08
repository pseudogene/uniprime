<?php
ob_start("ob_gzhandler");
session_start();
require_once('includes/main.inc');

if (isset($_GET['edit']) && preg_match('/^R(\d+)\.(\d+)/', $_GET['edit'], $matches)) {
  $sql = sql_connect($config['db']);
  if (isset($_POST['remove']) && !empty($_POST['edit']) && ($_POST['edit'] == md5($matches[0]))) {
    $result = sql_query('DELETE FROM mrna WHERE prefix=' . octdec($matches[1]) . ' AND id=' . octdec($matches[2]) . ';', $sql);
    header('Location: ' . $config['server'] . '/');
    exit(0);
  } elseif (isset($_POST['update']) && !empty($_POST['edit']) && ($_POST['edit'] == md5($matches[0])) && !empty($_POST['mrna']) && isset($_POST['type']) && (intval($_POST['type']) > 0) ) {
    $entry['type'] = intval($_POST['type']);
    $entry['mrna'] = preg_replace('/[^\w]/', '', strtoupper($_POST['mrna']));
    if (!empty($_POST['location'])) {
      $entry['location'] = preg_replace('/[^\d\w\.,\(\)]/', '', $_POST['location']);
    }
    if (!empty($_POST['comments'])) {
      $entry['comments'] = ucfirst(preg_replace('/&amp;(#x?[0-9a-f]+);/', '&\1', htmlentities(html_entity_decode($_POST['comments']), ENT_QUOTES, 'ISO8859-1')));
    }
    $result=sql_query('UPDATE mrna SET mrna_type='.$entry['type'].', location='.(isset($entry['location'])?('\'' . addslashes($entry['location']) . '\''):'NULL').', mrna=\'' . addslashes(base64_encode(bzcompress($entry['mrna']))) . '\', comments='.(isset($entry['comments'])?'\''.addslashes($entry['comments']).'\'':'NULL').', author=\'UniPrime Web\', updated=NOW() WHERE prefix='.octdec($matches[1]).' AND id='.octdec($matches[2]).';',$sql);
    if (!strlen($r=sql_last_error($sql))) {
      header('Location: '.$config['server'].'/mrna/'.$matches[0]);
      exit(0);
    } else {
      $msg = _("Entry invalid, check your data");
    }
  }
  $result = sql_query('SELECT prefix, id, mrna_type, location, mrna, comments FROM mrna WHERE prefix=' . octdec($matches[1]) . ' AND id=' . octdec($matches[2]) . ';', $sql);
  if ((!strlen($r = sql_last_error($sql))) && (sql_num_rows($result) == 1)) {
    head($matches[0]);
    $row = sql_fetch_row($result);
?>
        <div id="main">
          <h2><?php print _("mRNA") . ' ' .$matches[0]; ?></h2>
<?php if (!empty($msg)) { print "          <p><strong>$msg</strong></p>\n"; } ?>
          <form method="post" action="<?php print $config['server'].'/mrna/edit/'.$matches[0]; ?>" id="form">
            <div class="autoclear"><label for="location"><?php print _("Coordinate"); ?></label> <input type="text" name="location" id="location" title="<?php print _("Full coordinates (GenBank style: complement(join(aa..bb,cc..dd))"); ?>" <?php print (!empty($_POST['location'])?' value="'.$_POST['location'].'" ':((!isset($_POST['location']) && !empty($row[3]))?' value="'.$row[3].'" ':'')); ?>/><br /></div>
            <div class="autoclear"><label for="type"><strong><?php print _("mRNA type"); ?></strong></label> <select name="type" id="type" title="<?php print _("mRNA sequence type"); ?>"><?php
      for ($i = 1; $i < 11 ; $i++) {
        print '<option value="' . $i . '"' . (((!empty($_POST['type']) && $_POST['type']==$i) || (!isset($_POST['type']) && !empty($row[2]) && $row[2]==$i))?' selected="selected"':'')  . '>' . _("Transcript") . ' ' . $i . '</option>';
      }
?></select><br /></div>
            <div class="autoclear"><label for="mrna"><strong><?php print _("Sequence"); ?></strong></label> <textarea name="mrna" id="mrna" cols="30" rows="3" title="<?php print _("mRNA sequence"); ?>"><?php print (!empty($_POST['mrna'])?$_POST['mrna']:((!isset($_POST['mrna']) && !empty($row[4]))?bzdecompress(base64_decode($row[4])):'')); ?></textarea><br /></div>
            <div class="autoclear"><label for="comments"><?php print _("Description"); ?></label> <textarea name="comments" id="comments" cols="30" rows="3" title="<?php print _("mRNA description"); ?>"><?php print (!empty($_POST['comments'])?$_POST['comments']:((!isset($_POST['comments']) && !empty($row[5]))?$row[5]:'')); ?></textarea><br /></div>
            <p class="autoclear">
              <input type="hidden" name="edit" value="<?php print md5($matches[0]); ?>" />
              <input type="reset" value="<?php print _("Clear"); ?>" accesskey="c" />&nbsp;<input type="submit" name="update" value="<?php print _("Update"); ?>" accesskey="u" />&nbsp;<input type="submit" name="remove" value="<?php print _("Remove"); ?>" onclick="return confirm('<?php print _("Are you sure you want to delete?"); ?>')" accesskey="r" />
            </p>
            <p class="autoclear"></p>
          </form>
        </div>
<?php
  }
} elseif (!empty($_GET['add']) && preg_match('/^S(\d+)\.(\d+)/', $_GET['add'], $matches)) {
  $sql = sql_connect($config['db']);
  if (!empty($_POST['uniprime']) && ($_POST['uniprime'] == md5('add')) && !empty($_POST['mrna']) && isset($_POST['type']) && (intval($_POST['type']) > 0) ) {
    $entry['type'] = intval($_POST['type']);
    $entry['mrna'] = preg_replace('/[^\w]/', '', strtoupper($_POST['mrna']));
    if (!empty($_POST['location'])) {
      $entry['location'] = preg_replace('/[^\d\w\.,\(\)]/', '', $_POST['location']);
    }
    if (!empty($_POST['comments'])) {
      $entry['comments'] = ucfirst(preg_replace('/&amp;(#x?[0-9a-f]+);/', '&\1', htmlentities(html_entity_decode($_POST['comments']), ENT_QUOTES, 'ISO8859-1')));
    }
    $result = sql_query('SELECT locus_prefix, locus_id FROM sequence WHERE prefix='.octdec($matches[1]).' AND id=' . octdec($matches[2]) . ';', $sql);
    if ((!strlen($r = sql_last_error($sql))) && (sql_num_rows($result) == 1)) {
        $row = sql_fetch_row($result);
        $prefix = floor(((intval(date('Y', time())) - 2007) * 12 + intval(date('m', time())) - 1) / 1.5);
        $result = sql_query('INSERT INTO mrna (prefix, id, locus_prefix, locus_id, sequence_prefix, sequence_id, mrna_type, location, mrna, comments, author) SELECT ' . $prefix . ', CASE WHEN max(id)>=1 THEN max(id)+1 ELSE 1 END, ' . $row[0] . ',' . $row[1] . ',' . octdec($matches[1]). ','. octdec($matches[2]) . ',' .$entry['type']. ',' . (isset($entry['location'])?('\'' . addslashes($entry['location']) . '\''):'NULL') . ',\'' . addslashes(base64_encode(bzcompress($entry['mrna']))) . '\',' . (isset($entry['comments'])?'\'' . addslashes($entry['comments']) . '\'':'NULL') . ',\'UniPrime Web\' FROM mrna WHERE prefix=' . $prefix . ';', $sql);
        if (!strlen($r = sql_last_error($sql))) {
          header('Location: ' . $config['server'] . '/sequence/' . $matches[0]);
          exit(0);
        }else {
          $msg = _("Entry invalid, check your data") ;
        }
    } else {
      $msg = _("Entry invalid, check your data");
    }
  }
  head('mRNA');
?>
        <div id="main">
          <h2><?php print _("New mRNA for the sequence") . ' ' . $matches[0]; ?></h2>
<?php if (!empty($msg)) { print "          <p><strong>$msg</strong></p>\n"; } ?>
          <form method="post" action="<?php print $config['server'].'/mrna/add/'.$matches[0]; ?>" id="form">
            <div class="autoclear"><label for="location"><?php print _("Coordinate"); ?></label> <input type="text" name="location" id="location" title="<?php print _("Full coordinates (GenBank style: complement(join(aa..bb,cc..dd))"); ?>" <?php print (!empty($_POST['location'])?' value="'.$_POST['location'].'" ':''); ?>/><br /></div>
            <div class="autoclear"><label for="type"><strong><?php print _("mRNA type"); ?></strong></label> <select name="type" id="type" title="<?php print _("mRNA sequence type"); ?>"><option value="1"><?php print _("single mRNA"); ?></option><?php
      for ($i = 1; $i < 11 ; $i++) {
        print '<option value="' . $i . '"' . ((!empty($_POST['type']) && ($_POST['type']==$i) && ($i>1))?' selected="selected"':'')  . '>' . _("Transcript") . ' ' . $i . '</option>';
      }
?></select><br /></div>
            <div class="autoclear"><label for="mrna"><strong><?php print _("Sequence"); ?></strong></label> <textarea name="mrna" id="mrna" cols="30" rows="3" title="<?php print _("mRNA sequence"); ?>"><?php print (!empty($_POST['mrna'])?$_POST['mrna']:''); ?></textarea><br /></div>
            <div class="autoclear"><label for="comments"><?php print _("Description"); ?></label> <textarea name="comments" id="comments" cols="30" rows="3" title="<?php print _("mRNA description"); ?>"><?php print (!empty($_POST['comments'])?$_POST['comments']:''); ?></textarea><br /></div>
            <p class="autoclear">
              <input type="hidden" name="uniprime" value="<?php print md5('add'); ?>" />
              <input type="reset" value="<?php print _("Clear"); ?>" accesskey="c" />&nbsp;<input type="submit" value="<?php print _("Add"); ?>" accesskey="a" />
            </p>
            <p class="autoclear"></p>
          </form>
        </div>
        <div id="side">
          <h2><?php print _("Sequence"); ?></h2>
          <a href="<?php print $config['server'] . '/sequence/' . $matches[0] . '" title="' . _("Back...") . '" class="go">' . _("Back"); ?></a>
          <a href="<?php print $config['server'] . '/mrna/add/' . $matches[0] . '" title="' . _("Add a new mRNA") . '" class="go">' . _("New mRNA"); ?></a>
        </div>
<?php
}elseif (isset($_GET['mrna']) && preg_match('/^R(\d+)\.(\d+)/', $_GET['mrna'], $matches)) {
  head($matches[0]);
  $sql = sql_connect($config['db']);
  $result = sql_query('SELECT a.prefix, a.id, a.locus_prefix, a.locus_id, b.name, b.functions, a.sequence_prefix, a.sequence_id, c.name, c.organism, a.mrna_type, a.location, a.updated, a.comments FROM mrna AS a, locus AS b, sequence AS c WHERE b.prefix=a.locus_prefix AND b.id=a.locus_id AND c.prefix=a.sequence_prefix AND c.id=a.sequence_id AND a.prefix=' . octdec($matches[1]) . ' AND a.id=' . octdec($matches[2]) . ';', $sql);
  if ((!strlen($r = sql_last_error($sql))) && (sql_num_rows($result) == 1)) {
    $row = sql_fetch_row($result);
?>
        <div id="main">
          <h2><?php print $row[4]; ?></h2>
<?php
      print '          <h3>' . ("Locus") . "</h3>\n          <p>\n";
      print '            <span class="title">' . _("Name") . '</span> <span class="desc"><a href="' . $config['server'] . '/locus/L' . decoct($row[2]) . '.' . decoct($row[3]) . '">' . $row[4] . "</a></span><br />\n";
      if (!empty($row[5])) {
        print '            <span class="title">' . _("Functions") . '</span> <span class="desc">' . $row[5] . "</span><br />\n";
      }
      print "          </p>\n          <h3>" . ("Sequence") . "</h3>\n          <p>\n";
      print '            <span class="title">' . _("Name") . '</span> <span class="desc"><a href="' . $config['server'] . '/sequence/S' . decoct($row[6]) . '.' . decoct($row[7]) . '">' . $row[8] . "</a></span><br />\n";
      print '            <span class="title">' . _("Organism") . '</span> <span class="desc">' . $row[9] . "</span><br />\n";
      print "          </p>\n          <h3>" . ("mRNA") . "</h3>\n          <p>\n";
      if (!empty($row[11])) {
        print '            <img src="' . $config['server'] . '/mrna/draw/' . $matches[0] . "\" alt=\"\" class=\"right\" />\n";
      }
      print '            <span class="title">' . _("ID") . '</span> <span class="desc">R' . decoct($row[0]) . '.' . decoct($row[1]) . "</span><br />\n";
      print '            <span class="title">' .  _("mRNA") . '</span> <span class="desc">' . _("Transcript") . ' ' . $row[10] . "</span><br />\n";
      print '            <span class="title">' . _("Release") . '</span> <span class="desc">' . date(_("m/d/Y"), strtotime($row[12])) . "</span><br />\n";
      if (!empty($row[11])) {
        print '            <span class="title">' . _("mRNA location") . '</span> <span class="desc">' . str_replace(',',', ',$row[11]) . "</span><br />\n";
      }
      print '            <span class="title">' . _("Sequence") . '</span> <span class="desc"><a href="#" onclick="window.open(\'' . $config['server'] . '/mrna/dna/' . $matches[0] . '\', \'' . _("Sequence") . '\', \'toolbar=no, location=no, directories=no, status=no, scrollbars=yes, resizable=yes, copyhistory=no, width=450, height=400, left=300, top=50\');return false;" title="' . _("Extract RNA sequence") . '">' . _("See sequence") . "</a></span><br />\n";

      if (!empty($row[13])) {
        print "          </p>\n            <h3>" . _("Comments") . "</h3>\n          <p>\n" . '            ' . $row[13] . "\n";
      }
?>
          </p>
        </div>
        <div id="side">
          <h2><?php print _("mRNA"); ?></h2>
          <a href="<?php print $config['server'] . '/mrna/edit/' . $matches[0] . '" title="' . _("Edit") . '" class="go">' . _("Edit"); ?></a>
        </div>
<?php
  }
}

foot();
?>