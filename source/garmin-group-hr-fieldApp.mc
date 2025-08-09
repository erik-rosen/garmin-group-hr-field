import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;
import Toybox.System;

class garmin_group_hr_fieldApp extends Application.AppBase {
    var groupHeartRates as Dictionary = {};
    var myHeartRate as Number or Null = null;
    var mView as garmin_group_hr_fieldView or Null;

    function initialize() {
        AppBase.initialize();
        // Communications APIs are not available for this app type on this device.
        // Messaging/broadcast will be handled in the View if supported by the platform.
    }

    // onStart() is called on application start up
    function onStart(state as Dictionary or Null) as Void {
        AppBase.onStart(state);
    }

    // onStop() is called when your application is exiting
    function onStop(state as Dictionary?) as Void {
    }

    //! Return the initial view of your application here
    function getInitialView() as [Views] or [Views, InputDelegates] {
        mView = new garmin_group_hr_fieldView();
        return [ mView as Views ];
    }
}

function getApp() as garmin_group_hr_fieldApp {
    return Application.getApp() as garmin_group_hr_fieldApp;
}