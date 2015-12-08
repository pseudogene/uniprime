<?php
ob_start("ob_gzhandler");
session_start();
require_once('includes/main.inc');

head('home');
?>
        <div id="main">
          <h2>Uniprime</h2>
          <p><?php print _("UniPrime is an open-source software [http://uniprime.sourceforge.net] which automatically designs large sets of universal primers by simply inputting a gene ID reference. UniPrime automatically retrieves and aligns orthologous sequences from GenBank, identifies regions of conservation within the alignment and generates suitable primers that can amplify variable genomic regions. UniPrime differs from previous automatic primer design programs in that all steps of primer design are automated, saved and are phylogenetically limited. We have experimentally verified the efficiency and success of this program by amplifying and sequencing four diverse genes (<em>AOF2</em>, <em>EFEMP1</em>, <em>LRP6</em> and <em>OAZ1</em>) across multiple Orders of mammals. UniPrime is an experimentally validated, fully automated program that generates successful cross-species primers that take into account the biological aspects of the PCR."); ?></p>
          <h2><a href="<?php print $config['server']; ?>/browse" title="<?php print _("Browse through the database"); ?>"><?php print _("Browse"); ?></a></h2>
          <p><?php print _("You may browse through the loci and retrieve all related informations."); ?></p>
          <h2><?php print _("Search"); ?></h2>
          <p><?php print _("Retrieve a locus, a sequence, an alignment or a primer set. You may provide a reference number, a primer name, or a keyword."); ?></p>
          <form method="post" action="<?php print $config['server']; ?>/search" id="q">
            <p>
              <label for="query"><?php print _("Enter your query:"); ?></label>
              <input type="text" name="query" id="query" maxlength="50" title="<?php print _("Locus, Sequence or Primer name"); ?>" value="" accept="text/plain" accesskey="q" tabindex="1" />
              <input type="submit" value="<?php print _("Search"); ?>" accesskey="s" tabindex="2" />
            </p>
          <p class="autoclear"></p>
          </form>
        </div>
        <div id="side">
          <h2><?php print _("Main menu"); ?></h2>
          <a href="<?php print $config['server']; ?>/browse" title="<?php print _("Browse in the database"); ?>" class="go"><?php print _("Browse"); ?></a>
          <a href="<?php print $config['server']; ?>/search" title="<?php print _("Direct web search"); ?>" class="go"><?php print _("Search"); ?></a>
          <a href="<?php print $config['server']; ?>/options" title="<?php print _("Preferences page"); ?>" class="go"><?php print _("Options"); ?></a>
        </div>
<?php

foot();
?>