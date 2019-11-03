using Toybox.Application as App;
using Toybox.WatchUi as Ui;
using Toybox.Background;
using Toybox.System as Sys;
using Toybox.Time as Time;

class lateApp extends App.AppBase {

    var watch;

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state) { }

    function onStop(state) { }

    function onSettingsChanged() {
        watch.loadSettings();
        Ui.requestUpdate();
    }

    function getInitialView() {
    	var codes = Ui.loadResource(Rez.JsonData.credentials);
    	App.getApp().setProperty("client_id", codes.get("web").get("client_id"));
    	App.getApp().setProperty("client_secret", codes.get("web").get("client_secret"));
    	App.getApp().setProperty("redirect_uri", codes.get("web").get("redirect_uri"));
    	if(Toybox.System has :ServiceDelegate) {
    		var freq = App.getApp().getProperty("refresh_freq") * 60;
    		Background.registerForTemporalEvent(new Time.Duration(freq));
    	} else {
    		Sys.println("****background not available on this device****");
    	}
        return [new lateView()];
    }
    
    function onBackgroundData(data) {
    	if (data.hasKey("events")) {
    		App.getApp().setProperty("code", data.get("code"));
    		App.getApp().setProperty("events", data.get("events"));
    	} else {
			App.getApp().setProperty("code", data);
    	}
        Ui.requestUpdate();
    }    

    function getServiceDelegate() {
        return [new lateBackground()];
    }
    
}
