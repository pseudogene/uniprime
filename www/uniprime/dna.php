<?php
ob_start("ob_gzhandler");
session_start();
require_once('includes/main.inc');

  function deeptree($subtree, $deeper, $i = 0) {
    $node = trim($deeper[$i]);
    if (!isset($subtree[$node])) {
      $subtree[$node] = array();
    }
    if (isset($deeper[$i + 1])) {
      $subtree[$node] = deeptree($subtree[$node], $deeper, $i + 1);
    }
    return $subtree;
  }

  function trunctree($subtree,$key='') {
    if (is_array($subtree) && (count($subtree)==1)) {
      $subtree=trunctree(current($subtree),key($subtree));
    } elseif (is_array($subtree) && (count($subtree)>1)) {
      $subtree=$key;
    } else {
      return false;
    }
    return $subtree;
  }

function put_oligo($ref, $seq, $data, $name, $author, $code, $updated) {
  global $config;
  print "\t<oligo id=\"$ref\" ref=\"" . $config['server'] . '/' . substr($ref,0,-2) . "\">\n";
  if (!empty($name)) print "\t\t<name>" . $name . "</name>\n";
  print "\t\t<sequence>" . $seq . "</sequence>\n";
  print "\t\t<revision version=\"1\">\n";
  print "\t\t\t<author>" . $author . "</author>\n";
  print "\t\t\t<date>" . gmdate("Y-m-d\TH:i:s+00:00", strtotime($updated)) . "</date>\n";
  print "\t\t</revision>\n";
  if (!empty($code) && ($code != '+')) {
    print "\t\t<reference class=\"manual\" />\n";
  }elseif (!empty($code) && ($code == '+')) {
    print "\t\t<reference class=\"software\">\n";
    $soft=explode(' v', $author);
    print "\t\t\t<program" . (!empty($soft[1]) ? (' version="' . $soft[1] . '"') : '') . '>' . $soft[0] . "</program>\n";
    print "\t\t</reference>\n";
  }
  print "\t</oligo>\n";
}

