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

OrangeFactor.dayMs   = 24 * 60 * 60 * 1000,
OrangeFactor.limit   = 28;

OrangeFactor.getOrangeCount = function (data) {
    data = data.oranges;
    var total = 0,
        days = [],
        date = OrangeFactor.getCurrentDateMs() - (OrangeFactor.limit + 1) * OrangeFactor.dayMs;
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
    var graphContainer = YAHOO.util.Dom.get('orange-graph');
    Dom.removeClass(graphContainer, 'bz_default_hidden');
    YAHOO.util.Dom.setAttribute(graphContainer, 'title',
                                'failures over the past month, max in a day: ' + max);
    var  opts = {
        "percentage_lines":[0.25, 0.5, 0.75], 
        "fill_between_percentage_lines": true, 
        "left_padding": 0, 
        "right_padding": 0, 
        "top_padding": 0,
        "bottom_padding": 0, 
        "background": "#D0D0D0", 
        "stroke": "#000000", 
        "percentage_fill_color": "#CCCCFF"
    };
    new Sparkline('orange-graph', dayCounts, opts).draw();
}

OrangeFactor.displayCount = function (count) {
    var countContainer = YAHOO.util.Dom.get('orange-count');
    countContainer.innerHTML = encodeURIComponent(count) + ' failures in the past day';
}

OrangeFactor.dateString = function (date) {
    function norm(part) {
        return JSON.stringify(part).length == 2 ? part : '0' + part;
    }
    return date.getFullYear()
           + "-" + norm(date.getMonth() + 1)
           + "-" + norm(date.getDate());
}

OrangeFactor.getCurrentDateMs = function () {
    var d = new Date;
    return d.getTime();
}

OrangeFactor.orangify = function () {
    var bugId = document.forms['changeform'].id.value;
    var endDay = OrangeFactor.dateString(new Date(OrangeFactor.getCurrentDateMs() - 1 * OrangeFactor.dayMs));
    var startDay = OrangeFactor.dateString(new Date(OrangeFactor.getCurrentDateMs() - (OrangeFactor.limit + 1) * OrangeFactor.dayMs));
    var url = "https://brasstacks.mozilla.com/orangefactor/api/count?startday=" + encodeURIComponent(startDay) +
              "&endday=" + encodeURIComponent(endDay) + "&bugid=" + encodeURIComponent(bugId) + 
              "&callback=OrangeFactor.getOrangeCount";
    var script = document.createElement('script');
    Dom.setAttribute(script, 'src', url);
    Dom.setAttribute(script, 'type', 'text/javascript');
    var head = document.getElementsByTagName('head')[0];
    head.appendChild(script);
    var countContainer = YAHOO.util.Dom.get('orange-count');
    Dom.removeClass(countContainer, 'bz_default_hidden');
    countContainer.innerHTML = 'Loading...';a
}

YAHOO.util.Event.onDOMReady(OrangeFactor.orangify);
