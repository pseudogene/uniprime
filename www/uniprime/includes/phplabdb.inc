<?php
/**
**
** PHPLabDB v2.0 Library
**
**/

class XMLParser {
  var $stack = array();
  function startTag($parser, $name, $attrs) {
    $tag = array('name' => $name, 'attrs' => $attrs);
    array_push($this->stack, $tag);
  }
  function cdata($parser, $cdata) {
    if (trim($cdata))
      if (isset($this->stack[count($this->stack)-1]['cdata'])) {
        $this->stack[count($this->stack)-1]['cdata'] .= $cdata;
      }else {
        $this->stack[count($this->stack)-1]['cdata'] = $cdata;
      }
  }
  function endTag($parser, $name) {
    $this->stack[count($this->stack)-2]['children'][] = $this->stack[count($this->stack)-1];
    array_pop($this->stack);
  }
}

function readXML($buffer) {
  $xml_parser = xml_parser_create();
  $my_parser = new XMLParser();
  xml_set_object($xml_parser, $my_parser);
  xml_set_element_handler($xml_parser, "startTag", "endTag");
  xml_set_character_data_handler($xml_parser, "cdata");
  $data = xml_parse($xml_parser, $buffer);
  if (!$data)
    return false;
  xml_parser_free($xml_parser);
  return $my_parser->stack[0];
}

if (!function_exists('_')) {
  function _($str) {
    return $str;
  }
}

function getRNA($key) {
  $url = "http://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?db=nucleotide&id=$key&rettype=gb";
  $sequence = '';
  if ($genbankFile = fopen($url, "r")) {
    $seqdata_flag = false;
    while (!feof($genbankFile)) {
      $buffer = fgets($genbankFile, 4096);
      if (substr($buffer, 0, 6) == 'ORIGIN') {
        $seqdata_flag = true;
      }elseif ((substr($buffer, 0, 2) != '//') && ($seqdata_flag)) {
        $buffer = preg_replace('/\W/', '', $buffer);
        $sequence .= strtoupper(preg_replace('/\d/', '', $buffer));
      }elseif ((substr($buffer, 0, 2) == '//') && ($seqdata_flag)) {
        $seqdata_flag = false;
      }
    }
    fclose($genbankFile);
    if (strlen($sequence) > 10) return $sequence;
  }
  return false;
}

