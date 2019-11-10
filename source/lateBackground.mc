using Toybox.Background;
using Toybox.System as Sys;
using Toybox.WatchUi as Ui;
using Toybox.Communications;
using Toybox.Application as App;
using Toybox.Time;
using Toybox.Time.Gregorian;

const ServerToken = "https://oauth2.googleapis.com/token";
const AuthUri = "https://accounts.google.com/o/oauth2/auth";
const ApiUrl = "https://www.googleapis.com/calendar/v3/calendars/";
const ApiCalendarUrl = "https://www.googleapis.com/calendar/v3/users/me/calendarList";
const Scopes = "https://www.googleapis.com/auth/calendar.events.readonly https://www.googleapis.com/auth/calendar.readonly";

(:background)
class lateBackground extends Toybox.System.ServiceDelegate {

	var code;

  	function initialize() {
		Sys.ServiceDelegate.initialize();
	}
	
    function onTemporalEvent() {
    	if (App.getApp().getProperty("code") == null) {
  			if (App.getApp().getProperty("access_code").equals("")) {
  				Background.exit(code);
  			}
  			code = {"access_code"=>App.getApp().getProperty("access_code")};
			Communications.makeWebRequest(
				$.ServerToken,
				{
					"client_secret"=>App.getApp().getProperty("client_secret"),
					"client_id"=>App.getApp().getProperty("client_id"),
					"redirect_uri" =>App.getApp().getProperty("redirect_uri"),
					"code"=>code.get("access_code"),
					"grant_type"=>"authorization_code"
				},
				{
					:method => Communications.HTTP_REQUEST_METHOD_POST
				},
				method(:handleAccessResponse)
			);
  		} else {
  			code = App.getApp().getProperty("code");
        	getAccessTokenFromRefresh(code.get("refresh_token"));
      	}
    }
    
    function handleAccessResponse(responseCode, data) {
    	if (responseCode == 200) {
			Sys.println("AUTHORIZATION COMPLETED");
			code = data;
			getCalendarData();
    	} else {
			Sys.println("AUTHORIZATION ERROR!!!");
			Sys.println(data);
			Background.exit(code);
    	}
    }
    
    function getCalendarData() {
    	Communications.makeWebRequest(
           $.ApiCalendarUrl,
           {
           	"maxResults"=>"20",
           	"fields"=>"items(id)"
           },
           {
               :method=>Communications.HTTP_REQUEST_METHOD_GET,
               :headers=>{ "Authorization"=>"Bearer " + code.get("access_token") }
           },
           method(:parseCalendarData)
       );
    }
    
    var calendar_size = 0;
    var id_list = [];
    function parseCalendarData(responseCode, data) {
    	var result_size = data.get("items").size();
		if (responseCode == 200) {
			var indexes = App.getApp().getProperty("calendar_indexes");
			//Sys.println(indexes);
			indexes = indexes.toCharArray();
			var index_list = [];
			var cn = "";
			for (var i = 0; i < indexes.size(); i++) {
				var c = indexes[i];
				if (c == ',') {
					if (cn.toNumber() <= result_size) {index_list.add(cn.toNumber());}
					cn = "";
				} else {
					cn += c;
				}
			}
			if (cn.toNumber() <= result_size) {index_list.add(cn.toNumber());}
			calendar_size = index_list.size();
			
			for (var d = 0; d < index_list.size(); d++) {
				id_list.add(data.get("items")[index_list[d]-1].get("id"));
			}
			repeater();
		} else {
			Background.exit(_code());
		}
      }

    var current_index = 0;
	var hasNextPage = false;
    function repeater() {
  		if (current_index < calendar_size) {
			var today = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
			var sys_time = System.getClockTime();
			var UTCdelta = sys_time.timeZoneOffset < 0 ? sys_time.timeZoneOffset * -1 : sys_time.timeZoneOffset;
			var to = (UTCdelta/3600).format("%02d") + ":00";
			var sign = sys_time.timeZoneOffset < 0 ? "-" : "+";
			var dateStart = Lang.format(
				"$1$-$2$-$3$T$4$:$5$:00",
				[
					today.year,
					today.month,
					today.day,
					today.hour,
					today.min
				]
			);
			dateStart += sign + to;
			today = Gregorian.info(Time.now().add(new Time.Duration(3600*24)), Time.FORMAT_SHORT); 
			var dateEnd = Lang.format(
				"$1$-$2$-$3$T$4$:$5$:00",
			[
					today.year,
					today.month,
					today.day,
					today.hour,
					today.min
			]
			);
			dateEnd += sign + to;

			var options = {
				"maxResults"=>"4",
				"orderBy"=>"startTime",
				"singleEvents"=>"true",
				"timeMin"=>dateStart,
				"timeMax"=>dateEnd,
           		"fields"=>"nextPageToken,items(summary,location,start/dateTime,end/dateTime)"
			};
			if (hasNextPage) {
				options.put("pageToken", hasNextPage);
			}
			Sys.println(id_list[current_index] + " [" + current_index + "/" + calendar_size + "] :: nextPage => " + hasNextPage);

			Communications.makeWebRequest(
				$.ApiUrl + id_list[current_index] + "/events",
				options,
				{
					:method=>Communications.HTTP_REQUEST_METHOD_GET,
					:headers=>{ "Authorization"=>"Bearer " + code.get("access_token") }
				},
				method(:parseCalendarEventData)
			);
  		} else { // done
			var code_events = {
				"code"=>_code(),
				"events"=>encodeEvents(events_list)
			};
			try {
				Background.exit(code_events);
			} catch(ex) {
				Sys.println("bg ex: " + ex.getErrorMessage());
				Sys.println(ex.printStackTrace());
				code_events["events"] = events_list.size() ? events_list[0] : null;
				Background.exit(code_events);
			}
		}
	}

