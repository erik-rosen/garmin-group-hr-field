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

    function initialize() {
        DataField.initialize();
        mValue = 0.0f;
        mGroup = new GroupManager();

        // Fixed default group code (settings removed)
        mGroupCode = 1234;

        // Persist a stable self id
        var stored = Storage.getValue("self_id");
        if (stored == null) {
            mSelfId = ((System.getTimer() % 65535) as Number);
            Storage.setValue("self_id", mSelfId);
        } else {
            mSelfId = (stored as Number);
        }

        mAnt = new AntGroupTransport(mGroupCode, mSelfId, method(:onPeerPacket));
    }

    function onPeerPacket(pkt as Dictionary) as Void {
        if (!(pkt has :hr) || !(pkt has :peerId)) { return; }
        mGroup.upsertPeer(pkt[:peerId], pkt[:hr]);
    }

    function onShow() as Void {
        DataField.onShow();
        if (mAnt != null) { mAnt.start(); }
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
                        tv.setText((h as Float).format("%.0f"));
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

            // Prefer top peer with ID in primary line
            if (value != null) {
                if (top != null) {
                    var hr = (top[:hr] as Float).format("%.0f");
                    var idStr = top[:id] + "";
                    value.setText(hr + " (ID " + idStr + ")");
                } else {
                    var avg = mGroup.getGroupAverage(true, freshness);
                    var cnt = mGroup.getPeerCount(freshness);
                    if (avg != null) {
                        value.setText("Avg " + (avg as Float).format("%.0f") + " (" + cnt + ")");
                    } else {
                        value.setText((mValue as Float).format("%.0f"));
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
                        s += hStr;
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
