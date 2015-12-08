var _inputField=null;
var _path=null;
var _oldInputFieldValue="";
var _currentInputFieldValue="";
var _xmlHttp = null;

function getXMLHTTP(){
  var xml_request = false;
  if (window.XMLHttpRequest) { // Mozilla, Safari,...
    xml_request = new XMLHttpRequest();
    if (xml_request.overrideMimeType) {
      xml_request.overrideMimeType('text/xml');
    }
  } else if (window.ActiveXObject) { // IE
    try {
      xml_request = new ActiveXObject("Msxml2.XMLHTTP");
    } catch (e) {
      try {
        xml_request = new ActiveXObject("Microsoft.XMLHTTP");
      } catch (e) {}
    }
  }
  return xml_request;
}

function initPrimer(field,path){
  if (field != 'undefined') {
    _inputField=field;
    _path=path;
    _currentInputFieldValue=_inputField.value;
    _oldInputFieldValue=_currentInputFieldValue;
    setTimeout("mainLoop()",200);
  }
}

function mainLoop(){
  _currentInputFieldValue = _inputField.value;
  if(_oldInputFieldValue!=_currentInputFieldValue){
    var valeur=escapeURI(_currentInputFieldValue);
    callPrimer(valeur);
    _inputField.focus()
  }
  _oldInputFieldValue=_currentInputFieldValue;
  setTimeout("mainLoop()",200);
  return true;
}

function escapeURI(La){
  if(encodeURIComponent) {
    return encodeURIComponent(La);
  }
  if(escape) {
    return escape(La)
  }
}

function callPrimer(valeur){
  if(_xmlHttp&&_xmlHttp.readyState!=0){
    _xmlHttp.abort()
  }
  _xmlHttp=getXMLHTTP();
  if(_xmlHttp){
    _xmlHttp.open("GET",_path+"primer_ajax.php?primer="+valeur,true);
    _xmlHttp.onreadystatechange=function() {
      if(_xmlHttp.readyState==4&&_xmlHttp.responseXML) {
        var result = _xmlHttp.responseXML;
        check(result.getElementsByTagName('answer').item(0).firstChild.data);
      }
    };
    _xmlHttp.send(null)
  }
}

function check(valeur) {
  if (valeur!='true') {
    _inputField.style.backgroundColor="#ff6666";
    _inputField.style.color="#ffffff";
  } else {
    _inputField.style.backgroundColor="#89d289";
    _inputField.style.color="#000000";
  }
}