function getGenbank($key, $start, $end, $foggy=false) {
  $translate = array('A' => 'T', 'T' => 'A', 'C' => 'G', 'G' => 'C');
  if ($foggy) {
    $start -= 25;
    $end += 25;
  }
  $url = "http://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?db=nucleotide&id=$key&rettype=gb&seq_start=$start&seq_stop=$end";
  if ($genbankFile = fopen($url, "r")) {
    $flag_s = false;
    $flag_g = false;
    $flag_c = false;
    $flag_m = false;
    $flag_go = false;
    $seqdata_flag = false;
    $ret['translation'] = 1;
    while (!feof($genbankFile)) {
      $buffer = fgets($genbankFile, 4096);
      if (substr($buffer, 0, 5) == 'LOCUS') {
        $ret['molecule'] = trim(substr($buffer, 44, 7));
        $ret['circular'] = (trim(substr($buffer, 55, 8)) == 'circular'?'t':'f');
        $ret['division'] = trim(strtoupper(substr($buffer, 64, 3)));
        $ret['size'] = intval(trim(substr($buffer, 29, 11)));
        $ret['release'] = strtotime(trim(strtoupper(substr($buffer, 68, 11))));
      }elseif (substr($buffer, 0, 7) == 'VERSION') {
        if (preg_match('/([\d\w\_]+.\d+)/', $buffer, $matches)) {
          $ret['reference'] = $matches[1];
        }
      }elseif (substr($buffer, 0, 6) == 'SOURCE') {
        if (preg_match('/\((.*)\)/', $buffer, $matches)) {
          $ret['common'] = $matches[1];
        }
      }elseif (substr($buffer, 0, 10) == '  ORGANISM') {
        $ret['organism'] = trim(substr($buffer, 12));
       }elseif (substr($buffer, 0, 21) == '     source          ') {
        $flag_s = true;
      }elseif ((substr($buffer, 0, 21) == '                     ') && ($flag_s)) {
        if (substr($buffer, 21, 16) == '/db_xref="taxon:') $ret['taxonid'] = intval(substr($buffer, 37, -2));
        if (substr($buffer, 21, 13) == '/chromosome="') $ret['chromosome'] = substr($buffer, 34, -2);
        if (substr($buffer, 21, 12) == '/organelle="') $ret['organelle'] = substr($buffer, 33, -2);
      }elseif ((substr($buffer, 0, 21) == '     gene            ') && (preg_match('/ (complement\()?(join\()?(\d+)\..*\.(\d+)(\))*$/', $buffer, $matches)) && ((!$foggy && ($matches[3] == 1) && ($ret['size'] == $matches[4])) || ($foggy && ($matches[3] < 50) && (($ret['size'] - $matches[4]) < 50)))) {
        $flag_s = false;
        $begin = $matches[3]-1;
        $length = $matches[4] - $matches[3] + 1;
        $ret['strand'] = (($matches[1] == 'complement(')?-1:1);
        $ret['start'] = $start + $matches[3]-1;
        $ret['end'] = $start + $matches[4]-1;
        $ret['location'] = $ret['start'] . '..' . $ret['end'];
        if ($ret['strand'] == -1) {
          $ret['location'] = 'complement(' . $ret['location'] . ')';
        }
        $flag_g = true;
      }elseif ((substr($buffer, 0, 21) == '                     ') && ($flag_g) && ($flag_c == false)) {
        if (substr($buffer, 21, 7) == '/gene="') $ret['gene'] = substr($buffer, 28, -2);
        if (substr($buffer, 21, 17) == '/db_xref="GeneID:') $ret['geneid'] = intval(substr($buffer, 38, -2));
        if (substr($buffer, 21, 15) == '/db_xref="HGNC:') $ret['hgnc'] = intval(substr($buffer, 36, -2));
      }elseif ((substr($buffer, 0, 21) == '     mRNA            ') && (isset($ret['gene']))) {
        $flag_g = false;
        $flag_m = 1;
        $rna = trim(substr($buffer, 21));
      }elseif ((substr($buffer, 0, 21) == '                     ') && ($flag_m)) {
        if ($flag_m == 1) {
          if (strpos($buffer, '/') === false) {
            $rna .= trim(substr($buffer, 21));
          }else {
            $flag_m = 2;
          }
        }
        if ((substr($buffer, 21, 7) == '/gene="') && ($ret['gene'] == substr($buffer, 28, -2))) {
          $flag_m = 3;
        }elseif (($flag_m == 3) && (substr($buffer, 21, 16) == '/transcript_id="')) {
          if (($tmp = getRNA(trim(substr($buffer, 37, -2)))) !== false) {
            $rna = preg_replace("/(\d+)/e", "('\\1')-$begin", $rna);
            $rna = preg_replace("/^complement\((.*)\)$/", "\\1", $rna);
            if (!isset($ret['structure'])) $ret['structure'] = $rna;
            $ret['mRNA'][$rna] = $tmp;
            unset($tmp);
          }
        }
      }elseif ((substr($buffer, 0, 21) == '     CDS             ') && (isset($ret['gene']))) {
        $flag_g = false;
        $flag_m = false;
        $flag_c = 1;
        $go = '';
      }elseif ((substr($buffer, 0, 21) == '                     ') && ($flag_c)) {
        if ((substr($buffer, 21, 7) == '/gene="') && ($ret['gene'] == substr($buffer, 28, -2))) {
          $flag_c = 2;
        }else {
          if (substr($buffer, 21, 13) == '/go_process="') {
            $go = trim(substr($buffer, 34));
            $flag_go = 2;
          }elseif ($flag_go == 2) {
            if (strpos($buffer, '/') === false) {
              $go .= trim(substr($buffer, 21));
            }else {
              $go = substr($go, 0, -1);
              $flag_go = 1;
            }
          }
        }
        if (substr($buffer, 21, 14) == '/transl_table=') $ret['translation'] = intval(substr($buffer, 35));
      }elseif (substr($buffer, 0, 6) == 'ORIGIN') {
        $flag_g = false;
        if (($flag_c == 2) && !empty($go)) {
          $ret['go'] = $go;
        }
        $flag_c = false;
        $seqdata_flag = true;
        $ret['sequence'] = '';
      }elseif ((substr($buffer, 0, 2) != '//') && ($seqdata_flag)) {
        $buffer = preg_replace('/\W/', '', $buffer);
        $ret['sequence'] .= strtoupper(preg_replace('/\d/', '', $buffer));
      }elseif ((substr($buffer, 0, 2) == '//') && ($seqdata_flag)) {
        if (isset($ret['gene'])) $ret['sequence'] = substr($ret['sequence'], $begin, $length);
        if (isset($ret['strand']) && ($ret['strand'] == -1)) {
          $tmp = '';
          for($i = strlen($ret['sequence'])-1; $i >= 0; $i--) {
            $tmp .= $translate[$ret['sequence'] {
              $i}
            ];
          }
          $ret['sequence'] = $tmp;
          unset($tmp);
        }
        $seqdata_flag = false;
      }elseif (substr($buffer, 0, 21) != '                     ') {
        $flag_g = false;
        $flag_m = false;
        if (($flag_c == 2) && !empty($go)) {
          $ret['go'] = $go;
        }
        $flag_c = false;
      }
    }
    fclose($genbankFile);
    return $ret;
  }else {
    return false;
  }
}

