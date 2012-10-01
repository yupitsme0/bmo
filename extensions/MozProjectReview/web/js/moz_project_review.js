/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this file,
 * You can obtain one at http://mozilla.org/MPL/2.0/.
 *
 * This Source Code Form is "Incompatible With Secondary Licenses", as
 * defined by the Mozilla Public License, v. 2.0. 
 */

function toggleSpecialSections () {
    var mozilla_data_select = YAHOO.util.Dom.get('mozilla_data');
    var data_access_select  = YAHOO.util.Dom.get('data_access');
    var vendor_cost_select  = YAHOO.util.Dom.get('vendor_cost');

    if (mozilla_data_select.value == 'Yes') {
        YAHOO.util.Dom.removeClass('legal_questions','bz_default_hidden');
        YAHOO.util.Dom.removeClass('privacy_policy_project_questions','bz_default_hidden');
        YAHOO.util.Dom.removeClass('data_safety_questions', 'bz_default_hidden');
        YAHOO.util.Dom.removeClass('sec_review_questions', 'bz_default_hidden');
    }
    else {
        YAHOO.util.Dom.addClass('legal_questions','bz_default_hidden');
        YAHOO.util.Dom.addClass('privacy_policy_project_questions','bz_default_hidden');
        YAHOO.util.Dom.addClass('data_safety_questions', 'bz_default_hidden');
        YAHOO.util.Dom.addClass('sec_review_questions', 'bz_default_hidden');
    }

    if (data_access_select.value == 'Yes' || mozilla_data_select.value == 'Yes') {
        YAHOO.util.Dom.removeClass('sec_review_questions', 'bz_default_hidden');
    }
    else {
        YAHOO.util.Dom.addClass('sec_review_questions', 'bz_default_hidden');
    }

    if (data_access_select.value == 'Yes') {
        YAHOO.util.Dom.removeClass('privacy_policy_vendor_questions', 'bz_default_hidden');
    }
    else {
        YAHOO.util.Dom.addClass('privacy_policy_vendor_questions', 'bz_default_hidden');
    }

    if (vendor_cost_select.value == '> $25,000') {
        YAHOO.util.Dom.removeClass('finance_questions','bz_default_hidden');
    }
    else {
        YAHOO.util.Dom.addClass('finance_questions','bz_default_hidden');
    }
}

function toggleVisibleById () {
    var args   = Array.prototype.slice.call(arguments);
    var select = args.shift();
    var value  = args.shift();
    var ids    = args;

    if (typeof select == 'string') {
        select = YAHOO.util.Dom.get(select);
    }

    for (var i = 0; i < ids.length; i++) {
        if (select.value == value) {
            YAHOO.util.Dom.removeClass(ids[i], 'bz_default_hidden');
        }
        else {
            YAHOO.util.Dom.addClass(ids[i], 'bz_default_hidden');
        }
    }
}

function validateAndSubmit () {
    var alert_text = '';
    if (!isFilledOut('short_desc')) alert_text += "Please enter a value for project or feature name\n";
    if (!isFilledOut('contacts')) alert_text += "Please enter a value for points of contact\n";
    if (!isFilledOut('description')) alert_text += "Please enter a value for description\n";
    if (!isFilledOut('urgency')) alert_text += "Please enter a value for urgency\n";
    if (!isFilledOut('release_date')) alert_text += "Please enter a value for release date\n";
    if (!isFilledOut('project_status')) alert_text += "Please select a value for project status\n";
    if (!isFilledOut('mozilla_data')) alert_text += "Please select a value for mozilla data\n";
    if (!isFilledOut('new_or_change')) alert_text += "Please select a value for new or change to existing project\n";
    if (!isFilledOut('separate_party')) alert_text += "Please select a value for separate party\n";

    if (YAHOO.util.Dom.get('separate_party').value == 'Yes') {
        if (!isFilledOut('relationship_type')) alert_text += "Please select a value for type of relationship\n";
        if (!isFilledOut('data_access')) alert_text += "Please select a value for data access\n";
        if (!isFilledOut('vendor_cost')) alert_text += "Please select a value for vendor cost\n";
    }

    if(alert_text == '') {
        return true;
    }

    alert(alert_text);
    return false;
}

YAHOO.util.Event.onDOMReady(function() {
    toggleSpecialSections();
    toggleVisibleById('new_or_change','Existing','mozilla_project_row');
    toggleVisibleById('separate_party','Yes','initial_separate_party_questions');
    toggleVisibleById('relationship_type','Vendor/Services','legal_sow_details_row');
    toggleVisibleById('vendor_cost','> $25,000','finance_questions');
    toggleVisibleById('privacy_policy_project','Yes','privacy_policy_project_link_row');
    toggleVisibleById('privacy_policy_user_data','Yes','privacy_policy_project_user_data_bug_row');
    toggleVisibleById('privacy_policy_vendor_user_data','Yes','privacy_policy_vendor_extra');
    toggleVisibleById('data_safety_user_data','Yes','data_safety_extra_questions');
    toggleVisibleById('data_safety_retention','Yes','data_safety_retention_length_row');
    toggleVisibleById('data_safety_separate_party','Yes','data_safety_separate_party_data_row');
    toggleVisibleById('data_safety_community_visibility','Yes','data_safety_communication_channels_row');
    toggleVisibleById('data_safety_community_visibility','No','data_safety_communication_plan_row');
});

/**
 * Some Form Validation and Interaction
 **/

//Makes sure that there is an '@' in the address with a '.' 
//somewhere after it (and at least one character in between them
function isValidEmail(email) {
    var at_index = email.indexOf("@");
    var last_dot = email.lastIndexOf(".");
    return at_index > 0 && last_dot > (at_index + 1);
}

//Takes a DOM element id and makes sure that it is filled out
function isFilledOut(elem_id)  {
    var str = document.getElementById(elem_id).value;
    return str.length>0 && str!="noneselected";
}

function isChecked(elem_id) {
    return document.getElementById(elem_id).checked;
}
