<?php
ob_start("ob_gzhandler");
session_start();
require_once('includes/main.inc');

if (!isset($_SESSION['language'])) @set_pref('language', 'en');

if (isset($_GET['edit']) && preg_match('/^S(\d+)\.(\d+)/', $_GET['edit'], $matches)) {
  $sql = sql_connect($config['db']);
  if (isset($_POST['remove']) && !empty($_POST['edit']) && ($_POST['edit'] == md5($matches[0]))) {
    $result = sql_query('DELETE FROM mrna WHERE sequence_prefix=' . octdec($matches[1]) . ' AND sequence_id=' . octdec($matches[2]) . ';', $sql);
    $result = sql_query('DELETE FROM sequence WHERE prefix=' . octdec($matches[1]) . ' AND id=' . octdec($matches[2]) . ';', $sql);
    header('Location: ' . $config['server'] . '/');
    exit;
  } elseif (isset($_POST['update']) && !empty($_POST['edit']) && ($_POST['edit'] == md5($matches[0])) && !empty($_POST['type']) && ( ( (intval($_POST['type'])>=3) && !empty($_POST['primer']) && preg_match('/X(\d+)\.(\d+)/', strtoupper($_POST['primer']), $entry['primer'])) || (intval($_POST['type'])<3) ) && !empty($_POST['name']) && !empty($_POST['sequence']) && !empty($_POST['topology']) && !empty($_POST['molecule']) && !empty($_POST['organism']) && isset($_POST['strand']) && (intval($_POST['strand'])!=0) ) {
    if ( (intval($_POST['type'])>=3) && !empty($_POST['primer']) && preg_match('/X(\d+)\.(\d+)/', strtoupper($_POST['primer']), $entry['primer'])) {
      $result = sql_query('SELECT prefix, id FROM primer WHERE prefix=' . octdec(intval($entry['primer'][1])) . ' AND id=' . octdec(intval($entry['primer'][2])) . ';', $sql);
      if ((strlen($r = sql_last_error($sql))) || (sql_num_rows($result) != 1)) $msg=_("Primer reference unknown!");
    }
    if (empty($msg)) {
      $entry['type']=intval($_POST['type']);
      if (!empty($_POST['primer'])) { $entry['primer']=preg_replace('/&amp;(#x?[0-9a-f]+);/', '&\1',htmlentities(html_entity_decode($_POST['primer']),ENT_QUOTES,'ISO8859-1')); }
      if (!empty($_POST['evalue'])) { $entry['evalue']=floatval($_POST['evalue']); }
      if (!empty($_POST['isolate'])) { $entry['isolate']=preg_replace('/[^\d\w\.\-\_\ ]/','',$_POST['isolate']); }
      if (!empty($_POST['map'])) $entry['map']=preg_replace('/[^\d\w\.\-\_\ ]/','',$_POST['map']);
      $entry['sequence']=preg_replace('/[^\w]/','',strtoupper($_POST['sequence']));
      if (!empty($_POST['seq_map'])) {
        foreach (explode("\n",$_POST['seq_map']) as $ligne) {
          $char=explode('|',$ligne,4);
          if ( (isset($char[0]) && (intval($char[0])>0)) && (isset($char[1]) && (intval($char[1])>intval($char[0]))) && (isset($char[2]) && ((trim($char[2])=='P') || (trim($char[2])=='V') || (trim($char[2])=='S'))) && (!empty($char[3])) ) {
            $ret[]=intval($char[0]).'|'.intval($char[1]).'|'.trim($char[2]).'|'.ucfirst(preg_replace('/&amp;(#x?[0-9a-f]+);/', '&\1',htmlentities(html_entity_decode($char[3]),ENT_QUOTES,'ISO8859-1')));
          }
        }
        if (isset($ret)) $entry['structure']=join("\n",$ret);
      }
      if (!empty($_POST['seq_comments'])) { $entry['comments']=ucfirst(preg_replace('/&amp;(#x?[0-9a-f]+);/', '&\1',htmlentities(html_entity_decode($_POST['seq_comments']),ENT_QUOTES,'ISO8859-1'))); }
      if (!empty($_POST['seq_references'])) { $entry['references']=preg_replace('/&amp;(#x?[0-9a-f]+);/', '&\1',htmlentities(html_entity_decode($_POST['seq_references']),ENT_QUOTES,'ISO8859-1')); }
      if (!empty($_POST['accession']) && isset($_POST['start']) && isset($_POST['end'])) {
        $entry['accession']=preg_replace('/[^\d\w\.]/','',strtoupper($_POST['accession']));
        if (intval($_POST['start'])>intval($_POST['end'])) {
          $entry['end']=intval($_POST['start']);
          $entry['start']=intval($_POST['end']);
        } else {
          $entry['start']=intval($_POST['start']);
          $entry['end']=intval($_POST['end']);
        }
      } else {
        $entry['start']=1;
        $entry['end']=strlen($entry['sequence']);
      }
      if (!empty($_POST['alias'])) { $entry['alias']=preg_replace('/&amp;(#x?[0-9a-f]+);/', '&\1',htmlentities(html_entity_decode($_POST['alias']),ENT_QUOTES,'ISO8859-1')); }
      $entry['name']=preg_replace('/&amp;(#x?[0-9a-f]+);/', '&\1',htmlentities(html_entity_decode($_POST['name']),ENT_QUOTES,'ISO8859-1'));
      if (!empty($_POST['location'])) { $entry['location']=preg_replace('/[^\d\w\.\-\_\(\)]/','',$_POST['location']); }
      $entry['strand']=intval($_POST['strand']);
      if (!empty($_POST['chromosome'])) { $entry['chromosome']=preg_replace('/[^\d\w\.\-\_]/','',$_POST['chromosome']); }
      $entry['circular']=(($_POST['topology']=='t')?'t':'f');
      $entry['molecule']=preg_replace('/[^\w]/','',$_POST['molecule']);
      $entry['organism']=preg_replace('/[^\d\w\.\-\ ]/','',$_POST['organism']);
      if (!empty($_POST['organelle'])) { $entry['organelle']=preg_replace('/[^\d\w\.\-\_\ ]/','',$_POST['organelle']); }
      $entry['translation']=intval($_POST['translation']);
      $result=sql_query('UPDATE sequence SET name=\''.addslashes($entry['name']).'\', alias='.(isset($entry['locus']['alias'])?'\''.addslashes($entry['alias']).'\'':'NULL').', location='.(isset($entry['location'])?'\''.addslashes($entry['location']).'\'':'NULL').', isolate='.(isset($entry['isolate'])?'\''.addslashes($entry['isolate']).'\'':'NULL').', organelle='.(isset($entry['organelle'])?'\''.addslashes($entry['organelle']).'\'':'NULL').', translation='.$entry['translation'].', molecule=\''.addslashes($entry['molecule']).'\', circular=\''.$entry['circular'].'\', chromosome='.(isset($entry['chromosome'])?'\''.addslashes($entry['chromosome']).'\'':'NULL').', map='.(isset($entry['map'])?'\''.addslashes($entry['map']).'\'':'NULL').', accession='.(isset($entry['accession'])?'\''.addslashes($entry['accession']).'\'':'NULL').', organism=\''.addslashes($entry['organism']).'\', sequence_type='.$entry['type'].', stop='.$entry['end'].', start='.$entry['start'].', strand='.$entry['strand'].', sequence=\''.base64_encode(bzcompress($entry['sequence'])).'\', evalue='.(isset($entry['evalue'])?$entry['evalue']:'NULL').', sources='.(isset($entry['references'])?'\''.addslashes($entry['references']).'\'':'NULL').', comments='.(isset($entry['comments'])?'\''.addslashes($entry['comments']).'\'':'NULL').', structure='.(isset($entry['structure'])?'\''.addslashes($entry['structure']).'\'':'NULL').', '.(isset($entry['primer'])?'primer_prefix='.octdec($entry['primer'][1]).', primer_id='.octdec($entry['primer'][2]):'primer_prefix=NULL, primer_id=NULL') .', author=\'UniPrime Web\', updated=NOW() WHERE prefix='.octdec($matches[1]).' AND id='.octdec($matches[2]).';',$sql);
      if (!strlen($r=sql_last_error($sql))) {
        header('Location: '.$config['server'].'/sequence/'.$matches[0]);
        exit(0);
      } else {
        $msg = _("Entry invalid, check your data");
      }
    }
  }
  $result = sql_query('SELECT prefix, id, name, alias, location, translation, molecule, circular, chromosome, isolate, organelle, map, accession, hgnc, geneid, organism, go, sequence_type, primer_prefix, primer_id, sources, comments, evalue, start, stop, sequence, features, strand FROM sequence WHERE prefix=' . octdec($matches[1]) . ' AND id=' . octdec($matches[2]) . ';', $sql);
  if ((!strlen($r = sql_last_error($sql))) && (sql_num_rows($result) == 1)) {
    head($matches[0],false,true);
    $row = sql_fetch_row($result);
?>
        <div id="main">
          <h2><?php print $row[2]; ?></h2>
<?php if (!empty($msg)) { print "          <p><strong>$msg</strong></p>\n"; } ?>
          <form method="post" action="<?php print $config['server'].'/sequence/edit/'.$matches[0]; ?>" id="form">
            <div class="autoclear"><label for="name"><strong><?php print _("Sequence name"); ?></strong></label> <input type="text" name="name" id="name" maxlength="100" title="<?php print _("Sequence name"); ?>" <?php print (!empty($_POST['name'])?' value="'.$_POST['name'].'" ':((!isset($_POST['name']) && !empty($row[2]))?' value="'.$row[2].'" ':'')); ?>/><br /></div>
            <div class="autoclear"><label for="alias"><?php print _("Alias"); ?></label> <input type="text" name="alias" id="alias" maxlength="100" title="<?php print _("Locus alias"); ?>" <?php print (!empty($_POST['alias'])?' value="'.$_POST['alias'].'" ':((!isset($_POST['alias']) && !empty($row[3]))?' value="'.$row[3].'" ':'')); ?>/><br /></div>
<?php
  $result=sql_query('SELECT id,sequence_type FROM sequence_type WHERE lang=\'' . get_pref('language') . '\' ORDER BY id;',$sql);
  if (sql_num_rows($result)!=0) {
    print '            <div class="autoclear"><label for="type"><strong>'. _("Sequence type").'</strong></label> <select name="type" id="type" title="'. _("Sequence type").'">';
    while($row2=sql_fetch_row($result)) {
      print "<option value=\"$row2[0]\"".(((!empty($_POST['type']) && $_POST['type']==$row2[0]) || (!isset($_POST['type']) && !empty($row[17]) && $row[17]==$row2[0]))?' selected="selected"':'')."\">$row2[1]</option>";
    }
    print "</select><br /></div>\n";
  }
?>
            <div class="autoclear"><label for="accession"><?php print _("Accession"); ?></label> <input type="text" name="accession" id="accession" maxlength="50" title="<?php print _("Genbank accession number"); ?>" <?php print (!empty($_POST['reference'])?' value="'.$_POST['reference'].'" ':((!isset($_POST['reference']) && !empty($row[12]))?' value="'.$row[12].'" ':'')); ?>/><br /></div>
            <div class="autoclear"><label for="start"><?php print _("Start"); ?></label> <input type="text" name="start" id="start" maxlength="20" title="<?php print _("Start position of the sequence"); ?>" <?php print (!empty($_POST['start'])?' value="'.$_POST['start'].'" ':((!isset($_POST['start']) && !empty($row[23]))?' value="'.$row[23].'" ':'')); ?>/><br /></div>
            <div class="autoclear"><label for="end"><?php print _("End"); ?></label> <input type="text" name="end" id="end" maxlength="20" title="<?php print _("End position of the sequence"); ?>" <?php print (!empty($_POST['end'])?' value="'.$_POST['end'].'" ':((!isset($_POST['end']) && !empty($row[24]))?' value="'.$row[24].'" ':'')); ?>/><br /></div>
            <div class="autoclear"><label for="evalue"><?php print _("E-value"); ?></label> <input type="text" name="evalue" id="evalue" maxlength="50" title="<?php print _("E-value"); ?>" <?php print (isset($_POST['evalue'])?' value="'.$_POST['evalue'].'" ':((!isset($_POST['evalue']) && isset($row[22]))?' value="'.$row[22].'" ':'')); ?>/><br /></div>
            <div class="autoclear"><label for="primer"><?php print _("Primer Set"); ?></label> <input type="text" name="primer" id="primer" maxlength="100" title="<?php print _("Primer set used"); ?>" <?php print ( !empty($_POST['primer'])?' value="'.$_POST['primer'].'" ':((!isset($_POST['primer']) && isset($row[18]))?' value="X'.decoct($row[18]).'.'.decoct($row[19]).'" ':'')); ?>/><br /></div>
            <div class="autoclear"><label for="location"><?php print _("Location"); ?></label> <input type="text" name="location" id="location" title="<?php print _("Sequence location"); ?>" <?php print (!empty($_POST['location'])?' value="'.$_POST['location'].'" ':((!isset($_POST['location']) && !empty($row[4]))?' value="'.$row[4].'" ':'')); ?>/><br /></div>
            <div class="autoclear"><label for="strand"><strong><?php print _("Strand"); ?></strong></label> <select name="strand" id="strand" title="<?php print _("Strand"); ?>"><option value="1"<?php print (((!empty($_POST['strand']) && $_POST['strand']==1) || (!isset($_POST['strand']) && !empty($row[27]) && $row[27]==1))?' selected="selected"':''); ?>><?php print _("Direct"); ?></option><option value="-1"<?php print (((!empty($_POST['strand']) && $_POST['strand']==-1) || (!isset($_POST['strand']) && !empty($row[27]) && $row[27]==-1))?' selected="selected"':''); ?>><?php print _("Complementary"); ?></option></select><br /></div>
            <div class="autoclear"><label for="chromosome"><?php print _("Chromosome"); ?></label> <input type="text" name="chromosome" id="chromosome" maxlength="50" title="<?php print _("Chromosome name"); ?>" <?php print (!empty($_POST['chromosome'])?' value="'.$_POST['chromosome'].'" ':((!isset($_POST['chromosome']) && !empty($row[8]))?' value="'.$row[8].'" ':'')); ?>/><br /></div>
            <div class="autoclear"><label for="topology"><strong><?php print _("Topology"); ?></strong></label> <select name="topology" id="topology" title="<?php print _("Molecule topology"); ?>"><option value="f"<?php print (((!empty($_POST['topology']) && $_POST['topology']=='f') || (!isset($_POST['topology']) && !empty($row[7]) && $row[7]=='f'))?' selected="selected"':''); ?>><?php print _("Linear"); ?></option><option value="t"<?php print (((!empty($_POST['topology']) && $_POST['topology']=='t') || (!isset($_POST['topology']) && !empty($row[7]) && $row[7]=='t'))?' selected="selected"':''); ?>><?php print _("Circular"); ?></option></select><br /></div>
<?php
      $result=sql_query('SELECT id,molecule FROM molecule;',$sql);
      if ((!strlen($r=sql_last_error($sql))) && (sql_num_rows($result)!=0)) {
        print '            <div class="autoclear"><label for="molecule"><strong>'. _("Molecule").'</strong></label> <select name="molecule" id="molecule" title="'. _("Molecule type").'">';
        while($row2=sql_fetch_row($result)) {
          print "<option value=\"$row2[0]\"".(((!empty($_POST['molecule']) && $_POST['molecule']==$row2[0]) || (!isset($_POST['molecule']) && !empty($row[6]) && $row[6]==$row2[0]))?' selected="selected"':'').">$row2[1]</option>";
        }
        print "</select><br /></div>\n";
      }
      $result=sql_query('SELECT id,translation FROM translation;',$sql);
      if ((!strlen($r=sql_last_error($sql))) && (sql_num_rows($result)!=0)) {
        print '            <div class="autoclear"><label for="translation">'. _("Genetic table").'</label> <select name="translation" id="translation" title="'. _("Genetic table (if relevant)").'">';
        while($row2=sql_fetch_row($result)) {
          print "<option value=\"$row2[0]\"".(((!empty($_POST['translation']) && $_POST['translation']==$row2[0]) || (!isset($_POST['translation']) && !empty($row[5]) && $row[5]==$row2[0]))?' selected="selected"':'').">$row2[1]</option>";
        }
        print "</select><br /></div>\n";
      }
?>          <div class="autoclear"><label for="organism"><strong><?php print _("Organism"); ?></strong></label> <input type="text" name="organism" id="organism" maxlength="100" title="<?php print _("Organism name"); ?>" <?php print (!empty($_POST['organism'])?' value="'.$_POST['organism'].'" ':((!isset($_POST['organism']) && !empty($row[15]))?' value="'.$row[15].'" ':'')); ?>/><br /></div>
            <div class="autoclear"><label for="organelle"><?php print _("Organelle"); ?></label> <input type="text" name="organelle" id="organelle" maxlength="50" title="<?php print _("Organelle"); ?>" <?php print (!empty($_POST['organelle'])?' value="'.$_POST['organelle'].'" ':((!isset($_POST['organelle']) && !empty($row[10]))?' value="'.$row[10].'" ':'')); ?>/><br /></div>
            <div class="autoclear"><label for="map"><?php print _("Map"); ?></label> <input type="text" name="map" id="map" maxlength="100" title="<?php print _("Gene mapping"); ?>" <?php print (!empty($_POST['map'])?' value="'.$_POST['map'].'" ':((!isset($_POST['map']) && !empty($row[11]))?' value="'.$row[11].'" ':'')); ?>/><br /></div>
            <div class="autoclear"><label for="isolate"><?php print _("Isolate"); ?></label> <input type="text" name="isolate" id="isolate" maxlength="100" title="<?php print _("Isolate name"); ?>" <?php print (!empty($_POST['isolate'])?' value="'.$_POST['isolate'].'" ':((!isset($_POST['isolate']) && !empty($row[9]))?' value="'.$row[9].'" ':'')); ?>/><br /></div>
            <div class="autoclear"><label for="sequence"><strong><?php print _("Sequence"); ?></strong></label> <textarea name="sequence" id="sequence" cols="30" rows="3" title="<?php print _("Sequence description"); ?>"><?php print (!empty($_POST['sequence'])?$_POST['sequence']:((!isset($_POST['sequence']) && !empty($row[25]))?bzdecompress(base64_decode($row[25])):'')); ?></textarea><br /></div>
            <div class="autoclear"><label for="seq_map"><?php print _("Structure"); ?></label> <textarea name="seq_map" id="seq_map" cols="30" rows="3" title="<?php print _("Sequence structure (see help)"); ?>"><?php print (!empty($_POST['seq_map'])?$_POST['seq_map']:((!isset($_POST['seq_map']) && !empty($row[26]))?$row[26]:'')) . '</textarea>&nbsp;[<a href="#" onclick="window.open(\'' . $config['server'] . '/help/structure\', \'' . _("help") . '\', \'toolbar=no, location=no, directories=no, status=no, scrollbars=yes, resizable=yes, copyhistory=no, width=450, height=400, left=300, top=50\');return false;" title="' . _("help") . '">' . _("help"); ?></a>]<br /></div>
            <div class="autoclear"><label for="seq_comments"><?php print _("Description"); ?></label> <textarea name="seq_comments" id="seq_comments" cols="30" rows="3" title="<?php print _("Sequence description"); ?>"><?php print (!empty($_POST['seq_comments'])?$_POST['seq_comments']:((!isset($_POST['seq_comments']) && !empty($row[21]))?$row[21]:'')); ?></textarea><br /></div>
            <div class="autoclear"><label for="seq_references"><?php print _("References"); ?></label> <textarea name="seq_references" id="seq_references" cols="30" rows="3" title="<?php print _("References (wiki style [ full_url | name ])"); ?>"><?php print (!empty($_POST['seq_references'])?$_POST['seq_references']:((!isset($_POST['seq_references']) && !empty($row[20]))?$row[20]:'')); ?></textarea><br /></div>
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
  if (!empty($_POST['uniprime']) && ($_POST['uniprime'] == md5('add')) && !empty($_POST['type']) && (intval($_POST['type'])>0)) {
    $entry['type']=intval($_POST['type']);
    $entry['locus']['prefix']=octdec($matches[1]);
    $entry['locus']['id']=octdec($matches[2]);
    if (($entry['type']==1) && !empty($_POST['accession']) && isset($_POST['start']) && isset($_POST['end']) && (intval($_POST['start'])>0) && (intval($_POST['end'])>0)) {
      $entry['accession']=preg_replace('/[^\d\w\.]/','',strtoupper($_POST['accession']));
      if (!empty($_POST['isolate'])) { $entry['isolate']=preg_replace('/[^\d\w\.\-\_\ ]/','',$_POST['isolate']); }
      if (!empty($_POST['map'])) $entry['map']=preg_replace('/[^\d\w\.\-\_\ ]/','',$_POST['map']);
      if (intval($_POST['start'])>intval($_POST['end'])) {
        $entry['end']=intval($_POST['start']);
        $entry['start']=intval($_POST['end']);
      } else {
        $entry['start']=intval($_POST['start']);
        $entry['end']=intval($_POST['end']);
      }
      if (!empty($_POST['seq_comments'])) { $entry['comments']=ucfirst(preg_replace('/&amp;(#x?[0-9a-f]+);/', '&\1',htmlentities(html_entity_decode($_POST['seq_comments']),ENT_QUOTES,'ISO8859-1'))); }
      if (!empty($_POST['seq_references'])) { $entry['references']=preg_replace('/&amp;(#x?[0-9a-f]+);/', '&\1',htmlentities(html_entity_decode($_POST['seq_references']),ENT_QUOTES,'ISO8859-1')); }
      $msg = addSequence($entry,$sql);
      if (empty($msg)) {
        header('Location: '.$config['server'].'/locus/'.$matches[0]);
        exit(0);
      }
    } elseif (($entry['type']==2) && !empty($_POST['accession']) && isset($_POST['evalue']) && isset($_POST['start']) && isset($_POST['end']) && (floatval($_POST['evalue'])>=0) && (intval($_POST['start'])>0) && (intval($_POST['end'])>0)) {
        $entry['accession']=preg_replace('/[^\d\w\.]/','',strtoupper($_POST['accession']));
        if (!empty($_POST['isolate'])) { $entry['isolate']=preg_replace('/[^\d\w\.\-\_\ ]/','',$_POST['isolate']); }
        if (!empty($_POST['map'])) $entry['map']=preg_replace('/[^\d\w\.\-\_\ ]/','',$_POST['map']);
        $entry['evalue']=floatval($_POST['evalue']);
        if (intval($_POST['start'])>intval($_POST['end'])) {
          $entry['end']=intval($_POST['start']);
          $entry['start']=intval($_POST['end']);
        } else {
          $entry['start']=intval($_POST['start']);
          $entry['end']=intval($_POST['end']);
        }
        if (!empty($_POST['seq_comments'])) { $entry['comments']=ucfirst(preg_replace('/&amp;(#x?[0-9a-f]+);/', '&\1',htmlentities(html_entity_decode($_POST['seq_comments']),ENT_QUOTES,'ISO8859-1'))); }
        if (!empty($_POST['seq_references'])) { $entry['references']=preg_replace('/&amp;(#x?[0-9a-f]+);/', '&\1',htmlentities(html_entity_decode($_POST['seq_references']),ENT_QUOTES,'ISO8859-1')); }
        $msg = addSequence($entry,$sql);
        if (empty($msg)) {
          header('Location: '.$config['server'].'/locus/'.$matches[0]);
          exit(0);
        }
    } elseif (($entry['type']>=3) && !empty($_POST['primer']) && preg_match('/X(\d+)\.(\d+)/', strtoupper($_POST['primer']), $entry['primer']) && ( ( !empty($_POST['accession']) && isset($_POST['start']) && isset($_POST['end']) && (intval($_POST['start'])>0) && (intval($_POST['end'])>0) ) || (!empty($_POST['name']) && !empty($_POST['sequence']) && !empty($_POST['topology']) && !empty($_POST['molecule']) && isset($_POST['strand']) && (intval($_POST['strand'])!=0) && !empty($_POST['organism']) ) ) ) {
      $result = sql_query('SELECT prefix, id FROM primer WHERE prefix=' . octdec(intval($entry['primer'][1])) . ' AND id=' . octdec(intval($entry['primer'][2])) . ';', $sql);
      if ((!strlen($r = sql_last_error($sql))) && (sql_num_rows($result) == 1)) {
        if (!empty($_POST['isolate'])) { $entry['isolate']=preg_replace('/[^\d\w\.\-\_\ ]/','',$_POST['isolate']); }
        if (!empty($_POST['seq_map'])) {
          foreach (explode("\n",$_POST['seq_map']) as $ligne) {
            $char=explode('|',$ligne,4);
            if ( (isset($char[0]) && (intval($char[0])>0)) && (isset($char[1]) && (intval($char[1])>intval($char[0]))) && (isset($char[2]) && ((trim($char[2])=='P') || (trim($char[2])=='V') || (trim($char[2])=='S'))) && (!empty($char[3])) ) {
              $ret[]=intval($char[0]).'|'.intval($char[1]).'|'.trim($char[2]).'|'.ucfirst(preg_replace('/&amp;(#x?[0-9a-f]+);/', '&\1',htmlentities(html_entity_decode($char[3]),ENT_QUOTES,'ISO8859-1')));
            }
          }
          if (isset($ret)) $entry['features']=join("\n",$ret);
        }
        if (!empty($_POST['map'])) $entry['map']=preg_replace('/[^\d\w\.\-\_\ ]/','',$_POST['map']);
        if (!empty($_POST['seq_comments'])) { $entry['comments']=ucfirst(preg_replace('/&amp;(#x?[0-9a-f]+);/', '&\1',htmlentities(html_entity_decode($_POST['seq_comments']),ENT_QUOTES,'ISO8859-1'))); }
        if (!empty($_POST['seq_references'])) { $entry['references']=preg_replace('/&amp;(#x?[0-9a-f]+);/', '&\1',htmlentities(html_entity_decode($_POST['seq_references']),ENT_QUOTES,'ISO8859-1')); }
        if (!empty($_POST['accession'])) {
          $entry['accession']=preg_replace('/[^\d\w\.]/','',strtoupper($_POST['accession']));
          if (intval($_POST['start'])>intval($_POST['end'])) {
            $entry['end']=intval($_POST['start']);
            $entry['start']=intval($_POST['end']);
          } else {
            $entry['start']=intval($_POST['start']);
            $entry['end']=intval($_POST['end']);
          }
          $msg = addSequence($entry,$sql);
          if (empty($msg)) {
            header('Location: '.$config['server'].'/locus/'.$matches[0]);
            exit(0);
          }
        } else {
          $prefix = floor(((intval(date('Y', time())) - 2007) * 12 + intval(date('m', time())) - 1) / 1.5);
          $entry['name']=preg_replace('/&amp;(#x?[0-9a-f]+);/', '&\1',htmlentities(html_entity_decode($_POST['name']),ENT_QUOTES,'ISO8859-1'));
          $entry['sequence']=preg_replace('/[^\w]/','',strtoupper($_POST['sequence']));
          if (!empty($_POST['alias'])) { $entry['alias']=preg_replace('/&amp;(#x?[0-9a-f]+);/', '&\1',htmlentities(html_entity_decode($_POST['alias']),ENT_QUOTES,'ISO8859-1')); }
          if (!empty($_POST['location'])) { $entry['location']=preg_replace('/[^\d\w\.\-\_\(\)]/','',$_POST['location']); }
          $entry['strand']=intval($_POST['strand']);
          if (!empty($_POST['chromosome'])) { $entry['chromosome']=preg_replace('/[^\d\w\.\-\_]/','',$_POST['chromosome']); }
          $entry['circular']=(($_POST['topology']=='t')?'t':'f');
          $entry['molecule']=$entry['organelle']=preg_replace('/[^\w]/','',$_POST['molecule']);
          $entry['organism']=preg_replace('/[^\d\w\.\-\ ]/','',$_POST['organism']);
          if (!empty($_POST['organelle'])) { $entry['organelle']=preg_replace('/[^\d\w\.\-\_\ ]/','',$_POST['organelle']); }
          $entry['translation']=( isset($_POST['translation']) ? intval($_POST['translation']) : 0 ) ;
          $result = sql_query('INSERT INTO sequence (prefix, id, locus_prefix, locus_id, name, alias, location, isolate, organelle, translation, molecule, circular, chromosome, map, organism, sequence_type, primer_prefix, primer_id, stop, start, strand, sequence, features, evalue, sources, comments, author) SELECT ' . $prefix . ', CASE WHEN max(id)>=1 THEN max(id)+1 ELSE 1 END, ' . $entry['locus']['prefix'] . ', ' . $entry['locus']['id'] . ', \'' . addslashes($entry['name']) . '\',' . (isset($entry['alias'])?'\'' . addslashes($entry['alias']) . '\'':'NULL') . ',' . (isset($entry['location'])?'\'' . addslashes($entry['location']) . '\'':'NULL') . ',' . (isset($entry['isolate'])?'\'' . addslashes($entry['isolate']) . '\'':'NULL') . ',' . (isset($entry['organelle'])?'\'' . addslashes($entry['organelle']) . '\'':'NULL') . ',' . $entry['translation'] . ',\'' . addslashes($entry['molecule']) . '\',\'' . $entry['circular'] . '\',' . (isset($entry['chromosome'])?'\'' . addslashes($entry['chromosome']) . '\'':'NULL') . ',' . (isset($entry['map'])?'\'' . addslashes($entry['map']) . '\'':'NULL') . ',\'' . $entry['organism'] . '\',' . $entry['type'] . ', ' . (isset($entry['primer'])?octdec($entry['primer'][1]).', '.octdec($entry['primer'][2]):'NULL, NULL') .',' . strlen($entry['sequence']) . ',1,' . $entry['strand'] . ',\'' . addslashes(base64_encode(bzcompress($entry['sequence']))) . '\',' . (isset($entry['features'])?'\'' . addslashes($entry['features']) . '\'':'NULL') . ', ' .(isset($entry['evalue'])?$entry['evalue']:'NULL') . ', ' . (isset($entry['references'])?'\''  . addslashes($entry['references']) . '\'':'NULL') . ',' . (isset($entry['comments'])?'\'' . addslashes($entry['comments']) . '\'':'NULL') . ',\'UniPrime Web\' FROM sequence WHERE prefix=' . $prefix . ';', $sql);
          if (!strlen($r=sql_last_error($sql))) {
            header('Location: '.$config['server'].'/locus/'.$matches[0]);
            exit(0);
          } else {
            $msg = _("Entry invalid, check your data");
          }
        }
      } else {
        $msg = _("Primer reference unknown!");
      }
    }
  }

  head('sequence', true, true);
?>
        <div id="main">
          <h2><?php print _("New sequence for the locus") . ' ' . $matches[0]; ?></h2>
<?php if (!empty($msg)) { print "          <p><strong>$msg</strong></p>\n"; } ?>
          <form method="post" action="<?php print $config['server'].'/sequence/add/'.$matches[0]; ?>" id="form">
<?php
  $result=sql_query('SELECT id,sequence_type FROM sequence_type WHERE lang=\'' . get_pref('language') . '\' ORDER BY id;',$sql);
  if (sql_num_rows($result)!=0) {
    print '            <div class="autoclear"><label for="type"><strong>'. _("Sequence type").'</strong></label> <select name="type" id="type" title="'. _("Sequence type").'" onchange="javascript:this.form.submit();">';
    while($row=sql_fetch_row($result)) {
      print "<option value=\"$row[0]\"".((isset($entry['type']) && $entry['type']==$row[0])?' selected="selected"':'').">$row[1]</option>";
    }
    print "</select><br /><br /></div>\n";
  }
  if (isset($entry['type']) && ($entry['type']==1)) {
?>
            <div class="autoclear"><label for="advanced"><?php print _("Advanced"); ?></label> <input type="checkbox" name="advanced" id="advanced" rel="advanced"<?php print (!empty($_POST['advanced'])?' checked="checked"':''); ?> /><br /></div>
            <div class="autoclear"><label for="accession"><strong><?php print _("Accession"); ?></strong></label> <input type="text" name="accession" id="accession" maxlength="50" title="<?php print _("Genbank accession number"); ?>" <?php print (!empty($_POST['accession'])?' value="'.$_POST['accession'].'" ':''); ?>/><br /></div>
            <div class="autoclear" rel="advanced"><label for="map"><?php print _("Map"); ?></label> <input type="text" name="map" id="map" maxlength="100" title="<?php print _("Gene mapping"); ?>" <?php print (!empty($_POST['map'])?' value="'.$_POST['map'].'" ':''); ?>/><br /></div>
            <div class="autoclear" rel="advanced"><label for="isolate"><?php print _("Isolate"); ?></label> <input type="text" name="isolate" id="isolate" maxlength="100" title="<?php print _("Isolate name"); ?>" <?php print (!empty($_POST['isolate'])?' value="'.$_POST['isolate'].'" ':''); ?>/><br /></div>
            <div class="autoclear"><label for="start"><strong><?php print _("Start"); ?></strong></label> <input type="text" name="start" id="start" maxlength="20" title="<?php print _("Start position of the sequence"); ?>" <?php print (!empty($_POST['start'])?' value="'.$_POST['start'].'" ':''); ?>/><br /></div>
            <div class="autoclear"><label for="end"><strong><?php print _("End"); ?></strong></label> <input type="text" name="end" id="end" maxlength="20" title="<?php print _("End position of the sequence"); ?>" <?php print (!empty($_POST['end'])?' value="'.$_POST['end'].'" ':''); ?>/><br /></div>
            <div class="autoclear" rel="advanced"><label for="seq_comments"><?php print _("Description"); ?></label> <textarea name="seq_comments" id="seq_comments" cols="30" rows="3" title="<?php print _("Sequence description"); ?>"><?php print (!empty($_POST['seq_comments'])?$_POST['seq_comments']:''); ?></textarea><br /></div>
            <div class="autoclear" rel="advanced"><label for="seq_references"><?php print _("References"); ?></label> <textarea name="seq_references" id="seq_references" cols="30" rows="3" title="<?php print _("References (wiki style [ full_url | name ])"); ?>"><?php print (!empty($_POST['seq_references'])?$_POST['seq_references']:''); ?></textarea><br /></div>
<?php
  } elseif (isset($entry['type']) && ($entry['type']==2)) {
?>
            <div class="autoclear"><label for="advanced"><?php print _("Advanced"); ?></label> <input type="checkbox" name="advanced" id="advanced" rel="advanced"<?php print (!empty($_POST['advanced'])?' checked="checked"':''); ?> /><br /></div>
            <div class="autoclear"><label for="accession"><strong><?php print _("Accession"); ?></strong></label> <input type="text" name="accession" id="accession" maxlength="50" title="<?php print _("Genbank accession number"); ?>" <?php print (!empty($_POST['accession'])?' value="'.$_POST['accession'].'" ':''); ?>/><br /></div>
            <div class="autoclear"><label for="evalue"><strong><?php print _("E-value"); ?></strong></label> <input type="text" name="evalue" id="evalue" maxlength="50" title="<?php print _("E-value"); ?>" <?php print (isset($_POST['evalue'])?' value="'.$_POST['evalue'].'" ':''); ?>/><br /></div>
            <div class="autoclear" rel="advanced"><label for="map"><?php print _("Map"); ?></label> <input type="text" name="map" id="map" maxlength="100" title="<?php print _("Gene mapping"); ?>" <?php print (!empty($_POST['map'])?' value="'.$_POST['map'].'" ':''); ?>/><br /></div>
            <div class="autoclear" rel="advanced"><label for="isolate"><?php print _("Isolate"); ?></label> <input type="text" name="isolate" id="isolate" maxlength="100" title="<?php print _("Isolate name"); ?>" <?php print (!empty($_POST['isolate'])?' value="'.$_POST['isolate'].'" ':''); ?>/><br /></div>
            <div class="autoclear"><label for="start"><strong><?php print _("Start"); ?></strong></label> <input type="text" name="start" id="start" maxlength="20" title="<?php print _("Start position of the sequence"); ?>" <?php print (!empty($_POST['start'])?' value="'.$_POST['start'].'" ':''); ?>/><br /></div>
            <div class="autoclear"><label for="end"><strong><?php print _("End"); ?></strong></label> <input type="text" name="end" id="end" maxlength="20" title="<?php print _("End position of the sequence"); ?>" <?php print (!empty($_POST['end'])?' value="'.$_POST['end'].'" ':''); ?>/><br /></div>
            <div class="autoclear" rel="advanced"><label for="seq_comments"><?php print _("Description"); ?></label> <textarea name="seq_comments" id="seq_comments" cols="30" rows="3" title="<?php print _("Sequence description"); ?>"><?php print (!empty($_POST['seq_comments'])?$_POST['seq_comments']:''); ?></textarea><br /></div>
            <div class="autoclear" rel="advanced"><label for="seq_references"><?php print _("References"); ?></label> <textarea name="seq_references" id="seq_references" cols="30" rows="3" title="<?php print _("References (wiki style [ full_url | name ])"); ?>"><?php print (!empty($_POST['seq_references'])?$_POST['seq_references']:''); ?></textarea><br /></div>
<?php
  } elseif (isset($entry['type']) && ($entry['type']>=3)) {
?>
            <div class="autoclear"><label for="advanced"><?php print _("Advanced"); ?></label> <input type="checkbox" name="advanced" id="advanced" rel="advanced"<?php print (!empty($_POST['advanced'])?' checked="checked"':''); ?> /><br /></div>
            <div class="autoclear"><label for="accession"><strong><?php print _("Accession"); ?></strong></label> <input type="text" name="accession" id="accession" maxlength="50" title="<?php print _("Genbank accession number"); ?>" <?php print (!empty($_POST['accession'])?' value="'.$_POST['accession'].'" ':''); ?>/><br /></div>
            <div class="autoclear"><label for="start"><strong><?php print _("Start"); ?></strong></label> <input type="text" name="start" id="start" maxlength="20" title="<?php print _("Start position of the sequence"); ?>" <?php print (!empty($_POST['start'])?' value="'.$_POST['start'].'" ':''); ?>/><br /></div>
            <div class="autoclear"><label for="end"><strong><?php print _("End"); ?></strong></label> <input type="text" name="end" id="end" maxlength="20" title="<?php print _("End position of the sequence"); ?>" <?php print (!empty($_POST['end'])?' value="'.$_POST['end'].'" ':''); ?>/><br /><br /></div>
            <p><strong><?php print _("or"); ?></strong></p>
            <div class="autoclear"><label for="name"><strong><?php print _("Name"); ?></strong></label> <input type="text" name="name" id="name" maxlength="100" title="<?php print _("Sequence name"); ?>" <?php print (!empty($_POST['name'])?' value="'.$_POST['name'].'" ':''); ?>/><br /></div>
            <div class="autoclear" rel="advanced"><label for="alias"><?php print _("Alias"); ?></label> <input type="text" name="alias" id="alias" maxlength="100" title="<?php print _("Sequence alias"); ?>" <?php print (!empty($_POST['alias'])?' value="'.$_POST['alias'].'" ':''); ?>/><br /></div>
            <div class="autoclear" rel="advanced"><label for="location"><?php print _("Location"); ?></label> <input type="text" name="location" id="location" title="<?php print _("Sequence location"); ?>" <?php print (!empty($_POST['location'])?' value="'.$_POST['location'].'" ':''); ?>/><br /></div>
            <div class="autoclear"><label for="strand"><strong><?php print _("Strand"); ?></strong></label> <select name="strand" id="strand" title="<?php print _("Strand"); ?>"><option value="1"<?php print ((!empty($_POST['strand']) && $_POST['strand']==1)?' selected="selected"':''); ?>><?php print _("Direct"); ?></option><option value="-1"<?php print ((!empty($_POST['strand']) && $_POST['strand']==-1)?' selected="selected"':''); ?>><?php print _("Complementary"); ?></option></select><br /></div>
            <div class="autoclear" rel="advanced"><label for="chromosome"><?php print _("Chromosome"); ?></label> <input type="text" name="chromosome" id="chromosome" maxlength="50" title="<?php print _("Chromosome name"); ?>" <?php print (!empty($_POST['chromosome'])?' value="'.$_POST['chromosome'].'" ':''); ?>/><br /></div>
            <div class="autoclear"><label for="topology"><strong><?php print _("Topology"); ?></strong></label> <select name="topology" id="topology" title="<?php print _("Molecule topology"); ?>"><option value="f"<?php print ((!empty($_POST['topology']) && $_POST['topology']=='f')?' selected="selected"':''); ?>><?php print _("Linear"); ?></option><option value="t"<?php print ((!empty($_POST['topology']) && $_POST['topology']=='t')?' selected="selected"':''); ?>><?php print _("Circular"); ?></option></select><br /></div>
<?php
      $result=sql_query('SELECT id,molecule FROM molecule;',$sql);
      if ((!strlen($r=sql_last_error($sql))) && (sql_num_rows($result)!=0)) {
        print '            <div class="autoclear"><label for="molecule"><strong>'. _("Molecule").'</strong></label> <select name="molecule" id="molecule" title="'. _("Molecule type").'">';
        while($row=sql_fetch_row($result)) {
          print "<option value=\"$row[0]\"".((!empty($_POST['molecule']) && $_POST['molecule']==$row[0])?' selected="selected"':'').">$row[1]</option>";
        }
        print "</select><br /></div>\n";
      }
?>
            <div class="autoclear"><label for="organism"><strong><?php print _("Organism"); ?></strong></label> <input type="text" name="organism" id="organism" maxlength="100" title="<?php print _("Organism name"); ?>" <?php print (!empty($_POST['organism'])?' value="'.$_POST['organism'].'" ':''); ?>/><br /></div>
            <div class="autoclear" rel="advanced"><label for="organelle"><?php print _("Organelle"); ?></label> <input type="text" name="organelle" id="organelle" maxlength="50" title="<?php print _("Organelle"); ?>" <?php print (!empty($_POST['organelle'])?' value="'.$_POST['organelle'].'" ':''); ?>/><br /></div>
<?php
      $result=sql_query('SELECT id,translation FROM translation;',$sql);
      if ((!strlen($r=sql_last_error($sql))) && (sql_num_rows($result)!=0)) {
        print '            <div class="autoclear" rel="advanced"><label for="translation">'. _("Genetic table").'</label> <select name="translation" id="translation" title="'. _("Genetic table (if relevant)").'">';
        while($row=sql_fetch_row($result)) {
          print "<option value=\"$row[0]\"".((isset($_POST['translation']) && $_POST['translation']==$row[0])?' selected="selected"':'').">$row[1]</option>";
        }
        print "</select><br /></div>\n";
      }
?>
            <div class="autoclear"><label for="sequence"><strong><?php print _("Sequence"); ?></strong></label> <textarea name="sequence" id="sequence" cols="30" rows="3" title="<?php print _("Sequence description"); ?>"><?php print (!empty($_POST['sequence'])?$_POST['sequence']:''); ?></textarea><br /><br /></div>
            <p><strong><?php print _("and"); ?></strong></p>
            <div class="autoclear"><label for="primer"><strong><?php print _("Primer Set"); ?></strong></label> <input type="text" name="primer" id="primer" maxlength="100" title="<?php print _("Primer set used"); ?>" <?php print (!empty($_POST['primer'])?' value="'.$_POST['primer'].'" ':''); ?>/><br /></div>
            <div class="autoclear" rel="advanced"><label for="map"><?php print _("Map"); ?></label> <input type="text" name="map" id="map" maxlength="100" title="<?php print _("Gene mapping"); ?>" <?php print (!empty($_POST['map'])?' value="'.$_POST['map'].'" ':''); ?>/><br /></div>
            <div class="autoclear" rel="advanced"><label for="isolate"><?php print _("Isolate"); ?></label> <input type="text" name="isolate" id="isolate" maxlength="100" title="<?php print _("Isolate name"); ?>" <?php print (!empty($_POST['isolate'])?' value="'.$_POST['isolate'].'" ':''); ?>/><br /></div>
            <div class="autoclear" rel="advanced"><label for="seq_map"><?php print _("Structure"); ?></label> <textarea name="seq_map" id="seq_map" cols="30" rows="3" title="<?php print _("Sequence structure (see help)"); ?>"><?php print (!empty($_POST['seq_map'])?$_POST['seq_map']:'') . '</textarea>&nbsp;[<a href="#" onclick="window.open(\'' . $config['server'] . '/help/structure\', \'' . _("help") . '\', \'toolbar=no, location=no, directories=no, status=no, scrollbars=yes, resizable=yes, copyhistory=no, width=450, height=400, left=300, top=50\');return false;" title="' . _("help") . '">' . _("help"); ?></a>]<br /></div>
            <div class="autoclear" rel="advanced"><label for="seq_comments"><?php print _("Description"); ?></label> <textarea name="seq_comments" id="seq_comments" cols="30" rows="3" title="<?php print _("Sequence description"); ?>"><?php print (!empty($_POST['seq_comments'])?$_POST['seq_comments']:''); ?></textarea><br /></div>
            <div class="autoclear"><label for="seq_references"><?php print _("References"); ?></label> <textarea name="seq_references" id="seq_references" cols="30" rows="3" title="<?php print _("References (wiki style [ full_url | name ])"); ?>"><?php print (!empty($_POST['seq_references'])?$_POST['seq_references']:''); ?></textarea><br /></div>
<?php
    }
