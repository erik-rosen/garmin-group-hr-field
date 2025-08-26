import Toybox.Activity;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;
import Toybox.System;
import Toybox.Application;
import Toybox.Application.Storage;

class garmin_group_hr_fieldView extends WatchUi.DataField {

    hidden var mValue as Numeric;
    hidden var mGroup as GroupManager;
    hidden var mAnt as AntGroupTransport;
    hidden var mGroupCode as Number;
    hidden var mSelfId as Number;
    hidden var mInitials as String;
    hidden var mLastAppliedInitials as String or Null;
    hidden var mLastGroupCode as Number;
    hidden var mZone2Threshold as Number or Null;

    function initialize() {
        DataField.initialize();
        mValue = 0.0f;
        mGroup = new GroupManager();

    // Default group code (can be overridden by settings)
    mGroupCode = 1234;

        // Persist a stable self id
        var stored = Storage.getValue("self_id");
        if (stored == null) {
            mSelfId = ((System.getTimer() % 65535) as Number);
            Storage.setValue("self_id", mSelfId);
        } else {
            mSelfId = (stored as Number);
        }
        // Persist or derive two-letter initials
        var storedIni = Storage.getValue("self_initials");
        if (storedIni == null) {
            // Default to 'ER' instead of random initials
            mInitials = "ER";
            Storage.setValue("self_initials", mInitials);
        } else {
            mInitials = (storedIni as String);
        }

        // Set default Zone 2 threshold
        mZone2Threshold = 170;

    // Defer reading settings until onShow to avoid platform init quirks

        mAnt = new AntGroupTransport(mGroupCode, mSelfId, method(:onPeerPacket), mInitials);
        mLastAppliedInitials = mInitials;
        mLastGroupCode = mGroupCode;
    }

    // Read initials from App Settings (if available) and apply/persist
    function refreshInitialsFromSettings() as Void {
        try {
            var ini = _getProp("initials");
            if (ini == null) { return; }
            var s = "" + ini; // force to string
            // Normalize: take first two alphabetic chars (A-Z/a-z)
            var cleaned = "";
            var letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz";
            var idx = 0;
            while (idx < s.length() && cleaned.length() < 2) {
                var ch = s.substring(idx, 1);
                if (letters.find(ch) >= 0) { cleaned += ch; }
                idx += 1;
            }
            if (cleaned.length() >= 2) {
                var s2 = cleaned.substring(0, 2);
                if (s2 != mInitials) {
                    mInitials = s2;
                    Storage.setValue("self_initials", mInitials);
                    if (mAnt != null) { mAnt.setInitials(mInitials); }
                }
            }
        } catch(e) { /* swallow */ }
    }

    function onPeerPacket(pkt as Dictionary) as Void {
        if (!(pkt has :hr) || !(pkt has :peerId)) { return; }
    var ini = null;
    try { ini = pkt[:initials] as String; } catch(e) { ini = null; }
    var z2 = null;
    try { z2 = pkt[:z2] as Number; } catch(e) { z2 = null; }
    mGroup.upsertPeer(pkt[:peerId], pkt[:hr], ini, z2);
    }
                

    function onShow() as Void {
        DataField.onShow();
        // Pick up any settings changes made off-device
        refreshInitialsFromSettings();
        if (mAnt != null && mLastAppliedInitials != mInitials) { mAnt.setInitials(mInitials); mLastAppliedInitials = mInitials; }
        // Apply group code changes by recreating transport if needed
        refreshGroupCodeFromSettings();
        if (mGroupCode != mLastGroupCode) {
            if (mAnt != null) { mAnt.stop(); }
            mAnt = new AntGroupTransport(mGroupCode, mSelfId, method(:onPeerPacket), mInitials);
            mLastGroupCode = mGroupCode;
        }
        // Refresh zone 2 threshold
        refreshZone2FromSettings();
    // Push my z2 to transport
    if (mAnt != null) { mAnt.setZone2Threshold(mZone2Threshold); }
        if (mAnt != null) { mAnt.start(); }
    }

    // Read Zone 2 threshold from settings
    function refreshZone2FromSettings() as Void {
    var z = _getProp("zone2Threshold");
        if (z != null) {
            var n = null;
            try { n = z as Number; } catch(e) { n = null; }
            if (n != null && n > 0 && n <= 255) { mZone2Threshold = (n as Number); }
        }
    }

