<?php
require_once('config.inc');
require_once('phplabdb.inc');
require_once('postgresql.inc');

function head ($current='', $form = false, $ajax = false){
  global $config;

  header('Powered by: '.$config['powered']);
  print '<'.'?xml version="1.0" encoding="ISO-8859-1"?'.">\n";
?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.1//EN"
    "http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en">
  <head>
    <title>
      UniPrime | <?php print htmlentities($current); ?>
    </title>
    <meta http-equiv="Content-Type" content="text/html; charset=ISO-8859-1" />
    <meta name="robots" content="noindex,nofollow" />
    <style type="text/css" media="screen">
/*<![CDATA[*/
   @import url('<?php print $config['server']; ?>/styles/main.css');
/*]]>*/
    </style>
<?php
  if ($form) { print '    <script type="text/javascript" src="' . $config['server'] . "/scripts/usableforms.js\"></script>\n"; }
  if ($ajax) {
    print '    <script type="text/javascript" src="' . $config['server'] . "/scripts/ajax.js\"></script>\n";
    print "    <script type=\"text/javascript\">\n  window.onload = function(){initPrimer(document.getElementById('primer'),'" . $config['server'] . "/' )};\n</script>\n";
  }
  if(($current=='about')) { print '    <script type="text/javascript" src="'.$config['server']."/scripts/uniprime.js\"></script>\n"; }
?>
  </head>
  <body>
    <h1>UniPrime - Designing universal primers</h1>
    <div id="navigation" class="autoclear">
      <ul>
        <li id="home"<?php print ( $current == 'home' ? '  class="active"': ''); ?>><span><a href="<?php print $config['server']; ?>/" title="<?php print _("Main page"); ?>"><?php print _("home"); ?></a></span></li>
        <li id="browse"<?php print ( $current == 'browse' ? '  class="active"': ''); ?>><span><a href="<?php print $config['server']; ?>/browse" title="<?php print _("Browse in the database"); ?>"><?php print _("browse"); ?></a></span></li>
        <li id="search"<?php print ( $current == 'search' ? '  class="active"': ''); ?>><span><a href="<?php print $config['server']; ?>/search" title="<?php print _("Direct web search"); ?>"><?php print _("search"); ?></a></span></li>
        <li id="options"<?php print ( $current == 'options' ? '  class="active"': ''); ?>><span><a href="<?php print $config['server']; ?>/options" title="<?php print _("Preferences and options"); ?>"><?php print _("options"); ?></a></span></li>
        <li id="about"<?php print ( $current == 'about' ? '  class="active"': ''); ?>><span><a href="<?php print $config['server']; ?>/about" title="<?php print _("About UniPrime"); ?>"><?php print _("about"); ?></a></span></li>
      </ul>
    </div>
    <div class="page">
      <div class="content autoclear">
<?php
 }

function foot() {
?>
      </div>
    </div>
    <p id="footer">
    &copy; 2006-2008 M. Bekaert &amp; E. Teeling. <?php print _("This work is licensed under the"); ?> <a rel="license" href="http://creativecommons.org/licenses/LGPG/2.1/"><?php print _("GNU LGPL License 2.1"); ?></a>.
    </p>
  </body>
</html>
<?php
 }

function set_pref($pref,$status=false) {
  $_SESSION[$pref]=$status;
  return $_SESSION[$pref];
}

function get_pref($pref) {
  if(isset($_SESSION[$pref])) {
    return $_SESSION[$pref];
  }
  return false;
}

function fullyempty($val) {
  $result = false;
  if (empty($val)) $result = true;
  if (!$result && (trim($val) == '')) $result = true;
  if ($result && is_numeric($val) && $val == 0) $result = false;
  return $result;
}

/* To use file_put_contents prior to PHP5 */
if(!function_exists('file_put_contents')) {
  function file_put_contents($filename, $data, $file_append = false) {
    $fp = fopen($filename, (!$file_append ? 'w+' : 'a+'));
    if(!$fp) {
    return false;
  }
    fputs($fp, $data);
    fclose($fp);
    return true;
  }
}
?>
