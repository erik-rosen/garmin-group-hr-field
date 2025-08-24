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
            // Deterministic pseudo-random initials from self id
            var letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ";
            var i1 = (mSelfId % 26) as Number;
            var i2 = (((mSelfId / 26) as Number) % 26) as Number;
            mInitials = letters.substring(i1, 1) + letters.substring(i2, 1);
            Storage.setValue("self_initials", mInitials);
        } else {
            mInitials = (storedIni as String);
        }

        // Override from App Settings if provided
        refreshInitialsFromSettings();

        // Allow settings to override group code before starting transport
        refreshGroupCodeFromSettings();
    // Read Zone 2 threshold
    refreshZone2FromSettings();

        mAnt = new AntGroupTransport(mGroupCode, mSelfId, method(:onPeerPacket), mInitials);
        mLastAppliedInitials = mInitials;
        mLastGroupCode = mGroupCode;
    }

    // Read initials from App Settings (if available) and apply/persist
    function refreshInitialsFromSettings() as Void {
        var ini = null;
        try { ini = Application.Properties.getValue("initials"); } catch(e) { ini = null; }
        if (ini != null) {
            var s = (ini + "").toUpper();
            if (s.length() >= 2) {
                var s2 = s.substring(0, 2);
                if (s2 != mInitials) {
                    mInitials = s2;
                    Storage.setValue("self_initials", mInitials);
                    if (mAnt != null) { mAnt.setInitials(mInitials); }
                }
            }
        }
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
        var z = null;
        try { z = Application.Properties.getValue("zone2Threshold"); } catch(e) { z = null; }
        if (z != null) {
            var n = null;
            try { n = z as Number; } catch(e) { n = null; }
            if (n != null && n > 0 && n <= 255) { mZone2Threshold = (n as Number); }
        }
    }

    // Read group code from settings if present
    function refreshGroupCodeFromSettings() as Void {
        var gc = null;
        try { gc = Application.Properties.getValue("groupCode"); } catch(e) { gc = null; }
        if (gc != null) {
            var n = null;
            try { n = gc as Number; } catch(e) { n = null; }
            if (n != null && n > 0 && n <= 65535) { mGroupCode = (n as Number); }
        }
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
            var list = mGroup.getTopPeers(freshness, 6);
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
                        // Color per peer's threshold if provided
                        if (pz2 != null) {
                            if (((h as Number) > (pz2 as Number))) { tv.setColor(Graphics.COLOR_RED); }
                            else { tv.setColor(Graphics.COLOR_GREEN); }
                        }
                    } else {
                        tv.setText("");
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
            var top = mGroup.getTopPeer(freshness);
            var peers = mGroup.getTopPeers(freshness, 3);

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
                    // If this is my own HR being shown on primary line, color by Zone 2
                    var isSelf = false;
                    try { isSelf = ((top[:id] as Number) == mSelfId); } catch(e) { isSelf = false; }
                    if (isSelf && mZone2Threshold != null) {
                        if (hrNum != null) {
                            if (hrNum > (mZone2Threshold as Number)) { value.setColor(Graphics.COLOR_RED); }
                            else { value.setColor(Graphics.COLOR_GREEN); }
                        }
                    }
                } else {
                    var avg = mGroup.getGroupAverage(true, freshness);
                    var cnt = mGroup.getPeerCount(freshness);
                    if (avg != null) {
                        value.setText("Avg " + (avg as Float).format("%.0f") + " (" + cnt + ")");
                    } else {
                        // Show my own initials + HR (+% if z2 set)
                        var myHrStr = (mValue as Float).format("%.0f");
                        var pctSelf = "";
                        if (mZone2Threshold != null && (mZone2Threshold as Number) > 0) {
                            var pctS = ((mValue as Float) / ((mZone2Threshold as Number) as Float)) * 100.0f;
                            pctSelf = " " + (pctS as Float).format("%.0f") + "%";
                        }
                        value.setText(mInitials + " " + myHrStr + pctSelf);
                        // If showing my own HR only, color by Zone 2
                        if (mZone2Threshold != null) {
                            var myHr = mValue as Number;
                            if (myHr > (mZone2Threshold as Number)) { value.setColor(Graphics.COLOR_RED); }
                            else { value.setColor(Graphics.COLOR_GREEN); }
                        }
                    }
                }
            }

            // Secondary line: up to 3 peers HR list "145,142,137" (center layout only)
            if (sub != null) {
                if (peers.size() > 1) {
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
