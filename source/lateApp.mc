using Toybox.Application as App;
using Toybox.WatchUi as Ui;

class lateApp extends App.AppBase {
    var watch;

    function initialize() {
        AppBase.initialize();
    }

    function onSettingsChanged() {
        watch.loadSettings();
        Ui.requestUpdate();
    }

    function getInitialView() {
        watch = new lateView();
        return [watch];
    }
}