    // Read group code from settings if present
    function refreshGroupCodeFromSettings() as Void {
        var gc = _getProp("groupCode");
        if (gc != null) {
            var n = null;
            try { n = gc as Number; } catch(e) { n = null; }
            if (n != null && n > 0 && n <= 65535) { mGroupCode = (n as Number); }
        }
    }

    // Safe settings accessor: disabled due to symbol invocation issues on Edge 1040
    hidden function _getProp(key as String) as Lang.Object or Null {
        // Temporarily disabled - Properties API causes runtime crashes on some devices
        // try { return Application.Properties.getValue(key); } catch(e) { return null; }
        return null;
    }

    function onHide() as Void {
        if (mAnt != null) { mAnt.stop(); }
        DataField.onHide();
    }

    // Set your layout here. Anytime the size of obscurity of
    // the draw context is changed this will be called.
    function onLayout(dc as Dc) as Void {
        var obscurityFlags = DataField.getObscurityFlags();

        // Top left quadrant so we'll use the compact two-column layout
        if (obscurityFlags == (OBSCURE_TOP | OBSCURE_LEFT)) {
            View.setLayout(Rez.Layouts.CompactQuadLayout(dc));

        // Top right quadrant so we'll use the compact two-column layout
        } else if (obscurityFlags == (OBSCURE_TOP | OBSCURE_RIGHT)) {
            View.setLayout(Rez.Layouts.CompactQuadLayout(dc));

        // Bottom left quadrant so we'll use the compact two-column layout
        } else if (obscurityFlags == (OBSCURE_BOTTOM | OBSCURE_LEFT)) {
            View.setLayout(Rez.Layouts.CompactQuadLayout(dc));

        // Bottom right quadrant so we'll use the compact two-column layout
        } else if (obscurityFlags == (OBSCURE_BOTTOM | OBSCURE_RIGHT)) {
            View.setLayout(Rez.Layouts.CompactQuadLayout(dc));

        // Use the generic, centered layout
        } else {
            View.setLayout(Rez.Layouts.MainLayout(dc));
            var labelView = View.findDrawableById("label") as Text;
            labelView.locY = labelView.locY - 22;
            var valueView = View.findDrawableById("value") as Text;
            valueView.locY = valueView.locY - 2;
            var subView = View.findDrawableById("subvalue") as Text;
            subView.locY = subView.locY + 18;
        }

        // Label differs by layout
        var isCompact = (View.findDrawableById("v1") as Text) != null;
        (View.findDrawableById("label") as Text).setText(isCompact ? "Top HRs" : "Group HR");
    }

    // The given info object contains all the current workout information.
    // Calculate a value and save it locally in this method.
    // Note that compute() and onUpdate() are asynchronous, and there is no
    // guarantee that compute() will be called before onUpdate().
    function compute(info as Activity.Info) as Void {
        // See Activity.Info in the documentation for available information.
        if(info has :currentHeartRate){
            if(info.currentHeartRate != null){
                mValue = info.currentHeartRate as Number;
                mGroup.updateMyHr(mValue);
                if (mAnt != null) { mAnt.sendHr(mValue); }
            } else {
                mValue = 0.0f;
            }
        }
    }