function getLocus( $geneid ) {
  $url = "http://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?db=gene&retmode=xml&id=$geneid";
  if ($genbankFile = fopen($url, "r")) {
    $flag_geno = 0;
    $flag_pheno = 0;
    $flag_path = 0;
    while (!feof($genbankFile)) {
      $buffer = fgets($genbankFile, 4096);
      if (preg_match('/<Entrezgene_summary>(.*)<\/Entrezgene_summary>/', $buffer, $matches)) {
        $ret['comment'] = $matches[1];
      } elseif (preg_match('/<Gene-ref_locus>(.*)<\/Gene-ref_locus>/', $buffer, $matches)) {
        $ret['locus'] = $matches[1];
      } elseif (preg_match('/<Gene-ref_syn_E>(.*)<\/Gene-ref_syn_E>/', $buffer, $matches)) {
        if (empty($ret['locus'])) $ret['locus'] = $matches[1];
      } elseif (preg_match('/<Gene-ref_desc>(.*)<\/Gene-ref_desc>/', $buffer, $matches)) {
        $ret['desc'] = $matches[1];
      } elseif (preg_match('/>(.*)<\/Entrezgene_type>/', $buffer, $matches)) {
        $ret['locus_type'] = $matches[1];
      } elseif (preg_match('/<Maps_display-str>(.*)<\/Maps_display-str>/', $buffer, $matches)) {
        $ret['map'] = $matches[1];
      } elseif (preg_match('/<Gene-commentary_type value="genomic">1<\/Gene-commentary_type>/', $buffer, $matches)) {
        $flag_geno++;
      } elseif ( ( $flag_geno == 1 ) && preg_match('/<Gene-commentary_accession>(.*)<\/Gene-commentary_accession>/', $buffer, $matches)) {
        $ret['accession'] = $matches[1];
      } elseif ( ( $flag_geno == 1 ) && preg_match('/<Seq-interval_from>(\d+)<\/Seq-interval_from>/', $buffer, $matches)) {
        $ret['start'] = $matches[1] + 1;
      } elseif ( ( $flag_geno == 1 ) && preg_match('/<Seq-interval_to>(\d+)<\/Seq-interval_to>/', $buffer, $matches)) {
        $ret['end'] = $matches[1] + 1;
        $flag_geno++;
      } elseif (preg_match('/<Gene-commentary_type value="phenotype">.*<\/Gene-commentary_type>/', $buffer, $matches)) {
        $flag_pheno++;
      } elseif ( ( $flag_pheno == 1 ) && preg_match('/<Gene-commentary_text>(.*)<\/Gene-commentary_text>/', $buffer, $matches)) {
        if ( !empty($ret['phenotype']) ) {
          $ret['phenotype'] .= '|' .  $matches[1];
        } else {
          $ret['phenotype'] =  $matches[1];
        }
        $flag_pheno--;
      } elseif (preg_match('/<Gene-commentary_heading>Pathways<\/Gene-commentary_heading>/', $buffer, $matches)) {
        $flag_path++;
      } elseif ( ( $flag_path == true ) && preg_match('/<Gene-commentary_text>(.*)<\/Gene-commentary_text>/', $buffer, $matches)) {
        if ( !empty($ret['pathway']) ) {
          $ret['pathway'] .= '|' . $matches[1];
        } else {
          $ret['pathway'] = $matches[1];
        }
      } elseif ( ( $flag_path == true ) && preg_match('/<\/Gene-commentary>/', $buffer, $matches)) {
        $flag_path--;
      }
    }
    fclose($genbankFile);
    return $ret;
  }else {
    return false;
  }
}