?>
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
}elseif (isset($_GET['sequence']) && preg_match('/^S(\d+)\.(\d+)/', $_GET['sequence'], $matches)) {
  head($matches[0]);
  $sql = sql_connect($config['db']);
  $result = sql_query('SELECT a.prefix, a.id, a.locus_prefix, a.locus_id, a.name, a.alias, a.location, b.translation, c.molecule, a.circular, a.chromosome, a.isolate, a.organelle, a.map, a.accession, a.hgnc, a.geneid, a.organism, a.go, d.sequence_type, a.primer_prefix, a.primer_id, a.updated, a.sources, a.comments, a.evalue, a.start, a.stop, a.structure, e.name, e.functions FROM sequence AS a, translation AS b, molecule AS c, sequence_type AS d, locus AS e WHERE e.prefix=a.locus_prefix AND e.id=a.locus_id AND a.prefix=' . octdec($matches[1]) . ' AND a.id=' . octdec($matches[2]) . ' AND a.translation=b.id AND a.molecule=c.id AND a.sequence_type=d.id;', $sql);
  if ((!strlen($r = sql_last_error($sql))) && (sql_num_rows($result) == 1)) {
    $row = sql_fetch_row($result);
?>
        <div id="main">
          <h2><?php print $row[4]; ?></h2>
<?php
      print '          <h3>' . ("Locus") . "</h3>\n          <p>\n";
      print '            <span class="title">' . _("Name") . '</span> <span class="desc"><a href="' . $config['server'] . '/locus/L' . decoct($row[2]) . '.' . decoct($row[3]) . '">' . $row[29] . "</a></span><br />\n";
      if (!empty($row[30])) {
        print '            <span class="title">' . _("Functions") . '</span> <span class="desc">' . $row[30] . "</span><br />\n";
      }
      print "          </p>\n          <h3>" . ("Sequence") . "</h3>\n          <p>\n";
      if (!empty($row[28])) {
// ** fix me **
        print '            <img src="' . $config['server'] . '/sequence/draw/' . $matches[0] . "\" alt=\"\" class=\"right\" />\n";
      }
      print '            <span class="title">' . _("ID") . '</span> <span class="desc">S' . decoct($row[0]) . '.' . decoct($row[1]) . "</span><br />\n";
      print '            <span class="title">' .  _("Name") . '</span> <span class="desc">' . $row[4] . "</span><br />\n";
      if (!empty($row[5])) {
        print '            <span class="title">' . _("Alias") . '</span> <span class="desc">' . $row[5] . "</span><br />\n";
      }
      print '            <span class="title">' . _("Release") . '</span> <span class="desc">' . date(_("m/d/Y"), strtotime($row[22])) . "</span><br />\n";
      print '            <span class="title">' . _("Sequence type") . '</span> <span class="desc">' . $row[19] . "</span><br />\n";
      if (!empty($row[25])) {
        print '            <span class="title">' . _("E-value") . '</span> <span class="desc">' . $row[25] . "</span><br />\n";
      }
      if (!empty($row[14])) {
        print '            <span class="title">' . _("Accession") . '</span> <span class="desc"><a href="http://www.ncbi.nlm.nih.gov/entrez/viewer.fcgi?val=' . $row[14] . '&amp;from=' . $row[26] . '&amp;to=' . $row[27] . '&amp;dopt=gb">' . $row[14] . "</a></span><br />\n";
      }
      if (!empty($row[6])) {
        print '            <span class="title">' . _("Gene location") . '</span> <span class="desc">' . str_replace(',',', ',$row[6]) . "</span><br />\n";
      }
      if (!empty($row[13])) {
        print '            <span class="title">' . _("Map") . '</span> <span class="desc">' . $row[13] . "</span><br />\n";
      }
      if (!empty($row[15])) {
        print '            <span class="title"><acronym title="' . _("HUGO Gene Nomenclature Committee") . '">' . _("HGNC") . '</acronym></span> <span class="desc"><a href="http://www.gene.ucl.ac.uk/nomenclature/data/get_data.php?hgnc_id=' . $row[15] . '">' . $row[15] . "</a></span><br />\n";
      }
      if (!empty($row[16])) {
        print '            <span class="title"><acronym title="' . _("Genbank GeneID") . '">' . _("GeneID") . '</acronym></span> <span class="desc"><a href="http://www.ncbi.nlm.nih.gov/entrez/query.fcgi?db=gene&amp;cmd=Retrieve&amp;dopt=full_report&amp;list_uids=' . $row[16] . '">' . $row[16] . "</a></span><br />\n";
      }
      print '            <span class="title">' . _("Organism") . '</span> <span class="desc"><em>' . $row[17] . "</em></span><br />\n";
      if (!empty($row[11])) {
        print '            <span class="title">' . _("Isolate/population") . '</span> <span class="desc">' . $row[11] . "</span><br />\n";
      }
      if (!empty($row[10])) {
        print '            <span class="title">' . _("Chromosome") . '</span> <span class="desc">' . $row[10] . "</span><br />\n";
      }
      if (!empty($row[12])) {
        print '            <span class="title">' . _("Organelle") . '</span> <span class="desc">' . $row[12]  . "</span><br />\n";
      }
      print '            <span class="title">' . _("Molecule") . '</span> <span class="desc">' . $row[8] . "</span><br />\n";
      print '            <span class="title">' . _("Topology") . '</span> <span class="desc">' . (($row[9] == 't')?'circular':'linear') . "</span><br />\n";
      if ($row[7] > 0) {
        print '            <span class="title">' . _("Genetic code") . '</span> <span class="desc">' . $row[7] . "</span><br />\n";
      }
      if (!empty($row[18])) {
        print '            <span class="title"><acronym title="' . _("Gene Ontology terms") . '">' . _("GO") . '</acronym></span> <span class="desc">' . $row[18] . "</span><br />\n";
      }
      if (!empty($row[20])) {
        print '            <span class="title">' . _("Primer") . '</span> <span class="desc"><a href="' . $config['server'] . '/primer/X' . decoct($row[20]) . '.' . decoct($row[21]) . '">X' . decoct($row[20]) . '.' . decoct($row[21]) . "</a></span><br />\n";
      }
      print '            <span class="title">' . _("Sequence") . '</span> <span class="desc"><a href="#" onclick="window.open(\'' . $config['server'] . '/sequence/dna/' . $matches[0] . '\', \'' . _("Sequence") . '\', \'toolbar=no, location=no, directories=no, status=no, scrollbars=yes, resizable=yes, copyhistory=no, width=450, height=400, left=300, top=50\');return false;" title="' . _("Extract DNA sequence") . '">' . _("See sequence") . "</a></span><br />\n";

      if (!empty($row[24])) {
        print "          </p>\n            <h3>" . _("Comments") . "</h3>\n          <p>\n" . '            ' . $row[24] . "\n";
      }
      if (!empty($row[23])) {
        print "          </p>\n            <h3>" . _("References") . "</h3>\n          <p>\n" . '            ' . preg_replace('/\[([^\|\]]*)\]/','<a href="\1">\1</a><br />',preg_replace('/\[([^\|\]]*)\|([^\|\]]*)\]/','<a href="\1">\2</a><br />',$row[23])) . "\n";
      }
?>
          </p>
<?php
      // mRNA
      $result = sql_query('SELECT prefix, id, mrna_type, location FROM mrna WHERE sequence_prefix=' . octdec($matches[1]) . ' AND sequence_id=' . octdec($matches[2]) . ' ORDER BY mrna_type;', $sql);
      if ((!strlen($r = sql_last_error($sql))) && (sql_num_rows($result) > 0)) {
        print "          <h3>" . _("mRNA") . "</h3>\n          <ul class=\"result mrna\">\n";
        while ($row = sql_fetch_row($result)) {
          print '              <li><a href="' . $config['server'] . '/mrna/R' . decoct($row[0]) . '.' . decoct($row[1]) . '" title="R' . decoct($row[0]) . '.' . decoct($row[1]) . '" class="mrna"><span class="name">' . ((sql_num_rows($result) == 1)?'mRNA': _("Transcripts") . ' ' . $row[2]) . '</span><span class="date">R' . decoct($row[0]) . '.' . decoct($row[1]) . '</span><span class="description">' . ((strlen($row[3]) > 53)?(substr($row[3], 0, 50) . '...'):$desc) . "</span></a></li>\n";
        }
        print "          </ul>\n";
      }
?>
        </div>
        <div id="side">
          <h2><?php print _("Sequence"); ?></h2>
          <a href="<?php print $config['server'] . '/sequence/edit/' . $matches[0] . '" title="' . _("Edit") . '" class="go">' . _("Edit"); ?></a>
          <a href="<?php print $config['server'] . '/mrna/add/' . $matches[0] . '" title="' . _("Add a new mRNA") . '" class="go">' . _("New mRNA"); ?></a>
        </div>
<?php
  }
}

foot();
?>