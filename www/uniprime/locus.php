<?php
ob_start("ob_gzhandler");
session_start();
require_once('includes/main.inc');

if (!isset($_SESSION['language'])) @set_pref('language', 'en');
if (isset($_GET['edit']) && preg_match('/^L(\d+)\.(\d+)/', $_GET['edit'], $matches)) {
  $sql = sql_connect($config['db']);
  if (isset($_POST['remove']) && !empty($_POST['edit']) && ($_POST['edit'] == md5($matches[0]))) {
    $result = sql_query('DELETE FROM mrna WHERE locus_prefix=' . octdec($matches[1]) . ' AND locus_id=' . octdec($matches[2]) . ';', $sql);
    $result = sql_query('DELETE FROM sequence WHERE locus_prefix=' . octdec($matches[1]) . ' AND locus_id=' . octdec($matches[2]) . ' AND sequence_type>=3;', $sql);
    $result = sql_query('DELETE FROM primer WHERE locus_prefix=' . octdec($matches[1]) . ' AND locus_id=' . octdec($matches[2]) . ';', $sql);
    $result = sql_query('DELETE FROM alignment WHERE locus_prefix=' . octdec($matches[1]) . ' AND locus_id=' . octdec($matches[2]) . ';', $sql);
    $result = sql_query('DELETE FROM sequence WHERE locus_prefix=' . octdec($matches[1]) . ' AND locus_id=' . octdec($matches[2]) . ';', $sql);
    $result = sql_query('DELETE FROM locus WHERE prefix=' . octdec($matches[1]) . ' AND id=' . octdec($matches[2]) . ';', $sql);
    header('Location: ' . $config['server'] . '/');
    exit;
  } elseif (isset($_POST['update']) && !empty($_POST['edit']) && ($_POST['edit'] == md5($matches[0])) && !empty($_POST['name']) && !empty($_POST['functions']) && !empty($_POST['evidence']) && isset($_POST['locus']) && (intval($_POST['locus'])>0)) {
    $entry['name']=preg_replace('/&amp;(#x?[0-9a-f]+);/', '&\1',htmlentities(html_entity_decode($_POST['name']),ENT_QUOTES,'ISO8859-1'));
    if (!empty($_POST['alias'])) $entry['alias']=preg_replace('/&amp;(#x?[0-9a-f]+);/', '&\1',htmlentities(html_entity_decode($_POST['alias']),ENT_QUOTES,'ISO8859-1'));
    $entry['type']=intval($_POST['locus']);
    $entry['evidence']=$_POST['evidence'];
    $entry['status']=intval($_POST['status']);
    if (!empty($_POST['functions'])) { $entry['functions']=ucfirst(preg_replace('/&amp;(#x?[0-9a-f]+);/', '&\1',htmlentities(html_entity_decode($_POST['functions']),ENT_QUOTES,'ISO8859-1'))); }
    if (!empty($_POST['phenotype'])) { $entry['phenotype']=ucfirst(preg_replace('/&amp;(#x?[0-9a-f]+);/', '&\1',htmlentities(html_entity_decode($_POST['phenotype']),ENT_QUOTES,'ISO8859-1'))); }
    if (!empty($_POST['pathway'])) { $entry['pathway']=ucfirst(preg_replace('/&amp;(#x?[0-9a-f]+);/', '&\1',htmlentities(html_entity_decode($_POST['pathway']),ENT_QUOTES,'ISO8859-1'))); }
    if (!empty($_POST['comments'])) { $entry['comments']=ucfirst(preg_replace('/&amp;(#x?[0-9a-f]+);/', '&\1',htmlentities(html_entity_decode($_POST['comments']),ENT_QUOTES,'ISO8859-1'))); }
    if (!empty($_POST['references'])) { $entry['references']=preg_replace('/&amp;(#x?[0-9a-f]+);/', '&\1',htmlentities(html_entity_decode($_POST['references']),ENT_QUOTES,'ISO8859-1')); }
    $result=sql_query('UPDATE locus SET name=\'' . addslashes($entry['name']).'\', alias='.(isset($entry['alias'])?'\''.addslashes($entry['alias']).'\'':'NULL').', locus_type='.$entry['type'].', evidence=\''.$entry['evidence'].'\', status='.$entry['status'].', pathway='.(isset($entry['pathway'])?'\''.addslashes($entry['pathway']).'\'':'NULL').', functions='.(isset($entry['functions'])?'\''.addslashes($entry['functions']).'\'':'NULL').', phenotype='.(isset($entry['phenotype'])?'\''.addslashes($entry['phenotype']).'\'':'NULL').', comments='.(isset($entry['comments'])?'\''.addslashes($entry['comments']).'\'':'NULL').', sources='.(isset($entry['references'])?'\''.addslashes($entry['references']).'\'':'NULL').', updated=NOW(), author=\'UniPrime Web\' WHERE prefix=' . octdec($matches[1]) . ' AND id=' . octdec($matches[2]) . ';', $sql);
    if (!strlen($r=sql_last_error($sql))) {
      header('Location: ' . $config['server'] . '/locus/' . $matches[0]);
      exit;
    } else {
      $msg = _("General error: entry unknown");
    }
  }
  $result = sql_query('SELECT prefix, id, name, alias, pathway, phenotype, functions, comments, sources, evidence, status, locus_type FROM locus WHERE prefix=' . octdec($matches[1]) . ' AND id=' . octdec($matches[2]) . ';', $sql);
  if ((!strlen($r = sql_last_error($sql))) && (sql_num_rows($result) == 1)) {
    head($matches[0]);
    $row = sql_fetch_row($result);
?>
        <div id="main">
          <h2><?php print $row[2]; ?></h2>
<?php if (!empty($msg)) { print "          <p><strong>$msg</strong></p>\n"; } ?>
          <form method="post" action="<?php print $config['server'].'/locus/edit/'.$matches[0]; ?>" id="form">
            <div class="autoclear"><label for="name"><strong><?php print _("Locus name"); ?></strong></label> <input type="text" name="name" id="name" maxlength="100" title="<?php print _("Reference name or gene name"); ?>" <?php print (!empty($_POST['name'])?' value="'.$_POST['name'].'" ':((!isset($_POST['name']) && !empty($row[2]))?' value="'.$row[2].'" ':'')); ?>/><br /></div>
            <div class="autoclear"><label for="alias"><?php print _("Alias"); ?></label> <input type="text" name="alias" id="alias" maxlength="100" title="<?php print _("Locus alias"); ?>" <?php print (!empty($_POST['alias'])?' value="'.$_POST['alias'].'" ':((!isset($_POST['alias']) && !empty($row[3]))?' value="'.$row[3].'" ':'')); ?>/><br /></div>
<?php
    $result=sql_query('SELECT id,locus_type FROM locus_type ORDER BY id;',$sql);
    if ((!strlen($r=sql_last_error($sql))) && (sql_num_rows($result)!=0)) {
      print '            <div class="autoclear"><label for="locus"><strong>'. _("Locus type").'</strong></label> <select name="locus" id="locus" title="'. _("Specifies the type of locus, as defined by the NCBI").'">';
      while($row2=sql_fetch_row($result)) {
        print "<option value=\"$row2[0]\"".(((!empty($_POST['locus']) && $_POST['locus']==$row2[0]) || (!isset($_POST['locus']) && !empty($row[11]) && $row[11]==$row2[0]))?' selected="selected"':'').">$row2[1]</option>";
      }
      print "</select><br /></div>\n";
    }
    $result=sql_query('SELECT id,evidence FROM evidence;',$sql);
    if ((!strlen($r=sql_last_error($sql))) && (sql_num_rows($result)!=0)) {
      print '            <div class="autoclear"><label for="evidence"><strong>'. _("Evidence").'</strong></label> <select name="evidence" id="evidence" title="'. _("Biological evidence (at least for the reference sequence)").'">';
      while($row2=sql_fetch_row($result)) {
        print "<option value=\"$row2[0]\"".(((!empty($_POST['evidence']) && $_POST['evidence']==$row2[0]) || (!isset($_POST['evidence']) && !empty($row[9]) && $row[9]==$row2[0]))?' selected="selected"':'').">$row2[1]</option>";
      }
      print "</select><br /></div>\n";
    }
    $result=sql_query('SELECT id,status FROM status ORDER BY id;',$sql);
    if ((!strlen($r=sql_last_error($sql))) && (sql_num_rows($result)!=0)) {
      print '            <div class="autoclear"><label for="status"><strong>'. _("Status").'</strong></label> <select name="status" id="status" title="'. _("Status details").'">';
      while($row2=sql_fetch_row($result)) {
        print "<option value=\"$row2[0]\"".(((!empty($_POST['status']) && $_POST['status']==$row2[0]) || (!isset($_POST['status']) && !empty($row[10]) && $row[10]==$row2[0]))?' selected="selected"':'').">$row2[1]</option>";
      }
      print "</select><br /></div>\n";
    }
?>
            <div class="autoclear"><label for="functions"><strong><?php print _("Functions"); ?></strong></label> <textarea name="functions" id="functions" cols="30" rows="3" title="<?php print _("Known functions (at least for the reference sequence)"); ?>"><?php print (!empty($_POST['functions'])?$_POST['functions']:((!isset($_POST['functions']) && !empty($row[6]))?$row[6]:'')); ?></textarea><br /></div>
            <div class="autoclear"><label for="phenotype"><?php print _("Phenotype"); ?></label> <textarea name="phenotype" id="phenotype" cols="30" rows="3" title="<?php print _("Associated phenotypes, and diseases"); ?>"><?php print (!empty($_POST['phenotype'])?$_POST['phenotype']:((!isset($_POST['phenotype']) && !empty($row[5]))?$row[5]:'')); ?></textarea><br /></div>
            <div class="autoclear"><label for="pathway"><?php print _("Pathway"); ?></label> <textarea name="pathway" id="pathway" cols="30" rows="3" title="<?php print _("Genetic or functional pathway"); ?>"><?php print (!empty($_POST['pathway'])?$_POST['pathway']:((!isset($_POST['pathway']) && !empty($row[4]))?$row[4]:'')); ?></textarea><br /></div>
            <div class="autoclear"><label for="comments"><?php print _("Comments"); ?></label> <textarea name="comments" id="comments" cols="30" rows="3" title="<?php print _("Extra comments"); ?>"><?php print (!empty($_POST['comments'])?$_POST['comments']:((!isset($_POST['comments']) && !empty($row[7]))?$row[7]:'')); ?></textarea><br /></div>
            <div class="autoclear"><label for="references"><?php print _("References"); ?></label> <textarea name="references" id="references" cols="30" rows="3" title="<?php print _("References for the locus (wiki style [ full_url | name ])"); ?>"><?php print (!empty($_POST['references'])?$_POST['references']:((!isset($_POST['references']) && !empty($row[8]))?$row[8]:'')); ?></textarea><br /></div>
            <p class="autoclear">
              <input type="hidden" name="edit" value="<?php print md5($matches[0]); ?>" />
              <input type="reset" value="<?php print _("Clear"); ?>" accesskey="c" />&nbsp;<input type="submit" name="update" value="<?php print _("Update"); ?>" accesskey="u" />&nbsp;<input type="submit" name="remove" value="<?php print _("Remove"); ?>" onclick="return confirm('<?php print _("Are you sure you want to delete?"); ?>')" accesskey="r" />
            </p>
            <p class="autoclear"></p>
          </form>
        </div>
<?php
    }
} elseif (!empty($_GET['new'])) {
    if (!empty($_POST['uniprime']) && ($_POST['uniprime'] == md5('new')) && !empty($_POST['geneid']) && (intval($_POST['geneid'])>0)) {
      $sql = sql_connect($config['db']);
      if (!empty($_POST['references'])) { $entry['references']=preg_replace('/&amp;(#x?[0-9a-f]+);/', '&\1',htmlentities(html_entity_decode($_POST['references']),ENT_QUOTES,'ISO8859-1')); }
      $result=sql_query('SELECT prefix, id FROM sequence WHERE geneid='.intval($_POST['geneid']).';',$sql);
      if ((!strlen($r=sql_last_error($sql))) && (sql_num_rows($result)==0)) {
        if ((($locus=getlocus(intval($_POST['geneid'])))!==false) && !empty($locus['accession']) && !empty($locus['start']) && !empty($locus['end']) && !empty($locus['locus'])) {
          $prefix = floor(((intval(date('Y', time())) - 2007) * 12 + intval(date('m', time())) - 1) / 1.5);
          $result=sql_query('INSERT INTO locus (prefix, id, name, locus_type, phenotype, pathway, functions, comments, evidence, sources, status, author) SELECT ' . $prefix . ', CASE WHEN max(id)>=1 THEN max(id)+1 ELSE 1 END, \'' . $locus['locus'] .'\','.( !empty($locus['locus_type']) ? intval($locus['locus_type']) : 'NULL' ).','.( !empty($locus['phenotype']) ? '\'' . addslashes($locus['phenotype']) . '\'' : 'NULL' )  . ','.( !empty($locus['pathway']) ? '\'' . addslashes($locus['pathway']) . '\'' : 'NULL' )  . ','.( !empty($locus['desc']) ? '\'' . addslashes($locus['desc']) . '\'' : 'NULL' )  . ','.( !empty($locus['comment']) ? '\'' . addslashes($locus['comment']) . '\'' : 'NULL' )  . ',\'' . ( !empty($pmid_ref) ? 'TAS' : 'NAS' ) .'\','. (!empty($entry['references'])?'\''.addslashes($entry['references']).'\'':'NULL') .',1,\'UniPrime Web\' FROM locus WHERE prefix=' . $prefix . ';', $sql);
          if (!strlen($r=sql_last_error($sql))) {
            $result=sql_query('SELECT prefix, id FROM locus WHERE name=\''.$locus['locus'].'\' AND status=1;',$sql);
            if ((!strlen($r=sql_last_error($sql))) && (sql_num_rows($result)==1)) {
              $row=sql_fetch_row($result);
              $locus['locus']=array('prefix'=>$row[0],'id'=>$row[1]);
              $locus['type']=1;
              addSequence($locus,$sql);
              header('Location: ' . $config['server'] . '/locus/L' . decoct($row[0]) . '.' . decoct($row[1]));
              exit;
            } else {
              $msg = _("General error: entry unknown");
            }
          } else {
            $msg = _("Entry invalid, check your data");
          }
        } else {
          $msg = _("Unknown GeneID");
        }
      } else {
        $msg = _("This locus is already in the database");
      }
    }
    head('locus');
?>
        <div id="main">
          <h2><?php print _("New protoype"); ?></h2>
          <p><?php print _("Alternative entry for UniPrime command-line analyse. This entry replace the <tt>./uniprime.pl --action=locus --target=[id] --pmid=[pmid]</tt>."); ?></p>
<?php if (!empty($msg)) { print "          <p><strong>$msg</strong></p>\n"; } ?>
          <form method="post" action="<?php print $config['server']; ?>/new" id="form">
            <div class="autoclear"><label for="geneid"><strong><?php print _("GeneID"); ?></strong></label> <input type="text" name="geneid" id="geneid" maxlength="100" title="<?php print _("NCBI geneid"); ?>" <?php print (!empty($_POST['geneid'])?' value="'.$_POST['geneid'].'" ':''); ?>/><br /></div>
            <div class="autoclear"><label for="references"><?php print _("References"); ?></label> <textarea name="references" id="references" cols="30" rows="3" title="<?php print _("References for the locus (wiki style [ full_url | name ])"); ?>"><?php print (!empty($_POST['references'])?$_POST['references']:''); ?></textarea><br /></div>
            <p class="autoclear">
              <input type="hidden" name="uniprime" value="<?php print md5('new'); ?>" />
              <input type="reset" value="<?php print _("Clear"); ?>" accesskey="c" />&nbsp;<input type="submit" value="<?php print _("Add"); ?>" accesskey="a" />
            </p>
            <p class="autoclear"></p>
          </form>
        </div>
        <div id="side">
          <h2><?php print _("Locus"); ?></h2>
          <a href="<?php print $config['server'] . '/locus/add" title="' . _("Add a new locus") . '" class="go">' . _("Add a new locus"); ?></a>
          <a href="<?php print $config['server'] . '/new" title="' . _("Add a new prototype") . '" class="go">' . _("Add a new prototype"); ?></a>
          <h2><?php print _("Main menu"); ?></h2>
          <a href="<?php print $config['server']; ?>/browse" title="<?php print _("Browse in the database"); ?>" class="go"><?php print _("Browse"); ?></a>
          <a href="<?php print $config['server']; ?>/search" title="<?php print _("Direct web search"); ?>" class="go"><?php print _("Search"); ?></a>
          <a href="<?php print $config['server']; ?>/options" title="<?php print _("Preferences page"); ?>" class="go"><?php print _("Options"); ?></a>
        </div>
<?php
} elseif (!empty($_GET['add'])) {
    $sql = sql_connect($config['db']);
    if (!empty($_POST['uniprime']) && ($_POST['uniprime'] == md5('add')) && !empty($_POST['name']) && !empty($_POST['functions']) && !empty($_POST['evidence']) && isset($_POST['locus']) && (intval($_POST['locus'])>0)) {
      $entry['name']=preg_replace('/&amp;(#x?[0-9a-f]+);/', '&\1',htmlentities(html_entity_decode($_POST['name']),ENT_QUOTES,'ISO8859-1'));
      if (!empty($_POST['alias'])) $entry['alias']=preg_replace('/&amp;(#x?[0-9a-f]+);/', '&\1',htmlentities(html_entity_decode($_POST['alias']),ENT_QUOTES,'ISO8859-1'));
      $entry['type']=intval($_POST['locus']);
      $entry['evidence']=$_POST['evidence'];
      $entry['status']=intval($_POST['status']);
      if (!empty($_POST['functions'])) { $entry['functions']=ucfirst(preg_replace('/&amp;(#x?[0-9a-f]+);/', '&\1',htmlentities(html_entity_decode($_POST['functions']),ENT_QUOTES,'ISO8859-1'))); }
      if (!empty($_POST['phenotype'])) { $entry['phenotype']=ucfirst(preg_replace('/&amp;(#x?[0-9a-f]+);/', '&\1',htmlentities(html_entity_decode($_POST['phenotype']),ENT_QUOTES,'ISO8859-1'))); }
      if (!empty($_POST['pathway'])) { $entry['pathway']=ucfirst(preg_replace('/&amp;(#x?[0-9a-f]+);/', '&\1',htmlentities(html_entity_decode($_POST['pathway']),ENT_QUOTES,'ISO8859-1'))); }
      if (!empty($_POST['comments'])) { $entry['comments']=ucfirst(preg_replace('/&amp;(#x?[0-9a-f]+);/', '&\1',htmlentities(html_entity_decode($_POST['comments']),ENT_QUOTES,'ISO8859-1'))); }
      if (!empty($_POST['references'])) { $entry['references']=preg_replace('/&amp;(#x?[0-9a-f]+);/', '&\1',htmlentities(html_entity_decode($_POST['references']),ENT_QUOTES,'ISO8859-1')); }
      $result=sql_query('SELECT prefix, id FROM locus WHERE name=\''.addslashes($entry['name']).'\';',$sql);
      if ((!strlen($r=sql_last_error($sql))) && (sql_num_rows($result)==0)) {
        $prefix = floor(((intval(date('Y', time())) - 2007) * 12 + intval(date('m', time())) - 1) / 1.5);
        $result=sql_query('INSERT INTO locus (prefix,id,name,alias,locus_type,evidence,status,pathway,functions,phenotype,comments,sources,author) SELECT ' . $prefix . ', CASE WHEN max(id)>=1 THEN max(id)+1 ELSE 1 END, \'' . addslashes($entry['name']).'\','.(isset($entry['alias'])?'\''.addslashes($entry['alias']).'\'':'NULL').','.$entry['type'].',\''.$entry['evidence'].'\','.$entry['status'].','.(isset($entry['pathway'])?'\''.addslashes($entry['pathway']).'\'':'NULL').','.(isset($entry['functions'])?'\''.addslashes($entry['functions']).'\'':'NULL').','.(isset($entry['phenotype'])?'\''.addslashes($entry['phenotype']).'\'':'NULL').','.(isset($entry['comments'])?'\''.addslashes($entry['comments']).'\'':'NULL').','.(isset($entry['references'])?'\''.addslashes($entry['references']).'\'':'NULL').',\'UniPrime Web\' FROM locus WHERE prefix=' . $prefix . ';', $sql);
        if (!strlen($r=sql_last_error($sql))) {
          $result=sql_query('SELECT prefix, id FROM locus WHERE name=\''.addslashes($entry['name']).'\';',$sql);
          if ((!strlen($r=sql_last_error($sql))) && (sql_num_rows($result)==1)) {
            $row=sql_fetch_row($result);
            header('Location: ' . $config['server'] . '/locus/L' . decoct($row[0]) . '.' . decoct($row[1]));
            exit;
          } else {
            $msg = _("General error: entry unknown");
          }
        } else {
          $msg = _("Entry invalid, check your data");
        }
      } else {
        $msg = _("This locus is already in the database");
      }
    }
    head('locus', true);
?>
        <div id="main">
          <h2><?php print _("New Locus"); ?></h2>
<?php if (!empty($msg)) { print "          <p><strong>$msg</strong></p>\n"; } ?>
          <form method="post" action="<?php print $config['server']; ?>/locus/add" id="form">
            <div class="autoclear"><label for="advanced"><?php print _("Advanced"); ?></label> <input type="checkbox" name="advanced" id="advanced" rel="advanced"<?php print ((!empty($_POST['advanced']) || !empty($taxon))?' checked="checked"':''); ?> /><br /></div>
            <div class="autoclear"><label for="name"><strong><?php print _("Locus name"); ?></strong></label> <input type="text" name="name" id="name" maxlength="100" title="<?php print _("Reference name or gene name"); ?>" <?php print (!empty($_POST['name'])?' value="'.$_POST['name'].'" ':''); ?>/><br /></div>
            <div class="autoclear" rel="advanced"><label for="alias"><?php print _("Alias"); ?></label> <input type="text" name="alias" id="alias" maxlength="100" title="<?php print _("Locus alias"); ?>" <?php print (!empty($_POST['alias'])?' value="'.$_POST['alias'].'" ':''); ?>/><br /></div>
<?php
    $result=sql_query('SELECT id,locus_type FROM locus_type ORDER BY id;',$sql);
    if ((!strlen($r=sql_last_error($sql))) && (sql_num_rows($result)!=0)) {
      print '            <div class="autoclear"><label for="locus"><strong>'. _("Locus type").'</strong></label> <select name="locus" id="locus" title="'. _("Specifies the type of locus, as defined by the NCBI").'">';
      while($row=sql_fetch_row($result)) {
        print "<option value=\"$row[0]\"".((!empty($_POST['locus']) && $_POST['locus']==$row[0])?' selected="selected"':'').">$row[1]</option>";
      }
      print "</select><br /></div>\n";
    }
    $result=sql_query('SELECT id,evidence FROM evidence;',$sql);
    if ((!strlen($r=sql_last_error($sql))) && (sql_num_rows($result)!=0)) {
      print '            <div class="autoclear"><label for="evidence"><strong>'. _("Evidence").'</strong></label> <select name="evidence" id="evidence" title="'. _("Biological evidence (at least for the reference sequence)").'">';
      while($row=sql_fetch_row($result)) {
        print "<option value=\"$row[0]\"".((!empty($_POST['evidence']) && $_POST['evidence']==$row[0])?' selected="selected"':'').">$row[1]</option>";
      }
      print "</select><br /></div>\n";
    }
    $result=sql_query('SELECT id,status FROM status ORDER BY id;',$sql);
    if ((!strlen($r=sql_last_error($sql))) && (sql_num_rows($result)!=0)) {
      print '            <div class="autoclear"><label for="status"><strong>'. _("Status").'</strong></label> <select name="status" id="status" title="'. _("Status details").'">';
      while($row=sql_fetch_row($result)) {
        print "<option value=\"$row[0]\"".((!empty($_POST['status']) && $_POST['status']==$row[0])?' selected="selected"':'').">$row[1]</option>";
      }
      print "</select><br /></div>\n";
    }
?>
            <div class="autoclear"><label for="functions"><strong><?php print _("Functions"); ?></strong></label> <textarea name="functions" id="functions" cols="30" rows="3" title="<?php print _("Known functions (at least for the reference sequence)"); ?>"><?php print (!empty($_POST['functions'])?$_POST['functions']:''); ?></textarea><br /></div>
            <div class="autoclear" rel="advanced"><label for="phenotype"><?php print _("Phenotype"); ?></label> <textarea name="phenotype" id="phenotype" cols="30" rows="3" title="<?php print _("Associated phenotypes, and diseases"); ?>"><?php print (!empty($_POST['phenotype'])?$_POST['phenotype']:''); ?></textarea><br /></div>
            <div class="autoclear" rel="advanced"><label for="pathway"><?php print _("Pathway"); ?></label> <textarea name="pathway" id="pathway" cols="30" rows="3" title="<?php print _("Genetic or functional pathway"); ?>"><?php print (!empty($_POST['pathway'])?$_POST['pathway']:''); ?></textarea><br /></div>
            <div class="autoclear" rel="advanced"><label for="comments"><?php print _("Comments"); ?></label> <textarea name="comments" id="comments" cols="30" rows="3" title="<?php print _("Extra comments"); ?>"><?php print (!empty($_POST['comments'])?$_POST['comments']:''); ?></textarea><br /></div>
            <div class="autoclear" rel="advanced"><label for="references"><?php print _("References"); ?></label> <textarea name="references" id="references" cols="30" rows="3" title="<?php print _("References for the locus (wiki style [ full_url | name ])"); ?>"><?php print (!empty($_POST['references'])?$_POST['references']:''); ?></textarea><br /></div>
            <p class="autoclear">
              <input type="hidden" name="uniprime" value="<?php print md5('add'); ?>" />
              <input type="reset" value="<?php print _("Clear"); ?>" accesskey="c" />&nbsp;<input type="submit" value="<?php print _("Add"); ?>" accesskey="a" />
            </p>
            <p class="autoclear"></p>
          </form>
        </div>
        <div id="side">
          <h2><?php print _("Locus"); ?></h2>
          <a href="<?php print $config['server'] . '/locus/add" title="' . _("Add a new locus") . '" class="go">' . _("Add a new locus"); ?></a>
          <a href="<?php print $config['server'] . '/new" title="' . _("Add a new prototype") . '" class="go">' . _("Add a new prototype"); ?></a>
          <h2><?php print _("Main menu"); ?></h2>
          <a href="<?php print $config['server']; ?>/browse" title="<?php print _("Browse in the database"); ?>" class="go"><?php print _("Browse"); ?></a>
          <a href="<?php print $config['server']; ?>/search" title="<?php print _("Direct web search"); ?>" class="go"><?php print _("Search"); ?></a>
          <a href="<?php print $config['server']; ?>/options" title="<?php print _("Preferences page"); ?>" class="go"><?php print _("Options"); ?></a>
        </div>
<?php
  }elseif (isset($_GET['locus']) && preg_match('/^L(\d+)\.(\d+)/', $_GET['locus'], $matches)) {
    head($matches[0]);
    $sql = sql_connect($config['db']);
    $result = sql_query('SELECT a.prefix, a.id, a.name, a.alias, a.pathway, a.phenotype, a.functions, a.comments, a.sources, a.evidence, b.evidence, a.status, c.status, d.locus_type, a.updated FROM locus AS a, evidence AS b, status AS c, locus_type AS d WHERE a.prefix=' . octdec($matches[1]) . ' AND a.id=' . octdec($matches[2]) . ' AND a.evidence=b.id AND a.status=c.id AND a.locus_type=d.id;', $sql);
    if ((!strlen($r = sql_last_error($sql))) && (sql_num_rows($result) == 1)) {
      $row = sql_fetch_row($result);
?>
        <div id="main">
          <h2><?php print $row[2]; ?></h2>
<?php
      print '          <h3>' . ("Details") . "</h3>\n          <p>\n";
      print '            <span class="title">' . _("ID") . '</span> <span class="desc">L' . decoct($row[0]) . '.' . decoct($row[1]) . "</span><br />\n";
      print '            <span class="title">' .  _("Name") . '</span> <span class="desc">' . $row[2] . "</span><br />\n";
      if (!empty($row[3])) {
        print '            <span class="title">' . _("Alias") . '</span> <span class="desc">' . $row[3] . "</span><br />\n";
      }
      print '            <span class="title">' . _("Locus type") . '</span> <span class="desc">' . $row[13] . "</span><br />\n";
      print '            <span class="title">' . _("Evidence") . '</span> <span class="desc">' . $row[10] . "</span><br />\n";

      print '            <span class="title">' . _("Status") . '</span> <span class="desc">' . $row[12] . "</span><br />\n";
      print '            <span class="title">' . _("Release") . '</span> <span class="desc">' . date(_("m/d/Y"), strtotime($row[14])) . "</span><br />\n";
      print "          </p>\n            <h3>" . _("Function") . "</h3>\n          <p>\n";
      if (!empty($row[6])) {
        print '            <span class="title">' . _("Functions") . '</span> <span class="desc">' . $row[6] . "</span><br />\n";
      }
      if (!empty($row[4])) {
        print '            <span class="title">' . _("Pathway") . '</span> <span class="desc">' . str_replace('|', '<br /><span class="title">&nbsp;</span>', $row[4]) . "</span><br />\n";
      }
      if (!empty($row[5])) {
        print '            <span class="title">' . _("Phenotypes") . '</span> <span class="desc">' . str_replace('|', '<br /><span class="title">&nbsp;</span>', $row[5]) . "</span><br />\n";
      }
      if (!empty($row[7])) {
        print "          </p>\n            <h3>" . _("Comments") . "</h3>\n          <p>\n" . '            ' . $row[7] . "\n";
      }
      if (!empty($row[8])) {
        print "          </p>\n            <h3>" . _("References") . "</h3>\n          <p>\n" . '            ' . preg_replace('/\[([^\|\]]*)\]/','<a href="\1">\1</a><br />',preg_replace('/\[([^\|\]]*)\|([^\|\]]*)\]/','<a href="\1">\2</a><br />',$row[8])) . "\n";
      }
?>
          </p>
<?php
      // sequences
      $result = sql_query('SELECT DISTINCT a.prefix, a.id, a.name, a.map, a.accession, a.organism, a.sequence_type, a.updated, a.organelle FROM sequence AS a, sequence_type AS b WHERE b.lang=\'' . get_pref('language') . '\' AND a.sequence_type=b.id AND a.locus_prefix=' . octdec($matches[1]) . ' AND a.locus_id=' . octdec($matches[2]) . ' AND a.sequence_type<3 ORDER BY a.updated;', $sql);
      if ((!strlen($r = sql_last_error($sql))) && (sql_num_rows($result) > 0)) {
        print "          <h3>" . _("Sequences") . "</h3>\n          <ul class=\"result sequence\">\n";
        while ($row = sql_fetch_row($result)) {
          $desc = '<em>' . ucfirst($row[5]) . '</em>' . (isset($row[3])?' - ' . $row[3]:'') . (!empty($row[4])?' (' . $row[4] . ')':'') . (isset($row[8])?' [' . $row[8] . ']':'');
          print '              <li><a href="' . $config['server'] . '/sequence/S' . decoct($row[0]) . '.' . decoct($row[1]) . '" title="S' . decoct($row[0]) . '.' . decoct($row[1]) . '" class="sequence"><span class="name">' . $row[2] . '</span><span class="date">' . date(_("m/d/Y"), strtotime($row[7])) . '</span><span class="description">' . ((strlen($desc) > 53)?(substr($desc, 0, 50) . '...'):$desc) . "</span></a></li>\n";
        }
        print "          </ul>\n";
      }
      // alignments
      $result = sql_query('SELECT prefix, id, sequences, updated FROM alignment WHERE locus_prefix=' . octdec($matches[1]) . ' AND locus_id=' . octdec($matches[2]) . ' ORDER BY updated;', $sql);
      if ((!strlen($r = sql_last_error($sql))) && (sql_num_rows($result) > 0)) {
        print "          <h3>" . _("Alignments") . "</h3>\n          <ul class=\"result alignment\">\n";
        $i = 1;
        while ($row = sql_fetch_row($result)) {
          $specie = array();
          foreach(explode(' ', $row[2]) as $seqs) {
            if (preg_match('/^(\d+)\.(\d+)/', $seqs, $seq)) {
              $result_seq = sql_query('SELECT organism FROM sequence WHERE prefix=' . octdec($seq[1]) . ' AND id=' . octdec($seq[2]) . ';', $sql);
              if ((!strlen($r = sql_last_error($sql))) && (sql_num_rows($result_seq) == 1)) {
                $row_seq = sql_fetch_row($result_seq);
                $specie[] = ucfirst($row_seq[0]);
              }
            }
          }
          if (isset($specie)) $desc = implode(', ', $specie);
          print '              <li><a href="' . $config['server'] . '/alignment/A' . decoct($row[0]) . '.' . decoct($row[1]) . '" title="X' . decoct($row[0]) . '.' . decoct($row[1]) . '" class="alignment"><span class="name">'._("Alignment") . ' A' . decoct($row[0]) . '.' . decoct($row[1]) . '</span><span class="date">' . date(_("m/d/Y"), strtotime($row[3])) . '</span><span class="description">' . ((strlen($desc) > 53)?(substr($desc, 0, 50) . '...'):$desc) . "</span></a></li>\n";
        }
        print "          </ul>\n";
      }
      // primers
      $result = sql_query('SELECT prefix, id, left_name, right_name, location, updated FROM primer WHERE locus_prefix=' . octdec($matches[1]) . ' AND locus_id=' . octdec($matches[2]) . ' ORDER BY penality;', $sql);
      if ((!strlen($r = sql_last_error($sql))) && (sql_num_rows($result) > 0)) {
        $res=true;
        print "          <h3>" . _("Primers") . "</h3>\n          <ul class=\"result primer\">\n";
        $i = 1;
        while ($row = sql_fetch_row($result)) {
          print '              <li><a href="' . $config['server'] . '/primer/X' . decoct($row[0]) . '.' . decoct($row[1]) . '" title="X' . decoct($row[0]) . '.' . decoct($row[1]) . '" class="primer"><span class="name">X' . decoct($row[0]) . '.' . decoct($row[1]) . '</span><span class="date">' . date(_("m/d/Y"), strtotime($row[5])) . '</span><span class="description">' . substr($row[4], 0, strpos($row[4], '(')) . '</span><span class="type">' . ((isset($row[2]) && isset($row[3]))?($row[2] . ' / ' . $row[3]):'') . "</span></a></li>\n";
        }
        print "          </ul>\n";
      }
?>
        </div>
        <div id="side">
          <h2><?php print _("Locus"); ?></h2>
          <a href="<?php print $config['server'] . '/locus/edit/' . $matches[0] . '" title="' . _("Edit") . '" class="go">' . _("Edit"); ?></a>
          <a href="<?php print $config['server'] . '/sequence/add/' . $matches[0] . '" title="' . _("Add a new sequence") . '" class="go">' . _("New sequence"); ?></a>
          <a href="<?php print $config['server'] . '/alignment/add/' . $matches[0] . '" title="' . _("Add a new aligment") . '" class="go">' . _("New alignment"); ?></a>
          <a href="<?php print $config['server'] . '/locus/add" title="' . _("Add a new locus") . '" class="go">' . _("New locus"); ?></a>
          <a href="<?php print $config['server'] . '/new" title="' . _("Add a new prototype") . '" class="go">' . _("Add a new prototype"); ?></a>
        </div>
<?php
    }
 }
foot();
?>