<?php
ob_start("ob_gzhandler");
session_start();
require_once('includes/main.inc');

head('about');
?>
        <div id="main">
          <h2>Contact</h2>
          <p><?php print _("If you have any questions please email us at"); ?> <script type="text/javascript">
/*<![CDATA[*/
 zulu('michael','Micha&euml;l Bekaert','batlab.eu');
/*]]>*/</script> <?php print _("or"); ?> <script type="text/javascript">
/*<![CDATA[*/
 zulu('emma.teeling','Emma Teeling','ucd.ie');
/*]]>*/</script>.</p>
<!--
          <h2>Citation</h2>
          <p><strong>title</strong><br />authors<br /><em>journal</em>. year month [day]; volume[(issue)]:pages</p>
-->
          <h2>Implementation</h2>
          <p>
            <img src="<?php print $config['server']; ?>/images/uniprime.png" alt="" width="80" height="15" />&nbsp;<?php print $config['powered'] . ' ' . _("was developed by efforts of"); ?> <script type="text/javascript">
/*<![CDATA[*/
 zulu('michael','Micha&euml;l Bekaert','batlab.eu');
/*]]>*/</script> <?php print _("and"); ?> <script type="text/javascript">
/*<![CDATA[*/
 zulu('emma.teeling','Emma Teeling','ucd.ie');
/*]]>*/</script>.
          </p>
          <h3><?php print _("UniPrime command-line interface"); ?></h3>
          <p>
             <img src="<?php print $config['server']; ?>/images/perl.png" alt="perl" width="80" height="15" />&nbsp;<?php print _("Developed using <abbr title=\"Practical Extraction and Report Language\">Perl</abbr>"); ?><br />
             <img src="<?php print $config['server']; ?>/images/bioperl.png" alt="bioperl" width="80" height="15" />&nbsp;<?php print _("Uniprime used <abbr title=\"Perl modules for biology\">Bioperl</abbr> modules"); ?><br />
             <img src="<?php print $config['server']; ?>/images/tcoffee.png" alt="T-Coffee" width="80" height="15" />&nbsp;<?php print _("Developed using T-Coffee"); ?><br />
             <img src="<?php print $config['server']; ?>/images/primer3.png" alt="Primer3" width="80" height="15" />&nbsp;<?php print _("Developed using Primer3"); ?>
          </p>
          <h3><?php print _("Web Framework"); ?></h3>
          <p>
            <img src="<?php print $config['server']; ?>/images/gimp.png" alt="The GIMP" width="80" height="15" />&nbsp;<?php print _("Graphics developed with The GIMP"); ?><br />
            <img src="<?php print $config['server']; ?>/images/php.png" alt="PHP" width="80" height="15" />&nbsp;<?php print _("Site developed using <abbr title=\"recursive acronym for PHP: Hypertext Preprocessor\">PHP</abbr>"); ?><br />
            <img src="<?php print $config['server']; ?>/images/xhtml11.png" alt="XHTML 1.1 valid" width="80" height="15" />&nbsp;<?php print _("Conform to the <abbr title=\"Extensible HyperText Markup Language\">XHTML</abbr> 1.1 standard recommended by the <abbr title=\"World Wide Web Consortium\">W3C</abbr>"); ?><br />
            <img src="<?php print $config['server']; ?>/images/css.png" alt="CSS 2.0 valid" width="80" height="15" />&nbsp;<?php print _("Conform to the <abbr title=\"Cascading Style Sheets\">CSS</abbr> 2.0 standard recommended by the <abbr title=\"World Wide Web Consortium\">W3C</abbr>"); ?><br />
            <img src="<?php print $config['server']; ?>/images/waiaaa.png" alt="WAI-Triple A valid" width="80" height="15" />&nbsp;<?php print _("Conform to the <abbr title=\"Web Accessibility Initiative\">WAI</abbr>-Triple A 1.0 standard recommended by the <abbr title=\"World Wide Web Consortium\">W3C</abbr>"); ?>
          </p>
          <h3><?php print _("Database"); ?></h3>
          <p>
            <img src="<?php print $config['server']; ?>/images/pgsql.png" alt="PostgreSQL" width="80" height="15" />&nbsp;<?php print _("Site developed using PostgreSQL"); ?>
          </p>
          <h3><?php print _("License"); ?></h3>
          <p>
            <img src="<?php print $config['server']; ?>/images/lgpl.png" alt="GNU LGPL" width="80" height="15" />&nbsp;<?php print _("This work is licensed under the GNU LGPL License 2.1"); ?>
          </p>
        </div>
        <div id="side">
        <h2><?php print _("Contact us"); ?></h2>
          <p>Do you have a question or a problem? Give us a shout:</p>
          <script type="text/javascript">
/*<![CDATA[*/
 zulu('michael','Micha&euml;l Bekaert','batlab.eu', 'go');
/*]]>*/</script>
          <script type="text/javascript">
/*<![CDATA[*/
 zulu('emma.teeling','Emma Teeling','ucd.ie', 'go');
/*]]>*/</script>
          <a href="http://uniprime.batlab.eu" class="go url">UniPrime</a>
          <h2 class="separated"><?php print _("Main menu"); ?></h2>
          <a href="<?php print $config['server']; ?>/browse" title="<?php print _("Browse in the database"); ?>" class="go"><?php print _("Browse"); ?></a>
          <a href="<?php print $config['server']; ?>/search" title="<?php print _("Direct web search"); ?>" class="go"><?php print _("Search"); ?></a>
          <a href="<?php print $config['server']; ?>/options" title="<?php print _("Preferences page"); ?>" class="go"><?php print _("Options"); ?></a>
        </div>
<?php

foot();
?>
