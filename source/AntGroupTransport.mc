import Toybox.Ant;
import Toybox.Lang;
import Toybox.System;

class AntGroupTransport {
    const DEVICE_TYPE = 31; // arbitrary app-defined device type
    const RF_FREQ = 57;     // 2457 MHz
    const PERIOD = 8192;    // ~4Hz
    const ALPHA = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"; // for initials mapping

    var _tx as Ant.GenericChannel or Null;
    var _rx as Ant.GenericChannel or Null;
    var _groupCode as Number;
    var _selfId as Number; // 0..65535
    var _seq as Number;
    var _onReceive as Lang.Method or Null;
    var _ini1 as Number; // 0..25 index for first initial
    var _ini2 as Number; // 0..25 index for second initial
    var _hasIni as Boolean;
    var _z2 as Number or Null; // Zone 2 threshold (1..255) or null if unset

    function initialize(groupCode as Number, selfId as Number, onReceive as Lang.Method or Null, initials as String or Null) {
        _groupCode = groupCode;
        _selfId = (selfId % 65535) as Number; // session-stable id provided by app
    _seq = 0;
        _onReceive = onReceive;
        // Map initials to two indices 0..25; default to AA
        _ini1 = 0; _ini2 = 0; _hasIni = false;
        setInitials(initials);
    _z2 = null;
    }

    // Update initials at runtime; pass null or invalid to clear
    function setInitials(initials as String or Null) as Void {
        _hasIni = false;
        _ini1 = 0; _ini2 = 0;
        if (initials == null) { return; }
        var s = (initials as String).toUpper();
        if (s.length() >= 2) {
            var c1 = s.substring(0, 1);
            var c2 = s.substring(1, 1);
            var i1 = ALPHA.find(c1);
            var i2 = ALPHA.find(c2);
            if (i1 >= 0 && i1 < 26 && i2 >= 0 && i2 < 26) {
                _ini1 = i1 as Number;
                _ini2 = i2 as Number;
                _hasIni = true;
            }
        }
    }

    function getSelfId() as Number { return _selfId; }

    function start() as Void {
        // TX channel (Master)
        var txAssign = new Ant.ChannelAssignment(Ant.CHANNEL_TYPE_TX_NOT_RX, Ant.NETWORK_PUBLIC);
        _tx = new Ant.GenericChannel(method(:_onAntMessage), txAssign);
        var txCfg = new Ant.DeviceConfig({
            :deviceNumber => _selfId,
            :deviceType => DEVICE_TYPE,
            :transmissionType => 1,
            :messagePeriod => PERIOD,
            :radioFrequency => RF_FREQ,
            :searchTimeoutLowPriority => 0,
            :searchThreshold => 0
        });
        (_tx as Ant.GenericChannel).setDeviceConfig(txCfg);
        (_tx as Ant.GenericChannel).open();

        // RX channel (Background scan)
        var rxAssign = new Ant.ChannelAssignment(Ant.CHANNEL_TYPE_RX_ONLY, Ant.NETWORK_PUBLIC);
        rxAssign.setBackgroundScan(true);
        _rx = new Ant.GenericChannel(method(:_onAntMessage), rxAssign);
        var rxCfg = new Ant.DeviceConfig({
            :deviceType => DEVICE_TYPE,
            :messagePeriod => PERIOD,
            :radioFrequency => RF_FREQ,
            :searchTimeoutLowPriority => 12, // up to 30s, but background scan stays active
            :searchThreshold => 0
        });
        (_rx as Ant.GenericChannel).setDeviceConfig(rxCfg);
        (_rx as Ant.GenericChannel).open();
    }

    function stop() as Void {
        if (_tx != null) { (_tx as Ant.GenericChannel).close(); (_tx as Ant.GenericChannel).release(); _tx = null; }
        if (_rx != null) { (_rx as Ant.GenericChannel).close(); (_rx as Ant.GenericChannel).release(); _rx = null; }
    }

    function sendHr(hr as Number or Null) as Void {
        if (_tx == null || hr == null) { return; }
        var hrByte = hr;
        if (hrByte < 0) { hrByte = 0; }
        if (hrByte > 255) { hrByte = 255; }
        var data = new [8];
        data[0] = (_groupCode & 0xFF);
        data[1] = ((_groupCode >> 8) & 0xFF);
        data[2] = (_selfId & 0xFF);
        data[3] = ((_selfId >> 8) & 0xFF);
        data[4] = hrByte;
        // Byte 5 carries Zone 2 threshold (1..255). 0 means 'no threshold'.
        var z2b = 0;
        if (_z2 != null) {
            z2b = (_z2 as Number);
            if (z2b < 0) { z2b = 0; }
            if (z2b > 255) { z2b = 255; }
        }
        data[5] = z2b;
        // Pack initials as indices offset by +1 (1..26). 0 means 'no initials' for backward compatibility.
        if (_hasIni) {
            data[6] = (_ini1 + 1);
            data[7] = (_ini2 + 1);
        } else {
            data[6] = 0;
            data[7] = 0;
        }
        _seq = (_seq + 1) % 256;

        var msg = new Ant.Message();
        msg.setPayload(data);
        (_tx as Ant.GenericChannel).sendBroadcast(msg);
    }

    // ANT message listener
    function _onAntMessage(msg as Ant.Message) as Void {
        // Attempt to parse payload
        var payload;
        try { payload = msg.getPayload(); } catch(e) { return; }
        if (payload == null || payload.size() < 8) { return; }
        var g = (payload[0] as Number) | ((payload[1] as Number) << 8);
        if (g != _groupCode) { return; }
        var peerId = (payload[2] as Number) | ((payload[3] as Number) << 8);
        if (peerId == _selfId) { return; }
        var hr = payload[4] as Number;
        var z2 = payload[5] as Number;
        // Decode initials if provided (0..25 indices)
        var i1 = payload[6] as Number;
        var i2 = payload[7] as Number;
        var initials = null;
        // Decode with -1 offset; treat 0 as 'no initials'
        if (i1 > 0 && i1 <= 26 && i2 > 0 && i2 <= 26) {
            var di1 = (i1 - 1) as Number;
            var di2 = (i2 - 1) as Number;
            initials = ALPHA.substring(di1, 1) + ALPHA.substring(di2, 1);
        }
        if (_onReceive != null) {
            var dict = { :group => g, :peerId => peerId, :hr => hr, :initials => initials } as Dictionary;
            if (z2 > 0 && z2 <= 255) { dict[:z2] = z2; }
            (_onReceive as Lang.Method).invoke(dict);
        }
    }

    // Update Zone 2 threshold to be transmitted (1..255), or null to clear
    function setZone2Threshold(z2 as Number or Null) as Void {
        if (z2 == null) { _z2 = null; return; }
        var n = z2 as Number;
        if (n <= 0) { _z2 = null; return; }
        if (n > 255) { n = 255; }
        _z2 = n;
    }
}