if (((isset($_GET['sequence']) && preg_match('/^S(\d+)\.(\d+)/', $_GET['sequence'], $matches)) || (isset($_GET['mrna']) && preg_match('/^R(\d+)\.(\d+)/', $_GET['mrna'], $matches)) || (isset($_GET['primer']) && preg_match('/^X(\d+)\.(\d+)/', $_GET['primer'], $matches)))) {
  $sql = sql_connect($config['db']);
  if (isset($_GET['primer'])) {
    header('Powered by: ' . $config['powered']);
    header('Content-Type: application/xml; charset=ISO-8859-15');
    print '<!DOCTYPE uniprime PUBLIC "-//UNIPRIME//DTD UNIPRIME 0.4/EN" "' . $config['server'] . '/dtd/uniprime.dtd">' . "\n";
    print "<oligoml version=\"0.4\">\n";
    $result = sql_query('SELECT a.penality, a.left_seq, a.left_data, a.left_name, a.right_seq, a.right_data, a.right_name, a.location, a.pcr, a.updated, a.comments, b.name, a.author, b.functions, c.sequences FROM primer AS a, locus AS b, alignment AS c WHERE a.prefix=' . octdec($matches[1]) . ' AND a.id=' . octdec($matches[2]) . ' AND b.prefix=a.locus_prefix AND b.id=a.locus_id  AND c.prefix=a.alignment_prefix AND c.id=a.alignment_id;', $sql);
    if ((!strlen($r = sql_last_error($sql))) && (sql_num_rows($result) == 1)) {
      $row = sql_fetch_row($result);
      put_oligo($matches[0].'.F',$row[1],$row[2],$row[3],$row[12],$row[13],$row[9]);
      put_oligo($matches[0].'.R',$row[4],$row[5],$row[6],$row[12],$row[13],$row[9]);
      print "\t<pair id=\"" . $matches[0] . '" ref="' . $config['server'] . '/' . $matches[0] . "\">\n";
      print "\t\t<forward>" . $matches[0]. ".F</forward>\n";
      print "\t\t<reverse>" . $matches[0] . ".R</reverse>\n";
      print "\t\t<specificity>\n";
      print "\t\t\t<target" . (!empty($row[11]) ? ('>' . $row[11] . '</target>') : ' />') . "\n";
      $data1 = explode('|', $row[2]);
      $data2 = explode('|', $row[5]);
      if(($data2[0]-$data1[0])>1) print "\t\t\t<length>" . ($data2[0]-$data1[0]+1) . "</length>\n";
      if (!empty($row[7])) print "\t\t\t<location>" . $row[7] . "</location>\n";
      print "\t\t</specificity>\n";
      if (!empty($row[8])) print "\t\t<condition>\n\t\t\t<pcr>" . $row[8] . "</pcr>\n\t\t</condition>\n";
      if (!empty($row[10])) print "\t\t<comments><![CDATA[" . htmlentities(str_replace('<br />',"\n",$row[10]), ENT_COMPAT, 'ISO-8859-15') . "]]></comments>\n";
      print "\t\t<revision version=\"1\">\n";
      print "\t\t\t<author>" . $row[12] . "</author>\n";
      print "\t\t\t<date>" . gmdate("Y-m-d\TH:i:s+00:00", strtotime($row[9])) . "</date>\n";
      print "\t\t</revision>\n";
      print "\t</pair>\n";
    }
    print "</oligoml>\n";
  } else {
    if (isset($_GET['sequence'])) {
      $result = sql_query('SELECT name, sequence, accession, location, organism, features FROM sequence WHERE prefix=' . octdec($matches[1]) . ' AND id=' . octdec($matches[2]) . ';', $sql);
    }elseif (isset($_GET['mrna'])) {
      $result = sql_query('SELECT b.name, a.mrna, b.accession, a.location, b.organism  FROM mrna AS a, sequence AS b WHERE a.prefix=' . octdec($matches[1]) . ' AND a.id=' . octdec($matches[2]) . ' AND b.prefix=a.sequence_prefix AND b.id=a.sequence_id', $sql);
    }
    if (strlen($r = sql_last_error($sql)) || (sql_num_rows($result) < 1)) {
      header('HTTP/1.0 412 Precondition Failed');
      exit(412);
    }
    $row = sql_fetch_row($result);
    $row[1] = bzdecompress(base64_decode($row[1]));
    header('Powered by: ' . $config['powered']);
    if (isset($_GET['xml'])) {
      header("Content-Type: application/xml");
      print '<' . '?xml version="1.0" encoding="ISO-8859-1"?' . ">\n";
      print '<!DOCTYPE TSeq PUBLIC "-//NCBI//NCBI TSeq/EN" "http://www.ncbi.nlm.nih.gov/dtd/NCBI_TSeq.dtd">' . "\n";
      print "<TSeq>\n";
      print '  <TSeq_seqtype value="nucleotide"/>' . "\n";
      print "  <TSeq_sid>$row[0]</TSeq_sid>\n";
      print "  <TSeq_orgname>$row[4]</TSeq_orgname>\n";
      if (isset($_GET['sequence'])) {
        print '  <TSeq_defline>SequenceID ' . $matches[0] . (isset($row[2])?(" [$row[2] REGION: $row[3]]"):'') . "</TSeq_defline>\n";
      }elseif (isset($_GET['mrna'])) {
        print '  <TSeq_defline>TranscriptID ' . $matches[0] . "</TSeq_defline>\n";
      }
      print '  <TSeq_length>' . strlen($row[1]) . '</TSeq_length>' . "\n";
      print "  <TSeq_sequence>$row[1]</TSeq_sequence>\n";
      print "</TSeq>\n";
    }elseif (isset($row[5])) {
      print '<' . '?xml version="1.0" encoding="ISO-8859-1"?' . ">\n";
?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.1//EN"
    "http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en">
 <head>
  <meta http-equiv="Content-Type" content="text/html; charset=iso-8859-1" />
  <meta name="robots" content="noindex,nofollow" />
  <link rel="shortcut icon" href="<?php print $config['server']; ?>/favicon.ico" />
    <style type="text/css" media="all">
/*<![CDATA[*/
   @import url('<?php print $config['server']; ?>/styles/seq.css');
/*]]>*/
    </style>
  <script type="text/javascript" src="<?php print $config['server']; ?>/scripts/seq.js"></script>
  <title><?php print $row[0] . ' (' . $matches[0] . ')'; ?></title>
 </head>
 <body>
<?php
      print "  <div class=\"sequence\">\n";
      print '   <span class="seqcomment">&gt;' . $row[0] . ((!empty($row[2]))?'|' . $row[2]:'') . '|' . $row[4] . ' (' . strlen($row[1]) . " bp)</span>\n";
      $j = 0;
      $table = '';
      $multi = array();
      foreach(explode("\n", $row[5]) as $ligne) {
        $char = explode('|', $ligne, 4);
        $j++;
        for($i = $char[0]; $i <= $char[1]; $i++) {
          if (isset($multi[$i])) {
            $multi[$i][0] .= " f$j";
            if (ord($multi[$i][1]) < ord($char[2])) $multi[$i][1] = $char[2];
          }else {
            $multi[$i][0] = "f$j";
            $multi[$i][1] = $char[2];
          }
        }
        $table .= '    <tr class="nohighlightrow" ondblclick="CopyToClipboard(&#39;f' . $j . '&#39;, this)" onclick="ToggleHL(&#39;f' . $j . '&#39;, this, true)" onmouseover="Highlight(&#39;f' . $j . '&#39;, this)" onmouseout="NoHighlight(&#39;f' . $j . "&#39;,this)\">\n";
        $table .= '     <td class="start">' . $char[0] . "</td>\n";
        $table .= "     <td class=\"interc\">..</td>\n";
        $table .= '     <td class="stop">' . $char[1] . "</td>\n";
        $table .= '     <td class="features">' . $char[3] . "</td>\n";
        $table .= "    </tr>\n";
      }
      $class = array('P' => 'sequence', 'S' => 'sequence', 'V' => 'variation');
      for($i = 1; $i <= strlen($row[1]); $i++) {
        if (isset($multi[$i])) {
          if (isset($last)) {
            if ($last[0] != $multi[$i][0]) {
              print '</span>' . ((($i % 40) == 1)?"<br />\n    ":'') . '<span class="' . $class[$multi[$i][1]] . '" id="' . $multi[$i][0] . '">';
              $last = $multi[$i];
            }else {
              print ((($i % 40) == 1)?'</span>' . "<br />\n    " . '<span class="' . $class[$multi[$i][1]] . '" id="' . $multi[$i][0] . '">':'');
            }
          }else {
            print ((($i % 40) == 1)?"<br />\n    ":'') . '<span class="' . $class[$multi[$i][1]] . '" id="' . $multi[$i][0] . '">';
            $last = $multi[$i];
          }
        }elseif (isset($last)) {
          print '</span>' . ((($i % 40) == 1)?"<br />\n    ":'');
          unset($last);
        }else {
          print ((($i % 40) == 1)?"<br />\n    ":'');
        }
        print $row[1][$i-1];
      }
?>
  </div>
  <table class="feattable" summary="Features">
   <thead>
    <tr>
     <th colspan="3">Position</th>
     <th class="features">Feature</th>
    </tr>
   </thead>
   <tbody>
<?php print $table; ?>
   </tbody>
  </table>
 </body>
</html>
<?php
    }else {
      print '<' . '?xml version="1.0" encoding="ISO-8859-1"?' . ">\n";
?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.1//EN"
    "http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en">
 <head>
  <meta http-equiv="Content-Type" content="text/html; charset=iso-8859-1" />
  <meta name="robots" content="noindex,nofollow" />
  <link rel="shortcut icon" href="<?php print $config['server']; ?>/favicon.ico" />
  <title><?php print $row[0] . ' (' . $matches[0] . ')'; ?></title>
  <style type="text/css">
/*<![CDATA[*/
body { background: #ffffff; padding: 0 0 6em 0; margin: 1em; text-align: center; color: #000000; font-size: 10pt; font-family: sans-serif; }
img { vertical-align: middle; border: 0; }
a{ color: #000099; text-decoration: none; }
a:hover{ text-decoration: underline; }
#dna { text-align: left; width: 30em; margin: 0 auto; }
#dna .xml{ text-align: right; }
#dna .footer { text-align: center; }
/*]]>*/
  </style>
 </head>
 <body>
  <div id="dna">
   <div class="xml">
    <a href="<?php print $config['server'] . $plugin['uniprime']['url'] . '/' . (isset($_GET['sequence'])?'sequence':'mrna') . '/xml/' . $matches[0]; ?>">[<img src="<?php print $config['server'] . $plugin['uniprime']['url']; ?>/images/dnaxml.png" alt="TinyXML" />]</a>
   </div>
   <div>
<?php print '    <pre>' . wordwrap(wordwrap($row[1], 10, ' ', 1), 55) . '</pre>'; ?>
   </div>
   <div class="footer">
    [<a href="javascript:window.close();"><?php print _("close"); ?></a>]
   </div>
  </div>
 </body>
</html>
<?php
    }
  }
} elseif ((isset($_GET['alignment']) && preg_match('/^A(\d+)\.(\d+)/', $_GET['alignment'], $matches)) || (isset($_GET['consensus']) && preg_match('/^A(\d+)\.(\d+)/', $_GET['consensus'], $matches))) {
  $sql = sql_connect($config['db']);
  $result = sql_query('SELECT alignment, consensus FROM alignment WHERE prefix=' . octdec($matches[1]) . ' AND id=' . octdec($matches[2]) . ';', $sql);
  if ((!strlen($r = sql_last_error($sql))) && (sql_num_rows($result) == 1)) {
    $row = sql_fetch_row($result);
    header('Powered by: ' . $config['powered']);
    print '<' . '?xml version="1.0" encoding="ISO-8859-1"?' . ">\n";
?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.1//EN"
    "http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en">
 <head>
  <meta http-equiv="Content-Type" content="text/html; charset=iso-8859-1" />
  <meta name="robots" content="noindex,nofollow" />
  <link rel="shortcut icon" href="<?php print $config['server']; ?>/favicon.ico" />
  <title><?php print $matches[0]; ?></title>
  <style type="text/css">
/*<![CDATA[*/
body { background: #ffffff; padding: 0 0 6em 0; margin: 1em; text-align: center; color: #000000; font-size: 10pt; font-family: sans-serif; }
img { vertical-align: middle; border: 0; }
a{ color: #000099; text-decoration: none; }
a:hover{ text-decoration: underline; }
#dna { text-align: left; width: 30em; margin: 0 auto; }
#dna .xml{ text-align: right; }
#dna .footer { text-align: center; }
/*]]>*/
  </style>
 </head>
 <body>
  <div id="dna">
   <div>
<?php
    if(isset($_GET['alignment'])) {
      print '    <pre>' .bzdecompress(base64_decode($row[0])). '</pre>';
    } elseif(isset($_GET['consensus'])) {
      print '    <pre>' . wordwrap(wordwrap(bzdecompress(base64_decode($row[1])), 10, ' ', 1), 55) . '</pre>';
    }
?>
   </div>
   <div class="footer">
    [<a href="javascript:window.close();"><?php print _("close"); ?></a>]
   </div>
  </div>
 </body>
</html>
<?php
  }
}
?>