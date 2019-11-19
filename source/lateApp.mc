using Toybox.Application as App;
using Toybox.WatchUi as Ui;
using Toybox.Background;
using Toybox.System as Sys;
using Toybox.Time as Time;
using Toybox.Time.Gregorian;

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
//freq = freq * 24; // testing inflence of data loading on battery
    		Background.registerForTemporalEvent(new Time.Duration(freq));
    	} else {
    		Sys.println("****background not available on this device****");
    	}
        watch = new lateView();
        return [watch];
    }
    
    function onBackgroundData(data) {
        Sys.println("data");
    	try{
            if (data.hasKey("events")) {
                var events = parseEvents(data.get("events"));
        		App.getApp().setProperty("code", data.get("code"));
        		App.getApp().setProperty("events", events);
                if(watch){
                    watch.onBackgroundData(events);
                }
Background.registerForTemporalEvent(new Time.Duration(120*60)); 
        	} else {
    			App.getApp().setProperty("code", data);
        	}
            Ui.requestUpdate();
        } catch (ex){
            Sys.println("ex: " + ex.getErrorMessage());
            Sys.println( ex.printStackTrace());
            return;
        }
    }    

    function getServiceDelegate() {
        return [new lateBackground()];
    }
    
    function swap(data, x, y) {
        var tmp = data[x];
        data[x] = data[y];
        data[y] = tmp;
        return data;
    }
    
    function parseEvents(data){
        var events_list = [];
        var dayDegrees = 3600*24.0/360;
        var midnight = Time.today();
        
        
        if(data instanceof Toybox.Lang.Array) {
            for(var i=0; i<data.size()-1; i++){
                for (var j=0; j<data.size()-i-1; j++) {
                    var x = parseISODate(data[j][0]);
                    var y = parseISODate(data[j+1][0]);
                    if (x.greaterThan(y)) {
                        data = swap(data, j, j+1);
                    }
                }
            }
        }
        
        if(data instanceof Toybox.Lang.Array) { 
            for(var i=0; i<data.size() ;i++){
                var date = parseISODate(data[i][0]);
                //Sys.println(data[i]);
                if(date!=null){
                    events_list.add([
                        date.value(),                                               // start
                        parseISODate(data[i][1]).value(),                           // end
                        data[i][2],                                                 // name
                        data[i][3] ? ": " + data[i][3] : "",                        // location
                        data[i][4],                                                 // calendar
                        date.compare(midnight)/dayDegrees,                          // degree start
                        parseISODate(data[i][1]).compare(midnight)/dayDegrees       // degree end
                    ]);
                }
            }
        }
        return(events_list);
    }

    // converts rfc3339 formatted timestamp to Time::Moment (null on error)
    function parseISODate(date) {
        // assert(date instanceOf String)

        // 0123456789012345678901234
        // 2011-10-17T13:00:00-07:00
        // 2011-10-17T16:30:55.000Z
        // 2011-10-17T16:30:55Z
        if (date.length() < 20) {
            return null;
        }

        var moment = Gregorian.moment({
            :year => date.substring( 0, 4).toNumber(),
            :month => date.substring( 5, 7).toNumber(),
            :day => date.substring( 8, 10).toNumber(),
            :hour => date.substring(11, 13).toNumber(),
            :minute => date.substring(14, 16).toNumber(),
            :second => date.substring(17, 19).toNumber()
        });
        var suffix = date.substring(19, date.length());

        // skip over to time zone
        var tz = 0;
        if (suffix.substring(tz, tz + 1).equals(".")) {
            while (tz < suffix.length()) {
                var first = suffix.substring(tz, tz + 1);
                if ("-+Z".find(first) != null) {
                    break;
                }
                tz++;
            }
        }

        if (tz >= suffix.length()) {
            // no timezone given
            return null;
        }
        var tzOffset = 0;
        if (!suffix.substring(tz, tz + 1).equals("Z")) {
            // +HH:MM
            if (suffix.length() - tz < 6) {
                return null;
            }
            tzOffset = suffix.substring(tz + 1, tz + 3).toNumber() * Gregorian.SECONDS_PER_HOUR;
            tzOffset += suffix.substring(tz + 4, tz + 6).toNumber() * Gregorian.SECONDS_PER_MINUTE;

            var sign = suffix.substring(tz, tz + 1);
            if (sign.equals("+")) {
                tzOffset = -tzOffset;
            } else if (sign.equals("-") && tzOffset == 0) {
                // -00:00 denotes unknown timezone
                return null;
            }
        }
        return moment.add(new Time.Duration(tzOffset));
    }
}