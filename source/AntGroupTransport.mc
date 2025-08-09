import Toybox.Ant;
import Toybox.Lang;
import Toybox.System;

class AntGroupTransport {
    const DEVICE_TYPE = 31; // arbitrary app-defined device type
    const RF_FREQ = 57;     // 2457 MHz
    const PERIOD = 8192;    // ~4Hz

    var _tx as Ant.GenericChannel or Null;
    var _rx as Ant.GenericChannel or Null;
    var _groupCode as Number;
    var _selfId as Number; // 0..65535
    var _seq as Number;
    var _onReceive as Lang.Method or Null;

    function initialize(groupCode as Number, selfId as Number, onReceive as Lang.Method or Null) {
        _groupCode = groupCode;
        _selfId = (selfId % 65535) as Number; // session-stable id provided by app
        _seq = 0;
        _onReceive = onReceive;
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
        data[5] = (_seq & 0xFF);
        data[6] = 0;
        data[7] = 0;
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
        if (_onReceive != null) {
            (_onReceive as Lang.Method).invoke({ :group => g, :peerId => peerId, :hr => hr });
        }
    }
}