function addSequence($entry, $sql, $foggy=false) {
  global $config;
  $msg = '';
  if (isset($entry['genbank']) || ((($entry['genbank'] = getGenbank($entry['accession'], $entry['start'], $entry['end'], $foggy)) !== false) && !empty($entry['genbank']['molecule']) && !empty($entry['genbank']['circular']) && !empty($entry['genbank']['reference']) && !empty($entry['genbank']['sequence']) && !empty($entry['genbank']['organism']))) {
    $result = sql_query('SELECT prefix, id FROM sequence WHERE locus_prefix=' . $entry['locus']['prefix'] . ' AND locus_id=' . $entry['locus']['id'] . ' AND accession=\'' . $entry['genbank']['reference'] . '\';', $sql);
    if ((!strlen($r=sql_last_error($sql))) && (sql_num_rows($result)==0)) {
      $prefix = floor(((intval(date('Y', time())) - 2007) * 12 + intval(date('m', time())) - 1) / 1.5);
      if (!empty($entry['genbank']['gene']) && !empty($entry['genbank']['location']) && !empty($entry['genbank']['geneid']) && !empty($entry['genbank']['strand'])) {
        $result = sql_query('INSERT INTO sequence (prefix, id, locus_prefix, locus_id, name, alias, location, isolate, organelle, translation, molecule, circular, chromosome, map, accession, hgnc, geneid, organism, go, sequence_type, primer_prefix, primer_id, structure, stop, start, strand, sequence, features, evalue, sources, comments, author) SELECT ' . $prefix . ', CASE WHEN max(id)>=1 THEN max(id)+1 ELSE 1 END, ' . $entry['locus']['prefix'] . ', ' . $entry['locus']['id'] . ', \'' . addslashes($entry['genbank']['gene']) . '\',' . (isset($entry['alias'])?'\'' . addslashes($entry['alias']) . '\'':'NULL') . ',\'' . addslashes($entry['genbank']['location']) . '\',' . (isset($entry['isolate'])?'\'' . addslashes($entry['isolate']) . '\'':'NULL') . ',' . (isset($entry['genank']['organelle'])?'\'' . addslashes($entry['genank']['organelle']) . '\'':'NULL') . ',' . $entry['genbank']['translation'] . ',\'' . addslashes($entry['genbank']['molecule']) . '\',\'' . $entry['genbank']['circular'] . '\',' . (isset($entry['genbank']['chromosome'])?'\'' . addslashes($entry['genbank']['chromosome']) . '\'':'NULL') . ',' . (isset($entry['map'])?'\'' . addslashes($entry['map']) . '\'':'NULL') . ',\'' . addslashes($entry['genbank']['reference']) . '\',' . (isset($entry['genbank']['hgnc'])?$entry['genbank']['hgnc']:'NULL') . ',' . $entry['genbank']['geneid'] . ',\'' . $entry['genbank']['organism'] . '\',' . (isset($entry['genbank']['go'])?'\'' . addslashes($entry['genbank']['go']) . '\'':'NULL') . ', ' . $entry['type'] . ', ' . (isset($entry['primer'])?octdec($entry['primer'][1]).', '.octdec($entry['primer'][2]):'NULL, NULL') .', ' . (isset($entry['genbank']['structure'])?'\'' . addslashes($entry['genbank']['structure']) . '\'':'NULL') . ',' . $entry['genbank']['end'] . ',' . $entry['genbank']['start'] . ',' . $entry['genbank']['strand'] . ',\'' . addslashes(base64_encode(bzcompress($entry['genbank']['sequence']))) . '\',' . (isset($entry['features'])?'\'' . addslashes($entry['features']) . '\'':'NULL') . ', ' .(isset($entry['evalue'])?$entry['evalue']:'NULL') . ', ' . (isset($entry['references'])?'\''  . addslashes($entry['references']) . '\'':'NULL') . ',' . (isset($entry['comments'])?'\'' . addslashes($entry['comments']) . '\'':'NULL') . ',\'UniPrime Web\' FROM sequence WHERE prefix=' . $prefix . ';', $sql);
      } else {
        $result = sql_query('INSERT INTO sequence (prefix, id, locus_prefix, locus_id, name, alias, location, isolate, organelle, translation, molecule, circular, chromosome, map, accession, hgnc, geneid, organism, go, sequence_type, primer_prefix, primer_id, structure, stop, start, strand, sequence, features, evalue, sources, comments, author) SELECT ' . $prefix . ', CASE WHEN max(id)>=1 THEN max(id)+1 ELSE 1 END, ' . $entry['locus']['prefix'] . ', ' . $entry['locus']['id'] . ', \'' . addslashes($entry['genbank']['reference']) . '\',' . (isset($entry['alias'])?'\'' . addslashes($entry['alias']) . '\'':'NULL') . ',\'1..' . $entry['genbank']['size'] . '\',' . (isset($entry['isolate'])?'\'' . addslashes($entry['isolate']) . '\'':'NULL') . ',' . (isset($entry['genank']['organelle'])?'\'' . addslashes($entry['genank']['organelle']) . '\'':'NULL') . ',' . $entry['genbank']['translation'] . ',\'' . addslashes($entry['genbank']['molecule']) . '\',\'' . $entry['genbank']['circular'] . '\',' . (isset($entry['genbank']['chromosome'])?'\'' . addslashes($entry['genbank']['chromosome']) . '\'':'NULL') . ',' . (isset($entry['map'])?'\'' . addslashes($entry['map']) . '\'':'NULL') . ',\'' . addslashes($entry['genbank']['reference']) . '\',' . (isset($entry['genbank']['hgnc'])?$entry['genbank']['hgnc']:'NULL') . ',' . (isset($entry['genbank']['geneid'])?$entry['genbank']['geneid']:'NULL') . ',\'' . $entry['genbank']['organism'] . '\',' . (isset($entry['genbank']['go'])?'\'' . addslashes($entry['genbank']['go']) . '\'':'NULL') . ', ' . $entry['type'] . ', ' . (isset($entry['primer'])?octdec($entry['primer'][1]).', '.octdec($entry['primer'][2]):'NULL, NULL') .', ' . (isset($entry['genbank']['structure'])?'\'' . addslashes($entry['genbank']['structure']) . '\'':'NULL') . ',' . $entry['genbank']['size'] . ',1,1,\'' . addslashes(base64_encode(bzcompress($entry['genbank']['sequence']))) . '\',' . (isset($entry['features'])?'\'' . addslashes($entry['features']) . '\'':'NULL') . ', ' .(isset($entry['evalue'])?$entry['evalue']:'NULL') . ', ' . (isset($entry['references'])?'\'' . addslashes($entry['references']) . '\'':'NULL') . ',' . (isset($entry['comments'])?'\'' . addslashes($entry['comments']) . '\'':'NULL') . ',\'UniPrime Web\' FROM sequence WHERE prefix=' . $prefix . ';', $sql);
      }
      if (!strlen($r = sql_last_error($sql))) {
        if (isset($entry['genbank']['mRNA']) && count($entry['genbank']['mRNA']) > 0) {
          $result = sql_query('SELECT prefix, id FROM sequence WHERE locus_prefix=' . $entry['locus']['prefix'] . ' AND locus_id=' . $entry['locus']['id'] . ' AND prefix=' . $prefix . ' AND accession=\'' . $entry['genbank']['reference'] . '\' AND sequence_type=' . $entry['type'] . ';', $sql);
          if (!strlen($r = sql_last_error($sql))) {
            $row = sql_fetch_row($result);
            $seq_prefix = intval($row[0]);
            $seq_id = intval($row[1]);
            $i = 0;
            foreach ($entry['genbank']['mRNA'] as $loc => $mrna) {
            $result = sql_query('INSERT INTO mrna (prefix, id, locus_prefix, locus_id, sequence_prefix, sequence_id, mrna_type, location, mrna, author) SELECT ' . $prefix . ', CASE WHEN max(id)>=1 THEN max(id)+1 ELSE 1 END, ' . $entry['locus']['prefix'] . ', ' . $entry['locus']['id'] . ', ' . $seq_prefix . ', ' . $seq_id . ', ' . ++$i . ', \'' . addslashes($loc) . '\', \'' . addslashes(base64_encode(bzcompress($mrna))) . '\', \'UniPrime Web\' FROM mrna WHERE prefix=' . $prefix . ';', $sql);
            }
          }
        }
      }else {
        $msg =  _("SQL error, check your data");
      }
    }else {
      $msg =  _("The sequence already exist!");
    }
  }else {
    $msg = _("Accession number unknown");
  }
  return $msg;
}

