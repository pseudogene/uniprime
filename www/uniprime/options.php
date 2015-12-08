<?php
ob_start("ob_gzhandler");
session_start();
require_once('includes/main.inc');

if (!isset($_SESSION['language'])) @set_pref('language', 'en');
if (!isset($_SESSION['limit'])) @set_pref('limit', false);
if (!empty($_POST['language']) && !empty($_POST['limit'])) {
  @set_pref('language', $_POST['language']);
  @set_pref('limit', (($_POST['limit'] == 'false')?false:intval($_POST['limit'])));
  header('Location: '.$config['server'].'/');
  exit;
}

head('options');
?>
        <div id="main">
          <h2><?php print _("Options"); ?></h2>
          <p><?php print _("Global preference changes apply to all services. You may display tips and messages in another language or filter the locus for the on-going analysis only."); ?></p>
          <form method="post" action="<?php print $config['server']; ?>/options" id="form">
            <p class="autoclear">
              <label for="language"><?php print _("Enter your query"); ?></label>
              <select name="language" id="language" title="<?php print _("Interface language"); ?>" tabindex="1"><option value="en" selected="selected">English</option></select><br />
              <label for="limit"><?php print _("Search limit"); ?></label>
              <select name="limit" id="limit" title="<?php print _("Search limit"); ?>" accesskey="s" tabindex="2"><option value="false"<?php print ((!get_pref('limit'))?' selected="selected"':''); ?>><?php print _("No filter"); ?></option><option value="8"<?php print ((get_pref('limit') == 8)?' selected="selected"':''); ?>><?php print _("Working view"); ?></option></select>
            </p>
            <p class="autoclear">
              <input type="submit" value="<?php print _("Update"); ?>" accesskey="u" tabindex="3" />
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