/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2006 OpenLink Software
 *
 *  This project is free software; you can redistribute it and/or modify it
 *  under the terms of the GNU General Public License as published by the
 *  Free Software Foundation; only version 2 of the License, dated June 1991.
 *
 *  This program is distributed in the hope that it will be useful, but
 *  WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
 *  General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License along
 *  with this program; if not, write to the Free Software Foundation, Inc.,
 *  51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA
 *
 */
// ---------------------------------------------------------------------------
var BrowserDetect = {
  init: function () {
    this.browser = this.searchString(this.dataBrowser) || "An unknown browser";
    this.version = this.searchVersion(navigator.userAgent)
      || this.searchVersion(navigator.appVersion)
      || "an unknown version";
    this.OS = this.searchString(this.dataOS) || "an unknown OS";
  },
  searchString: function (data) {
    for (var i=0;i<data.length;i++)  {
      var dataString = data[i].string;
      var dataProp = data[i].prop;
      this.versionSearchString = data[i].versionSearch || data[i].identity;
      if (dataString) {
        if (dataString.indexOf(data[i].subString) != -1)
          return data[i].identity;
      }
      else if (dataProp)
        return data[i].identity;
    }
  },
  searchVersion: function (dataString) {
    var index = dataString.indexOf(this.versionSearchString);
    if (index == -1) return;
    return parseFloat(dataString.substring(index+this.versionSearchString.length+1));
  },
  dataBrowser: [
    {   string: navigator.userAgent,
      subString: "OmniWeb",
      versionSearch: "OmniWeb/",
      identity: "OmniWeb"
    },
    {
      string: navigator.vendor,
      subString: "Apple",
      identity: "Safari"
    },
    {
      prop: window.opera,
      identity: "Opera"
    },
    {
      string: navigator.vendor,
      subString: "iCab",
      identity: "iCab"
    },
    {
      string: navigator.vendor,
      subString: "KDE",
      identity: "Konqueror"
    },
    {
      string: navigator.userAgent,
      subString: "Firefox",
      identity: "Firefox"
    },
    {
      string: navigator.vendor,
      subString: "Camino",
      identity: "Camino"
    },
    {    // for newer Netscapes (6+)
      string: navigator.userAgent,
      subString: "Netscape",
      identity: "Netscape"
    },
    {
      string: navigator.userAgent,
      subString: "MSIE",
      identity: "Explorer",
      versionSearch: "MSIE"
    },
    {
      string: navigator.userAgent,
      subString: "Gecko",
      identity: "Mozilla",
      versionSearch: "rv"
    },
    {     // for older Netscapes (4-)
      string: navigator.userAgent,
      subString: "Mozilla",
      identity: "Netscape",
      versionSearch: "Mozilla"
    }
  ],
  dataOS : [
    {
      string: navigator.platform,
      subString: "Win",
      identity: "Windows"
    },
    {
      string: navigator.platform,
      subString: "Mac",
      identity: "Mac"
    },
    {
      string: navigator.platform,
      subString: "Linux",
      identity: "Linux"
}
  ]

};
BrowserDetect.init();

// ---------------------------------------------------------------------------
function AddAdr(obj,addr)
{
	fld = eval('document.f1.'+ obj.name);
	if (obj.checked == true) {
		if (fld.value.indexOf('~no name~') != -1)
			fld.value = '';
  	if (fld.value.length != 0)
			if (fld.value.substring(fld.value.length-1,fld.value.length) != ',')
				fld.value = fld.value + ',';
		fld.value = fld.value + addr;
	} else {
		pos = fld.value.indexOf(addr)
		if (pos != -1)
			fld.value = fld.value.substring(0,pos) + fld.value.substring(pos + addr.length+1,fld.value.length);
	}
}

// ---------------------------------------------------------------------------
function ClearFld(obj,fvalue)
{
	if (obj.value.indexOf(fvalue) != -1)
		obj.value = '';
}

// ---------------------------------------------------------------------------
showRow = (navigator.appName.indexOf("Internet Explorer") != -1) ? "block" : "table-row";

