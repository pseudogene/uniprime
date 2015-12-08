<?php
/* install.php */
/* UniPrime installer (v0.2) */

/* Distribution package */
define('_VERSION', 'UniPrime/Prune v1.18 (2008-04-02)');

function lookdir($dir) {
  if (is_dir($dir) && ($dh = opendir($dir))) {
    while (($file = readdir($dh)) !== false) {
      if ($file!=='..' && $file!=='.') {
        if (is_dir($dir .'/'. $file)) {
          lookdir($dir .'/'. $file);
          @chmod($dir .'/'. $file, 0710);
        } else {
          @chmod($dir .'/'. $file, 0640);
        }
      }
    }
    closedir($dh);
  }
}

if (!empty($_POST['addict']) && (intval($_POST['addict']) == 1)) {
  $step=1;
  if (!empty($_POST['db'])) {
    require_once('includes/postgresql.inc');
    $config = array('db' => trim($_POST['db']), 'sqlhost' => (!empty($_POST['sqlhost'])?strtolower(trim($_POST['sqlhost'])):'localhost'), 'sqlport' => ((!empty($_POST['sqlport']) && (intval($_POST['sqlport']) > 0))?intval($_POST['sqlport']):''), 'sqlpassword' => (!empty($_POST['sqlpassword'])?trim($_POST['sqlpassword']):''), 'sqllogin' => (!empty($_POST['sqllogin'])?trim($_POST['sqllogin']):''));
    $sql = sql_connect($config['db']);
    if (isset($sql)) {
      if (is_readable('.htaccess') && is_writable('.htaccess') && ($htaccess=file_get_contents('.htaccess'))) {
        file_put_contents('.htaccess', preg_replace('/RewriteBase \/uniprime\n/', 'RewriteBase ' . dirname($_SERVER['SCRIPT_NAME']) . "\n", $htaccess));
        $buffer[] = "\$config = array(
  'server'=>'http'.((!empty(\$_SERVER['HTTPS']) && (\$_SERVER['HTTPS']=='on'))?'s':'').'://".((strpos($_SERVER['SERVER_NAME'],':')!==false)?'[':'').$_SERVER['SERVER_NAME'].((strpos($_SERVER['SERVER_NAME'],':')!==false)?']':'').((dirname($_SERVER['SCRIPT_NAME'])!='/')?dirname($_SERVER['SCRIPT_NAME']):'')."',
  'powered' => '" . _VERSION . "',
  'db' => '" . trim($_POST['db']) . "',
  'sqlport' => '" . ((!empty($_POST['sqlport']) && (intval($_POST['sqlport']) > 0))?intval($_POST['sqlport']):'') . "',
  'sqlhost' => '" . (!empty($_POST['sqlhost'])?strtolower(trim($_POST['sqlhost'])):'localhost') . "',
  'sqlpassword' => '" . (!empty($_POST['sqlpassword'])?trim($_POST['sqlpassword']):'') . "',
  'sqllogin' => '" . (!empty($_POST['sqllogin'])?trim($_POST['sqllogin']):'') . "'
  );\n";
        file_put_contents('includes/config.inc','<'."?php\n".implode("\n",$buffer).'?'.'>');
        lookdir('.');
        @chmod('includes/config.inc', 0600);
        @chmod(__FILE__, 0600);
      } else {
        $error = 'Installation file not readable???';
      }
    } else {
      $error = 'SQL server connexion error';
    }
  } else {
    $error = 'SQL server connexion error';
  }
}

?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN"
    "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
<html dir='ltr' xmlns="http://www.w3.org/1999/xhtml">
  <head>
    <title>
      UniPrime Installer
    </title>
    <meta http-equiv="Expires" content="0" />
    <meta http-equiv="cache-control" content="no-cache,no-store" />
    <meta http-equiv="pragma" content="no-cache" />
    <meta http-equiv="Content-Type" content="text/html; charset=us-ascii" />
<style type="text/css">
/*<![CDATA[*/
body { font-family: Georgia,Garamond,Times,serif; background-color: white; color: black; margin: 4em; text-align: center; }
#main { width: 25em; text-align: left; }
h1 { font-size: 110%; font-weight: bold; color: #970038; }
label { font-size: 90%; }
input[type=text], select { width: 10em; }
.right { text-align: right; }
/*]]>*/
</style>
  </head>
  <body>
    <div id="main">
      <h1>
      <?php print _VERSION; ?>
      </h1>
<?php

if (isset($step) && ($step==1) && !isset($error)) {
?>
      <p>
        <strong>Installation done.</strong>
      </p>
      <p>
        You may now use <a href=".">UniPrime Web-companion</a>.
      </p>
<?php
  @unlink (__FILE__);
} else {
?>
      <p>
        <strong>Tuning your installation.</strong>
      </p>
      <p>
        First, the program will set-up the configuration and then adjust the file permissions.
      </p>
      <p>
        <?php print (isset($error)?'<strong>'.$error.'</strong>':'Please field the form and click on the button to continue'); ?>.
      </p>
      <div class="right">
        <form action="<?php print basename($_SERVER['PHP_SELF']); ?>" method="post">
          <label for="db" accesskey="n"><strong>SQL database name</strong></label>&nbsp;<input type="text" name="db" id="db" title="The full database name" value="uniprime" /><br />
          <label for="sqlhost" accesskey="a">SQL host address</label>&nbsp;<input type="text" name="sqlhost" id="sqlhost" title="The full SQL IP address - leave empty for localhost" /><br />
          <label for="sqlport" accesskey="p">SQL port address</label>&nbsp;<input type="text" name="sqlport" id="sqlport" title="The SQL port (e.g. 5432 [PostgreSQL], or 3307 [MySQL])" /><br />
          <label for="sqllogin" accesskey="l">SQL login</label>&nbsp;<input type="text" name="sqllogin" id="sqllogin" title="The SQL login name (e.g. www, apache, etc.)" /><br />
          <label for="sqlpassword" accesskey="p">SQL password</label>&nbsp;<input type="text" name="sqlpassword" id="sqlpassword" title="The SQL password (e.g. 123456789)" /><br />
          <input type="hidden" name="addict" value="1" /><input type="submit" accesskey="f" value="Next &gt;&gt;" />
        </form>
      </div>
<?php
}
?>
    </div>
  </body>
</html>