function Tm($primer) {
  return round((Tm_cal($primer, true) + Tm_cal($primer, false)) / 2, 2);
}

function Tm_cal($primer, $min = false) {
  $primer_len = strlen($primer);
  list($n_CG, $n_AT) = CG_AT($primer, $min);
  if ($primer_len < 14) {
    return round(2 * $n_AT + 4 * $n_CG, 3);
  }else {
    return round(64.9 + 41 * (($n_CG - 16.4) / $primer_len), 3);
  }
}

function Mw($primer) {
  return round(((Mw_cal($primer, true) + Mw_cal($primer, false)) / 2) / 1000, 2);
}

function Mw_cal($primer, $min = false) {
  $dna_A_wt = 313.245;
  $dna_C_wt = 289.215;
  $dna_G_wt = 329.245;
  $dna_T_wt = 304.225;
  $water = 18.015;
  $wts = array('A' => array($dna_A_wt, $dna_A_wt), // Adenine
    'C' => array($dna_C_wt, $dna_C_wt), // Cytosine
    'G' => array($dna_G_wt, $dna_G_wt), // Guanine
    'T' => array($dna_T_wt, $dna_T_wt), // Thymine
    'M' => array($dna_C_wt, $dna_A_wt), // A or C
    'R' => array($dna_A_wt, $dna_G_wt), // A or G
    'W' => array($dna_T_wt, $dna_A_wt), // A or T
    'S' => array($dna_C_wt, $dna_G_wt), // C or G
    'Y' => array($dna_C_wt, $dna_T_wt), // C or T
    'K' => array($dna_T_wt, $dna_G_wt), // G or T
    'V' => array($dna_C_wt, $dna_G_wt), // A or C or G
    'H' => array($dna_C_wt, $dna_A_wt), // A or C or T
    'D' => array($dna_T_wt, $dna_G_wt), // A or G or T
    'B' => array($dna_C_wt, $dna_G_wt), // C or G or T
    'X' => array($dna_C_wt, $dna_G_wt), // G, A, T or C
    'N' => array($dna_C_wt, $dna_G_wt) // G, A, T or C
    );
  $mwt = 0;
  $wlimit = 0;
  $NA_len = strlen($primer);
  if ($min) $wlimit = 1;
  for ($i = 0; $i < $NA_len; $i++) {
    $NA_base = substr($primer, $i, 1);
    $mwt += $wts[$NA_base][$wlimit];
  }
  $mwt += $water;
  return $mwt;
}

function CG($primer) {
  $primer_len = strlen($primer);
  list($CG_min) = CG_AT($primer, true);
  list($CG_max) = CG_AT($primer, false);
  return (round((($CG_min + $CG_max) / 2) / $primer_len, 2) * 100);
}

function CG_AT($primer, $min = false) {
  if ($min) {
    $primer = preg_replace('/A|T|Y|R|W|K|M|D|V|H|B|N|X/', 'A', $primer);
    $primer = preg_replace('/C|G|S/', 'G', $primer);
  }else {
    $primer = preg_replace('/A|T|W/', 'A', $primer);
    $primer = preg_replace('/C|G|Y|R|S|K|M|D|V|H|B|N|X/', 'G', $primer);
  }
  return array(substr_count($primer, 'G'), substr_count($primer, 'A'));
}
?>