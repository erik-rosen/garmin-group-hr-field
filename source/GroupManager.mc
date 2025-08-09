import Toybox.System;
import Toybox.Lang;

class PeerRec {
    var hr as Numeric;
    var ts as Number; // ms since app start
    function initialize(h as Numeric, t as Number) {
        hr = h;
        ts = t;
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

    function upsertPeer(peerId as String or Number, hr as Numeric) as Void {
        _peers[peerId] = new PeerRec(hr, System.getTimer());
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

    // Returns { :id => peerId, :hr => Numeric } or null
    function getTopPeer(maxAgeMs as Number) as Dictionary or Null {
        prune(maxAgeMs);
        var now = System.getTimer();
        var keys = _peers.keys();
        var bestId = null;
        var bestHr = -1.0f;
        for (var i = 0; i < keys.size(); i += 1) {
            var k = keys[i];
            var rec = _peers[k] as PeerRec;
            if ((now - rec.ts) <= maxAgeMs) {
                var hrf = (rec.hr as Float);
                if (hrf > bestHr) { bestHr = hrf; bestId = k; }
            }
        }
        if (bestId == null) { return null; }
        return { :id => bestId, :hr => bestHr };
    }

    // Returns array of up to 'limit' peers sorted by HR desc, items are { :id, :hr }
    function getTopPeers(maxAgeMs as Number, limit as Number) as Array {
        prune(maxAgeMs);
        var now = System.getTimer();
        var keys = _peers.keys();
        var ids = [];
        var hrs = [];
        for (var i = 0; i < keys.size(); i += 1) {
            var k = keys[i];
            var rec = _peers[k] as PeerRec;
            if ((now - rec.ts) <= maxAgeMs) {
                ids.add(k);
                hrs.add(rec.hr);
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
                out.add({ :id => ids[bestIdx], :hr => hrs[bestIdx] });
                ids.remove(bestIdx);
                hrs.remove(bestIdx);
            } else {
                break;
            }
        }
        return out;
    }
}
