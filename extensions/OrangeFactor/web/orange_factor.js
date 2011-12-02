/* ***** BEGIN LICENSE BLOCK *****
 * Version: MPL 1.1
 * 
 * The contents of this file are subject to the Mozilla Public License Version
 * 1.1 (the "License"); you may not use this file except in compliance with the
 * License. You may obtain a copy of the License at http://www.mozilla.org/MPL/
 * 
 * Software distributed under the License is distributed on an "AS IS" basis,
 * WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License for
 * the specific language governing rights and limitations under the License.
 * 
 * The Original Code is the OrangeFactor Bugzilla Extension;
 * Derived from the Bugzilla Tweaks Addon.
 * 
 * The Initial Developer of the Original Code is the Mozilla Foundation.
 * Portions created by the Initial Developer are Copyright (C) 2011 the Initial
 * Developer. All Rights Reserved.
 * 
 * Contributor(s):
 *   Johnathan Nightingale <johnath@mozilla.com>
 *   Ehsan Akhgari <ehsan@mozilla.com>
 *   Heather Arthur <harthur@mozilla.com>
 *   Byron Jones <glob@mozilla.com>
 *   David Lawrence <dkl@mozilla.com>
 *
 * ***** END LICENSE BLOCK *****
 */

YAHOO.namespace('OrangeFactor');

var OrangeFactor = YAHOO.OrangeFactor;

OrangeFactor.dayMs = 24 * 60 * 60 * 1000,
OrangeFactor.limit = 28;

OrangeFactor.getOrangeCount = function (data) {
    data = data.oranges;
    var total = 0,
        days = [],
        date = Date.now() - (OrangeFactor.limit + 1) * OrangeFactor.dayMs;
    for(var i = 0; i < OrangeFactor.limit; i++) {
        var iso = OrangeFactor.dateString(new Date(date));
        days.push(data[iso] ? data[iso].orangecount : 0);
        date += OrangeFactor.dayMs;
    }
    OrangeFactor.displayGraph(days);
    OrangeFactor.displayCount(days[days.length - 1]);
}

OrangeFactor.displayGraph = function (dayCounts) {
    var max = dayCounts.reduce(function(max, count) {
        return count > max ? count : max;
    });
    var graph = YAHOO.util.Dom.get('orange-graph');
    YAHOO.util.Dom.setAttribute(graph, 'title',
                                'failures over the past month, max in a day: ' + max);
    var  opts = {
        "percentage_lines":[0.25, 0.5, 0.75], "fill_between_percentage_lines":true, 
        "left_padding":0, "right_padding":0, "top_padding":0, "bottom_padding":0, 
        "background":"#FFFFFF", "stroke":"#444444", "percentage_color":"#AAAAFF", 
        "percentage_fill_color":"#CCCCFF"
    };
    new Sparkline('orange-graph', dayCounts, opts).draw();
}

OrangeFactor.displayCount = function (count) {
    var failures = YAHOO.util.Dom.get('orange-failures');
    failures.appendChild(document.createTextNode(count + ' failures'));
    var pastDay = YAHOO.util.Dom.get('orange-past-day');
    pastDay.appendChild(document.createTextNode('in the past day'));
}

OrangeFactor.dateString = function (date) {
    function norm(part) {
        return JSON.stringify(part).length == 2 ? part : '0' + part;
    }
    return date.getFullYear()
           + "-" + norm(date.getMonth() + 1)
           + "-" + norm(date.getDate());
}

OrangeFactor.orangify = function () {
    var bugid = YAHOO.util.Dom.get('orange-bug-id').value;
    var endday = OrangeFactor.dateString(new Date(Date.now() - 1 * OrangeFactor.dayMs));
    var startday = OrangeFactor.dateString(new Date(Date.now() - (OrangeFactor.limit + 1) * OrangeFactor.dayMs));
    var url = "http://brasstacks.mozilla.com/orangefactor/api/count?startday=" + encodeURIComponent(startday) +
               "&endday=" + encodeURIComponent(endday) + "&bugid=" + encodeURIComponent(bugid) + 
               "&callback=OrangeFactor.getOrangeCount";
    var script = document.createElement('script');
    Dom.setAttribute(script, 'src', url);
    Dom.setAttribute(script, 'type', 'text/javascript');
    var head = document.getElementsByTagName('head')[0];
    head.appendChild(script);
}

YAHOO.util.Event.onDOMReady(OrangeFactor.orangify);