  	var events_list_size = 0;  
	var events_list = [];
    function parseCalendarEventData(responseCode, data) {
    	if(responseCode == 200) {
			for (var i = 0; i < data.get("items").size(); i++) {
				var event = data.get("items")[i];
				if(event["start"]) { // skip day events that have only "summary"
					try {
						var eventTrim = {
							"name"=>event.get("summary").substring(0,25),
							"location"=>event.get("location"),
							"start"=>event.get("start").get("dateTime"),
							"end"=>event.get("end").get("dateTime"), 
							"cal"=>current_index
						};
						//Sys.println(eventTrim);
						if(eventTrim["location"]) {  // trimming and event to fit the screen right 
							eventTrim["location"] = eventTrim["location"].substring(0,15);
							var split = eventTrim["location"].find(",");
							if(split && split>0){
								eventTrim["location"] = eventTrim["location"].substring(0,split);
							}
						}
						events_list.add(eventTrim);
						events_list_size += eventTrim.toString().length();

						//Sys.println([eventTrim["name"], eventTrim.toString().length(), events_list_size, code.toString().length()]);
					} catch(ex) {
						Sys.println("ex: " + ex.getErrorMessage());
						Sys.println( ex.printStackTrace());
					}
				}
			}
			if (data.get("nextPageToken")) {
				hasNextPage = data.get("nextPageToken");
			} else {
				hasNextPage = false;
				current_index++;
			}
			repeater();
      	} else { // no data
			try {
				Background.exit(_code());
			} catch(ex) {
				Background.exit(null);
			}
      	}
    }
    
    function getAccessTokenFromRefresh(refresh_token) {
		Communications.makeWebRequest(
			$.ServerToken,
			{
				"client_secret"=>App.getApp().getProperty("client_secret"),
				"client_id"=>App.getApp().getProperty("client_id"),
				"refresh_token"=>refresh_token,
				"grant_type"=>"refresh_token"
			},
			{
				:method => Communications.HTTP_REQUEST_METHOD_POST
			},
			method(:handleAccessResponseRefresh)
		);
    }
        
    function handleAccessResponseRefresh(responseCode, data) {
    	if (responseCode == 200) {
			data.put("refresh_token", code.get("refresh_token"));
			code = data;
			getCalendarData();
    	} else {
		  	Background.exit(_code());
    	}
    }

	function _code() {
		if (App.getApp().getProperty("code") == null) {
			return {"refresh_token"=>code.get("refresh_token")};
		}
		if (App.getApp().getProperty("code").hasKey("refresh_token")) {
			if (code.get("refresh_token") != App.getApp().getProperty("code").get("refresh_token")) {
				return {"refresh_token"=>code.get("refresh_token")};
			}
		}
		return {};
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

	function swap(data, x, y) {
        var tmp = data[x];
        data[x] = data[y];
        data[y] = tmp;
        return data;
    }

	function getDegree(time) {
		var dayDegrees = 3600*24.0/360;
		var deg = parseISODate(time).compare(Time.today())/dayDegrees;
		return deg.format("%03d");
	}

	function encodeEvents(object) {
		var res = "";

		//Sort
		if(object instanceof Toybox.Lang.Array) {
            for(var i=0; i<object.size()-1; i++){
                for (var j=0; j<object.size()-i-1; j++) {
                    var x = parseISODate(object[j].get("start"));
                    var y = parseISODate(object[j+1].get("start"));
                    if (x.greaterThan(y)) {
                        object = swap(object, j, j+1);
                    }
                }
            }
        }

		res += (object.size() > 1 ? 2 : 1) + "%";
		for (var i = 0; i < object.size(); i++) {
			var c = object[i];
			if (i < 2) {
				res += c.get("name") + "," + (c.get("location") ? c.get("location") : "") + ",";
			} else {
				break;
			}
		}
		for (var i = 0; i < object.size(); i++) {
			var c = object[i];
			if (i < 2) {
				var start = Gregorian.info(parseISODate(c.get("start")), Time.FORMAT_MEDIUM);
				res += Lang.format("$1$:$2$,", [start.hour.format("%02d"), start.min.format("%02d")]);
			} else {
				break;
			}
		}
		for (var i = 0; i < object.size(); i++) {
			var c = object[i];
			res += getDegree(c.get("start")) + "-";
			res += getDegree(c.get("end"));
			res += parseISODate(c.get("end")).value() >= Time.today().value()+3600*24 ? "t" : "x";
			if (i < object.size()-1) {
				res += ",";
			}
		}
		res += "/";
		for (var i = 0; i < object.size(); i++) {
			var c = object[i];
			res += c.get("cal");
			if (i < object.size()-1) {
				res += ",";
			}
		}
		var x = object.toString().length().toDouble();
		var y = res.length().toDouble();
		var compression = (((x-y)/x)*100).format("%.1f");
        Sys.println("Compression: " + compression + "%");
		return res;
	}
}