// ---------------------------------------------------------------------------
function getObject(id)
{
  if (document.all)
    return document.all[id];
  return document.getElementById(id);
}

// ---------------------------------------------------------------------------
function toggleCell(cell)
{
  var c = getObject('row_'+cell);
  c.style.display = (c.style.display == "none") ? showRow : "none";
  var l = getObject('label_'+cell);
  l.innerHTML = l.innerHTML.replace((c.style.display == "none") ? 'Remove' : 'Add', (c.style.display == "none") ? 'Add' : 'Remove');
  var v = (c.style.display == "none") ? '0' : '1';
  createHidden (document, 'x_'+cell, v);
  if (document.forms['f1'].elements['eparams']) {
    var value = document.forms['f1'].elements['eparams'].value;
    var re = new RegExp('&x_'+cell+'=0', 'gi');
    value = value.replace(re, '');
    re = new RegExp('&x_'+cell+'=1', 'gi');
    value = value.replace(re, '');
    document.forms['f1'].elements['eparams'].value = value+'&x_'+cell+'='+v
  } else {
    createHidden (document, 'eparams', '&x_'+cell+'='+v);
  }
}

// ---------------------------------------------------------------------------
function toggleTab(obj, noValue)
{
  if (obj.checked == true) {
    document.getElementById('plain').style.display = 'none';
    document.getElementById('rte').style.display = 'block';
    initEditor('rteMessage');
  } else {
    document.getElementById('plain').style.display = 'block';
    document.getElementById('rte').style.display = 'none';
  }
  if (noValue == null)
    toggleValue(obj);
}

// ---------------------------------------------------------------------------
function initTab(obj)
{
  initValue(obj);
  toggleTab(obj, true);
  returnValue(obj);
}

// ---------------------------------------------------------------------------
function toggleValue(obj) {
  if (obj.checked == true) {
    var value = document.forms['f1'].elements['plainMessage'].value;
    enableDesignMode('rteMessage', text2rte(value), true);
  } else {
    updateRTE('rteMessage');
    var value = document.forms['f1'].elements['rteMessage'].value;
    document.forms['f1'].elements['plainMessage'].value = rte2text(value);
  }
}

// ---------------------------------------------------------------------------
function initValue(obj) {
  var value = document.forms['f1'].elements['message'].value;
  if (obj.checked == true) {
    if (!((BrowserDetect.browser == 'Opera') && (BrowserDetect.version <= '8.53')))
    enableDesignMode('rteMessage', initRte(value), false);
  } else {
    document.forms['f1'].elements['plainMessage'].value = value;
  }
}

// ---------------------------------------------------------------------------
function returnValue(obj) {
  var value;
  if (obj.checked == true) {
    updateRTE('rteMessage');
    value = clearRte(document.forms['f1'].elements['rteMessage'].value);
  } else {
    value = document.forms['f1'].elements['plainMessage'].value;
  }
  document.forms['f1'].elements['message'].value = value;
}

// ---------------------------------------------------------------------------
function initEditor(rte) {
	if (document.all) {
		var oRTE = frames[rte].document;
  	oRTE.designMode = "On";
	} else {
  	try {
  	  document.getElementById(rte).contentDocument.designMode = "on";
  	} catch (e) {
  		setTimeout("initEditor('" + rte + "');", 10);
  	}
	}
}

// ---------------------------------------------------------------------------
function clearRte(value) {
  var re;
  re = new RegExp('\r\n', 'gi');
  value = value.replace(re, '\n');
  re = new RegExp('\n', 'gi');
  value = value.replace(re, '');
  return value;
}

// ---------------------------------------------------------------------------
function initRte(value) {
  var re;
  re = new RegExp('\r\n', 'gi');
  value = value.replace(re, '\n');
  re = new RegExp('\n', 'gi');
  value = value.replace(re, '<br />');
  re = new RegExp("'", 'gi');
  value = value.replace(re, "&apos;");
  return value;
}

