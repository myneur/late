using Toybox.Application as App;
using Toybox.WatchUi as Ui;
using Toybox.Background;
using Toybox.System as Sys;
using Toybox.Communications;

var code="code";
var events="events";

(:background)
class lateApp extends App.AppBase {
    var watch;

    function initialize(){
        AppBase.initialize();
        var now=Sys.getClockTime();
    	var ts=now.hour+":"+now.min.format("%02d");
    	//you'll see this gets called in both the foreground and background        
        Sys.println("App initialize "+ts);
    }

    function onStart(state) { }

    function onStop(state) { }

    function onSettingsChanged(){
        watch.loadSettings();
        Ui.requestUpdate();
    }

    function getInitialView(){
   		//register for temporal events if they are supported
    	if(Toybox.System has :ServiceDelegate) {
    		Background.registerForTemporalEvent(new Time.Duration(50 * 60));
    	} else {
    		Sys.println("****background not available on this device****");
    	}
        return [ new lateView() ];
    }
    
    // BGBACK sends data here and BGAPP requests Ui update
    function onBackgroundData(data) {
    	if (data.hasKey("events")) {
    		App.getApp().setProperty(code,data.get("code"));
    		App.getApp().setProperty(events,data.get("events"));
    	} else {
			App.getApp().setProperty(code,data);
    	}
        Ui.requestUpdate();
    }    

	// BGAPP-MUST
    function getServiceDelegate(){
        return [new lateBackground()];
    }
}
