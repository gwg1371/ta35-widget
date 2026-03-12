import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

class TA35App extends Application.AppBase {

    private var _view as TA35View;

    function initialize() {
        AppBase.initialize();
        _view = new TA35View();
    }

    function onStart(state as Dictionary?) as Void {
    }

    function onStop(state as Dictionary?) as Void {
        _view.stopTimer();
    }

    function getInitialView() as [WatchUi.Views] or [WatchUi.Views, WatchUi.InputDelegates] {
        return [_view];
    }
}
