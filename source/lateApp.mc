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
    		Background.registerForTemporalEvent(new Time.Duration(freq));
    	} else {
    		Sys.println("****background not available on this device****");
    	}
        watch = new lateView();
        return [watch];
    }
    
    function onBackgroundData(data) {
        try {
            if (data.hasKey("events")) {
                if (data.get("code").hasKey("refresh_token")) {
                    if (App.getApp().getProperty("code") == null) {
                        App.getApp().setProperty("code", data.get("code"));
                    } else if (data.get("code").get("refresh_token") != App.getApp().getProperty("code").get("refresh_token")) {
                        App.getApp().setProperty("code", data.get("code"));
                    }
                }

                var events = decodeEvents(data.get("events"));
                App.getApp().setProperty("events", events);
                if (watch) {
                    watch.onBackgroundData(events);
                }
            } else {
                if (data.hasKey("refresh_token")) {
                    if (App.getApp().getProperty("code") == null) {
                        App.getApp().setProperty("code", data);
                    } else if (data.get("refresh_token") != App.getApp().getProperty("code").get("refresh_token")) {
                        App.getApp().setProperty("code", data);
                    }
                }
            }
            Ui.requestUpdate();
        } catch (ex){
            return data;
        }
    }

    function decodeEvents(object) {
        var os = object.toString();
        var size = os.substring(0, 1).toNumber();

        var ci = 0;
        var state = 0;
        var rest = os.substring(os.find("%")+1, os.length());
        var data = [[], [], [], [], []];
        for (var i = 0; !rest.equals("");) {
            var part, next;
            rest = rest.substring(i, os.length());
            if (rest.find(",")) {
                next = rest.find(",");
                part = rest.substring(0, next);
                if (part.find("/")) {
                    next = rest.find("/");
                    part = rest.substring(0, next);
                }
                i = next+1;
            } else {
                try {
                    next = rest.find("/");
                    part = rest.substring(0, next);
                    i = next+1;
                } catch (ignored) {
                    part = rest;
                    rest = "";
                }
            }
            if (rest.find("/") == null) {
                state = 2;
            }
            if (ci < size) {
                if (state == 0) { //name
                    data[0].add(part);
                    state++;
                } else { //location
                    data[1].add(part);
                    state--;
                    ci++;
                }
            } else {
                if (state == 0) { //hour
                    if (data[0].size() > data[2].size()) {
                        data[2].add(part);
                    } else {
                        state++;
                    }
                }
                if (state == 1) { //degree
                    var tomorrow = false;
                    if (part.find("t") != null) {
                        tomorrow = true;
                    }
                    var degree = part.substring(0, part.length()-1);
                    data[3].add([
                        degree.substring(0, degree.find("-")),
                        degree.substring(degree.find("-")+1, degree.length()),
                        tomorrow
                    ]);
                }
                if (state == 2) { //cal index
                    data[4].add(part);
                }
            }
        }
        for (var i = 0; i < data[2].size(); i++) {
            var part = data[2][i];
            var sys_time = System.getClockTime();
            var UTCdelta = sys_time.timeZoneOffset < 0 ? sys_time.timeZoneOffset * -1 : sys_time.timeZoneOffset;
            var to = (UTCdelta/3600).format("%02d") + ":00";
            var sign = sys_time.timeZoneOffset < 0 ? "-" : "+";
            var date = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
            if (data[3][i][2]) {
                date = Gregorian.info(Time.now().add(new Time.Duration(3600*24)), Time.FORMAT_SHORT);
            }
            var start = Lang.format(
                "$1$-$2$-$3$T$4$:$5$:00",
                [
                    date.year,
                    date.month,
                    date.day,
                    part.substring(0, part.find(":")),
                    part.substring(part.find(":")+1, part.length())
                ]
            );
            start += sign + to;
            data[2][i] = start;
        }
        var events_list = [];
        for (var i = 0; i < data[3].size(); i++) {
            events_list.add({
                "name"=>data[0].size() > i ? data[0][i] : "", 
                "location"=>data[1].size() > i ? ": " + data[1][i] : "",
                "start"=>data[2].size() > i ? parseISODate(data[2][i]).value() : "",
                "tomorrow"=>data[3][i][2],
                "degreeStart"=>data[3][i][0], 
                "degreeEnd"=>data[3][i][1], 
                "cal"=>data[4][i]
            });
        }
        return events_list;
    }

    function getServiceDelegate() {
        return [new lateBackground()];
    }

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