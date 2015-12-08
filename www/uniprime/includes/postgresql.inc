<?php
$regsql='~*';

function sql_connect($database) {
  global $config;
  if ($config['sqlhost']=='localhost') {
    if($result=pg_connect("dbname=$database".(!empty($config['sqllogin'])?' user='.$config['sqllogin']:'').(!empty($config['sqllpassword'])?' password='.$config['sqllpassword']:''))) return $result;
  } else {
    if($result=pg_connect('host='.$config['sqlhost'].(!empty($config['sqlport'])?' port='.$config['sqlhost']:'')." dbname=$database".(!empty($config['sqllogin'])?' user='.$config['sqllogin']:'').(!empty($config['sqllpassword'])?' password='.$config['sqllpassword']:''))) return $result;
  }
}

function sql_query($query,$link) {
  if($result=pg_query($link,$query)) return $result;
}

function sql_reg($name) {
  return "~*'$name'";
}

function sql_field_name($result, $i) {
  return pg_field_name($result, $i);
}

function  sql_last_error($link) {
  return pg_last_error($link);
}

function sql_num_rows($result) {
  if($row=pg_num_rows($result)) return $row;
}

function sql_fetch_row($result) {
  if($row=pg_fetch_row($result)) return $row;
}

function sql_limit($min=0,$size=30) {
  return " OFFSET $min LIMIT $size;";
}
?>