    // Display the value you computed here. This will be called
    // once a second when the data field is visible.
    function onUpdate(dc as Dc) as Void {
        // Set the background color
        (View.findDrawableById("Background") as Text).setColor(getBackgroundColor());

        var bgIsDark = (getBackgroundColor() == Graphics.COLOR_BLACK);

        // Detect compact quadrant layout
        var v1 = View.findDrawableById("v1") as Text;
        var isCompact = (v1 != null);
        if (isCompact) {
            // Compact two-column list of top HRs (up to 6)
            var ids = [ "v1", "v2", "v3", "v4", "v5", "v6" ];
            // Set colors
            for (var i = 0; i < ids.size(); i += 1) {
                var t = View.findDrawableById(ids[i]) as Text;
                if (t != null) { t.setColor(bgIsDark ? Graphics.COLOR_WHITE : Graphics.COLOR_BLACK); }
            }
            var lbl = View.findDrawableById("label") as Text;
            if (lbl != null) { lbl.setColor(Graphics.COLOR_LT_GRAY); }

            var freshness = 15000; // 15s
            var list = mGroup.getTopPeers(freshness, 6, mSelfId);
            // Populate values
            for (var j = 0; j < ids.size(); j += 1) {
                var tv = View.findDrawableById(ids[j]) as Text;
                if (tv != null) {
                    if (j < list.size()) {
                        var item = list[j] as Dictionary;
                        var h = item[:hr] as Numeric;
                        var tag = null;
                        var ini2 = null;
                        try { ini2 = item[:initials] as String; } catch(e) { ini2 = null; }
                        if (ini2 != null) { tag = ini2 + ""; }
                        else { tag = (item[:id] + ""); }
                        var hStr = (h as Float).format("%.0f");
                        // Percentage of peer's Zone 2 threshold if present
                        var pctStr = "";
                        var pz2 = null;
                        try { pz2 = item[:z2] as Number; } catch(e) { pz2 = null; }
                        if (pz2 != null && (pz2 as Number) > 0) {
                            var pct = ((h as Float) / ((pz2 as Number) as Float)) * 100.0f;
                            pctStr = " " + (pct as Float).format("%.0f") + "%";
                        }
                        tv.setText(tag + " " + hStr + pctStr);
                        // Reset to normal font size for peer data
                        tv.setFont(Graphics.FONT_SMALL);
                        // Color per peer's threshold if provided
                        if (pz2 != null) {
                            if (((h as Number) > (pz2 as Number))) { tv.setColor(Graphics.COLOR_RED); }
                            else { tv.setColor(Graphics.COLOR_GREEN); }
                        }
                    } else if (j == 0 && list.size() == 0) {
                        // Show "No peers nearby" only in first row if no peers at all
                        tv.setText("No peers nearby");
                        tv.setColor(Graphics.COLOR_LT_GRAY);
                        // Set smaller font size (half of default)
                        tv.setFont(Graphics.FONT_XTINY);
                    } else {
                        tv.setText("");
                        // Reset font size for empty cells
                        tv.setFont(Graphics.FONT_SMALL);
                    }
                }
            }
        } else {
            // Non-compact layouts (center/full) use primary value + optional subvalue list
            var value = View.findDrawableById("value") as Text;
            var sub = View.findDrawableById("subvalue") as Text;
            if (value != null) {
                value.setColor(bgIsDark ? Graphics.COLOR_WHITE : Graphics.COLOR_BLACK);
            }
            if (sub != null) {
                sub.setColor(bgIsDark ? Graphics.COLOR_WHITE : Graphics.COLOR_BLACK);
            }

            var freshness = 15000; // 15s
            var top = mGroup.getTopPeer(freshness, mSelfId);
            var peers = mGroup.getTopPeers(freshness, 5, mSelfId);

        // Prefer top peer with initials (fallback to ID) in primary line
            if (value != null) {
                if (top != null) {
                    var hrNum = null;
                    try { hrNum = top[:hr] as Number; } catch(e) { hrNum = null; }
                    var hr = (hrNum == null ? "" : ((hrNum as Float).format("%.0f")));
                    var tag = null;
            var ini3 = null;
            try { ini3 = top[:initials] as String; } catch(e) { ini3 = null; }
            if (ini3 != null) { tag = ini3 + ""; }
                    else { tag = ("ID " + (top[:id] + "")); }
                    // Percentage of that peer's Zone 2 threshold if present
                    var pctStr = "";
                    var tz2 = null;
                    try { tz2 = top[:z2] as Number; } catch(e) { tz2 = null; }
                    if (tz2 != null && hrNum != null && (tz2 as Number) > 0) {
                        var pct = ((hrNum as Float) / ((tz2 as Number) as Float)) * 100.0f;
                        pctStr = " " + (pct as Float).format("%.0f") + "%";
                    }
                    value.setText(tag + " " + hr + pctStr);
                } else {
                    // No peers at all
                    value.setText("No peers nearby");
                    value.setColor(Graphics.COLOR_LT_GRAY);
                }
            }

            // Secondary line: up to 5 peers HR list "145,142,137,135,130" (center layout only)
            if (sub != null) {
                if (peers.size() > 0) {
                    var s = "";
                    for (var i = 0; i < peers.size(); i += 1) {
                        var item = peers[i] as Dictionary;
                        var hNum = item[:hr] as Numeric;
                        var hStr = (hNum as Float).format("%.0f");
                        if (i > 0) { s += ","; }
                        // Append a marker if over that peer's threshold
                        var mark = "";
                        var pz = null;
                        try { pz = item[:z2] as Number; } catch(e) { pz = null; }
                        if (pz != null && ((hNum as Number) > (pz as Number))) { mark = "!"; }
                        s += hStr + mark;
                    }
                    sub.setText(s);
                } else {
                    sub.setText("");
                }
            }
        }

        // Call parent's onUpdate(dc) to redraw the layout
        View.onUpdate(dc);
    }

}
