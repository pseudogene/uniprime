function zulu (login,name,domain,class) {
  if (!name) name=login+'@'+domain;
  if (class) class=' class=\"'+class+' zulu\"';
  document.write('<a href=\"mailto:'+login+'@'+domain+'\"'+class+'>'+name+'</a>');
}

function confirmSubmit(request) {
  if (confirm(request))
    return true;
  else
    return false;
}