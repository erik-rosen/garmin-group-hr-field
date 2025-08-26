import Toybox.System;
import Toybox.Lang;

class PeerRec {
    var hr as Numeric;
    var ts as Number; // ms since app start
    var initials as String or Null;
    var z2 as Number or Null;
    function initialize(h as Numeric, t as Number, ini as String or Null, z as Number or Null) {
        hr = h;
        ts = t;
        initials = ini;
        z2 = z;
    }
}

class GroupManager {
    // peerId (String/Number) => PeerRec
    var _peers as Dictionary;
    var _myHr as Numeric or Null;

    function initialize() {
        _peers = {};
        _myHr = null;
    }

    function updateMyHr(hr as Numeric or Null) as Void {
        _myHr = hr;
    }

    function getMyHr() as Numeric or Null { return _myHr; }

    function upsertPeer(peerId as String or Number, hr as Numeric, initials as String or Null, z2 as Number or Null) as Void {
        _peers[peerId] = new PeerRec(hr, System.getTimer(), initials, z2);
    }

    function prune(maxAgeMs as Number) as Void {
        var now = System.getTimer();
        var keys = _peers.keys();
        var toRemove = [];
        for (var i = 0; i < keys.size(); i += 1) {
            var k = keys[i];
            var rec = _peers[k] as PeerRec;
            if ((now - rec.ts) > maxAgeMs) {
                toRemove.add(k);
            }
        }
        for (var j = 0; j < toRemove.size(); j += 1) { _peers.remove(toRemove[j]); }
    }

    function getPeerCount(maxAgeMs as Number) as Number {
        prune(maxAgeMs);
        return (_peers.keys().size() as Number);
    }

    function getGroupAverage(includeSelf as Boolean, maxPeerAgeMs as Number) as Float or Null {
        prune(maxPeerAgeMs);
        var sum = 0.0f;
        var count = 0.0f;
        var keys = _peers.keys();
        var now = System.getTimer();
        for (var i = 0; i < keys.size(); i += 1) {
            var rec = _peers[keys[i]] as PeerRec;
            if ((now - rec.ts) <= maxPeerAgeMs) {
                sum += (rec.hr as Float);
                count += 1.0f;
            }
        }
        if (includeSelf && _myHr != null) { sum += ((_myHr as Numeric) as Float); count += 1.0f; }
        if (count == 0.0f) { return null; }
        return sum / count;
    }

    // Returns { :id => peerId, :hr => Numeric, :initials => String?, :z2 => Number? } or null
    // excludeSelfId: if provided, exclude this peer ID from results
    function getTopPeer(maxAgeMs as Number, excludeSelfId as String or Number or Null) as Dictionary or Null {
        prune(maxAgeMs);
        var now = System.getTimer();
        var keys = _peers.keys();
        var bestId = null;
        var bestHr = -1.0f;
        var bestIni = null;
        var bestZ2 = null;
        for (var i = 0; i < keys.size(); i += 1) {
            var k = keys[i];
            // Skip if this is the excluded self ID
            if (excludeSelfId != null && k.equals(excludeSelfId)) { continue; }
            var rec = _peers[k] as PeerRec;
            if ((now - rec.ts) <= maxAgeMs) {
                var hrf = (rec.hr as Float);
                if (hrf > bestHr) { bestHr = hrf; bestId = k; bestIni = rec.initials; bestZ2 = rec.z2; }
            }
        }
        if (bestId == null) { return null; }
        var out = { :id => bestId, :hr => bestHr, :initials => bestIni } as Dictionary;
        if (bestZ2 != null) { out[:z2] = bestZ2; }
        return out;
    }

    // Returns array of up to 'limit' peers sorted by HR desc, items are { :id, :hr, :initials?, :z2? }
    // excludeSelfId: if provided, exclude this peer ID from results
    function getTopPeers(maxAgeMs as Number, limit as Number, excludeSelfId as String or Number or Null) as Array {
        prune(maxAgeMs);
        var now = System.getTimer();
        var keys = _peers.keys();
        var ids = [];
        var hrs = [];
        var inis = [];
        var z2s = [];
        for (var i = 0; i < keys.size(); i += 1) {
            var k = keys[i];
            // Skip if this is the excluded self ID
            if (excludeSelfId != null && k.equals(excludeSelfId)) { continue; }
            var rec = _peers[k] as PeerRec;
            if ((now - rec.ts) <= maxAgeMs) {
                ids.add(k);
                hrs.add(rec.hr);
                inis.add(rec.initials);
                z2s.add(rec.z2);
            }
        }
        var out = [];
        var take = limit;
        if (take > hrs.size()) { take = hrs.size(); }
        for (var n = 0; n < take; n += 1) {
            var bestIdx = -1;
            var bestHr = -1.0f;
            for (var j = 0; j < hrs.size(); j += 1) {
                var hrf = ((hrs[j] as Numeric) as Float);
                if (hrf > bestHr) { bestHr = hrf; bestIdx = j; }
            }
            if (bestIdx >= 0) {
                var item = { :id => ids[bestIdx], :hr => hrs[bestIdx], :initials => inis[bestIdx] } as Dictionary;
                if (z2s[bestIdx] != null) { item[:z2] = z2s[bestIdx]; }
                out.add(item);
                ids.remove(bestIdx);
                hrs.remove(bestIdx);
                inis.remove(bestIdx);
                z2s.remove(bestIdx);
            } else {
                break;
            }
        }
        return out;
    }
}
