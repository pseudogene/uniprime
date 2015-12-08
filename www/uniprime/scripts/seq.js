function ElemData( id, elem ) {
  this.elemid = id;
  this.elem = elem;
}
var sticky = new ElemData( '', '' );

function Highlight( section, elem ) {
  if( sticky.elemid == section ) {
    elem.className = 'stickyrow';
  } else {
    elem.className = 'highlightrow';
  }
  var spans = document.getElementsByTagName('span');
  for( var s = 0; s < spans.length; ++s ) {
    if( spans[s].id.match(section) ) {
      if( section == sticky.elemid ) {
        spans[s].className = 'sticky';
      } else {
        if( spans[s].className == 'sequence' ) {
          spans[s].className = 'sequencehighlight' ;
        } else if( spans[s].className == 'variation' ) {
          spans[s].className = 'variationhighlight';
        } else if( spans[s].className == 'Sticky' ) {
          spans[s].className = 'stickyhighlight';
        }
      }
    }
  }
  if( window.clipboardData ) {
    elem.setAttribute( 'title', 'Double click to copy sequence to clipboard' );
  }  else {
    if( section == sticky.elemid ) {
      elem.setAttribute( 'title', 'Click here to unmark sequence' );
    } else {
      elem.setAttribute( 'title', 'Click here to mark sequence' );
    }
  }
}

function NoHighlight( section, elem ) {
  if( sticky.elemid == section) {
    elem.className = 'stickyrow';
  } else {
    elem.className = 'nohighlightrow';
  }
  var spans = document.getElementsByTagName('span');
  for( var s = 0; s < spans.length; ++s ) {
    if(spans[s].id.match(section)) {
      if( spans[s].className == 'sticky' || spans[s].className == 'stickyhighlight' ) {
        spans[s].className = 'sticky';        
      } else if(spans[s].className == 'sequencehighlight' ) {
          spans[s].className = 'sequence';
      } else if(spans[s].className == 'variationhighlight' ) {
          spans[s].className = 'variation';
      }
    }
  }
}

function PutSticky( elemid, elem ) {
  var spans = document.getElementsByTagName('span');
  for( var s = 0; s < spans.length; ++s ) {
    if( spans[s].id.match(elemid) ) {
      AddToSticky( elemid, elem );
      spans[s].className = 'sticky';
      elem.className = 'stickyrow';
    }
  }
}

function RemoveSticky( elemid, elem ) {
  var spans = document.getElementsByTagName('span');
  for( var s = 0; s < spans.length; ++s ) {
    if( spans[s].id.match(elemid) ) {    
      if( sticky.spanclass == 'variation' || sticky.spanclass == 'variationhighlight' ) {
        spans[s].className = 'variation';
      } else {
        spans[s].className = 'sequence';
      }
      elem.className = 'nohighlightrow';
    }
  }
  ClearSticky();
}

function ToggleHL( elemid, elem ) {
  if( !InSticky(elemid) ) {
    if( sticky.elemid != '' ) RemoveSticky( sticky.elemid, sticky.elem );
    PutSticky(elemid,elem);
  } else {
    RemoveSticky(elemid,elem);
  }
}

function AddToSticky( elemid, elem ) {
  sticky.elem = elem;
  sticky.elemid = elemid;  
}
function ClearSticky() {
  sticky.elem = '';
  sticky.elemid = '';
}
function InSticky( elemid ) {
  if( sticky.elemid == elemid ) return true;
  return false;
}

function CopyToClipboard( section, elem ) {
  var spans = document.getElementsByTagName('span');
  var copytext='';
  for( var s = 0; s < spans.length; ++s ) {
    if( spans[s].id.match(section) ) {
      if( document.all ) {
        copytext += spans[s].innerText;
      } else {
        copytext += spans[s].textContent;
      }
    }
  }
  if(window.clipboardData) { // Works in IE only
    window.clipboardData.setData("Text",copytext);
  }
}