// ---------------------------------------------------------------------------
function text2rte(value) {
  var re;
  re = new RegExp('[ ][ ]', 'gi');
  value = value.replace(re, '&nbsp;&nbsp;');
  re = new RegExp('\r\n', 'gi');
  value = value.replace(re, '\n');
  re = new RegExp('\n', 'gi');
  value = value.replace(re, '<br />');
  return value;
}

// ---------------------------------------------------------------------------
function rte2text(value) {
  var re;
  re = new RegExp('&nbsp;', 'gi');
  value = value.replace(re, ' ');
  re = new RegExp('<br />', 'gi');
  value = value.replace(re, '\r\n');
  re = new RegExp('<br>', 'gi');
  value = value.replace(re, '\r\n');
  re = new RegExp('<p>', 'gi');
  value = value.replace(re, '');
  re = new RegExp('</p>', 'gi');
  value = value.replace(re, '\r\n');
	re = new RegExp('(<([^>]+)>)', 'gi');
  value = value.replace(re, '');
  return value;
}

// ---------------------------------------------------------------------------
function createHidden(aDocument, name, value) {
  var hidden;

  hidden = aDocument.forms["f1"].elements[name];
  if (hidden == null) {
    hidden = aDocument.createElement("input");
    hidden.setAttribute ("type", "hidden");
    hidden.setAttribute ("name", name);
    hidden.setAttribute ("id", name);
    aDocument.forms["f1"].appendChild(hidden);
  }
  hidden.value = value;
}

// ---------------------------------------------------------------------------
//
function submitEnter(myForm, myButton, e) {
  var keycode;
  if (window.event)
    keycode = window.event.keyCode;
  else
    if (e)
      keycode = e.which;
    else
      return true;
  if (keycode == 13)
    document.forms[myForm].submit();
  return true;
}

// ---------------------------------------------------------------------------
//
function boxSubmit(value) {
  createHidden (document, 'bp', value);
  createHidden (document, 'sort.x', '1');
  document.f1.submit ();
}

// ---------------------------------------------------------------------------
//
function attachSubmit(value) {
  createHidden (document, 'fa_attach.x', '1');
  document.f1.submit ();
}

// ---------------------------------------------------------------------------
//
function formSubmit(myField, myValue)
{
  createHidden (document, myField, myValue);
  document.f1.submit ();
}

// ---------------------------------------------------------------------------
function confirmAction (confirmMsq, form, txt, selectionMsq)
{
  if (anySelected (form, txt, selectionMsq))
    return confirm (confirmMsq);
  return false;
}

// ---------------------------------------------------------------------------
//
function anySelected (form, txt, selectionMsq)
{
  if ((form != null) && (txt != null)) {
    for (var i = 0; i < form.elements.length; i++) {
      var obj = form.elements[i];
      if ((obj != null) && (obj.type == "checkbox") && (obj.name.indexOf (txt) != -1) && obj.checked)
        return true;
    }
    if (selectionMsq != null)
      alert(selectionMsq);
    return false;
  }
  return true;
}

// ---------------------------------------------------------------------------
//
function showTab2(tab, tabs)
{
  for (var i = 1; i <= tabs; i++) {
    var div = document.getElementById(i);
    if (div != null) {
      var divTab = document.getElementById('tab_'+i);
      if (i == tab) {
        var divNo = document.getElementById('tabNo');
        divNo.value = tab;
        div.style.visibility = 'visible';
        div.style.display = 'block';
        if (divTab != null) {
          divTab.className = "tab activeTab";
          divTab.blur();
        };
      } else {
        div.style.visibility = 'hidden';
        div.style.display = 'none';
        if (divTab != null)
          divTab.className = "tab";
      }
    }
  }
}

// ---------------------------------------------------------------------------
function initTab2(tabs, defaultNo)
{
  var divNo = document.getElementById('tabNo');
  var tab = defaultNo;
  if (divNo != null) {
    var divTab = document.getElementById('tab_'+divNo.value);
    if (divTab != null)
      tab = divNo.value;
  }
  showTab2(tab, tabs);
}

// ---------------------------------------------------------------------------
function saveCheckbox(obj)
{
  createHidden(document, 'ch_'+obj.name, obj.checked ? '1': '');
}
