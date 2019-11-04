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
    var current_index = 0;
    var id_list = [];
    function parseCalendarData(responseCode, data) {
    	var result_size = data.get("items").size();
      Sys.println(data);
      if (responseCode == 200) {
  			var indexes = App.getApp().getProperty("calendar_indexes");
        Sys.println("calendar indexes to read: " + indexes);
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
      		Background.exit(code);
      	}
      }
      
      var in_progress = -1;
      function repeater() {
  		if (in_progress < current_index) {
  			in_progress++;
  			getCalendarEventData(id_list[current_index]);
  		}
    	
    }
    
    function getCalendarEventData(calendar_id) {
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
      Communications.makeWebRequest(
           $.ApiUrl + calendar_id + "/events",
           {
           	"maxResults"=>"6",
           	"orderBy"=>"startTime",
           	"singleEvents"=>"true",
           	"timeMin"=>dateStart,
           	"timeMax"=>dateEnd,
           	"fields"=>"items(summary,location,start/dateTime,end/dateTime)"
           },
           {
               :method=>Communications.HTTP_REQUEST_METHOD_GET,
               :headers=>{ "Authorization"=>"Bearer " + code.get("access_token") }
           },
           method(:parseCalendarEventData)
       );
    }
    
	var events_list = [];
    function parseCalendarEventData(responseCode, data) {
    	if(responseCode == 200) {
  			for (var i = 0; i < data.get("items").size(); i++) {
  				var event = data.get("items")[i];
  				var eventTrim = {
  					"name"=>event.get("summary").substring(0,25),
  					"location"=>event.get("location"),
  					"start"=>event.get("start").get("dateTime"),
  					"end"=>event.get("end").get("dateTime")
  				};
          if(eventTrim["location"]){  // trimming and event to fit the screen right 
            eventTrim["location"] = eventTrim["location"].substring(0,15);
            var split = eventTrim["location"].find(",");
            if(split && split>0){
                eventTrim["location"] = eventTrim["location"].substring(0,split);
            }
          }
          events_list.add(eventTrim);
  			}
  			if (current_index == calendar_size-1) {
  				var code_events = {
  					"code"=>code,
  					"events"=>events_list
  				};
  				Background.exit(code_events);
  			} else {
  				current_index++;
  			}
  			repeater();
      	} else {
  			var code_events = {
  				"code"=>code,
  				"events"=>events_list
  			};
      		Background.exit(code_events);
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
		   Background.exit(code);
    	}
    }
}
