<?php
ob_start("ob_gzhandler");
session_start();
require_once('includes/main.inc');

if (!empty($_GET['help'])) {
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
   @import url('<?php print $config['server']; ?>/styles/main.css');
/*]]>*/
    </style>
  <title><?php print $_GET['help']; ?></title>
 </head>
 <body>
   <div class="help">
     <h3><?php print $_GET['help']; ?></h3>
<?php if($_GET['help']=='structure') { ?>
     <p>You may highlight some important features on the sequence, or in the processe to work with multiple sequence. This field allows the user to easyly hilight basic features: Primers positions, Nucleotidic polymorphysm and the main sequence itself.<br />Each entry must include the type of feature, the position and a description. (one feature per line)<br /><code>Begin | End | Type | Description</code><br /></p>
     <h3>Begin</h3>
     <p>This is the start position of the feature. This value must be between 1 and the length of the sequence.</p>
     <h3>End</h3>
     <p>This is the end position of the feature. This value must be between start position value and the length of the sequence.</p>
     <h3>Type</h3>
     <p><code>P <em>primer</em><br />V <em>variation/polymorphysm</em><br />S <em>sequence</em><br /></code></p>
     <h3>Description</h3>
     <p>Short description of the feature</p>
     <h3>Example</h3>
     <p>Position of forward and reverse primer on a sequence of 500 bp<br /><code>1|20|P|Forward Primer<br />21|479|S|PCR Product<br />480|500|P|Reverse Primer<br /></code></p>
<?php } ?>
   </div>
 </body>
</html>
<?php } ?>