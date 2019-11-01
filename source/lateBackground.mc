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
const RedirectUri = "http://localhost";

(:background)
class lateBackground extends Toybox.System.ServiceDelegate {

	var code;

    function initialize() {
		Sys.ServiceDelegate.initialize();
    	Communications.registerForOAuthMessages(method(:getAccessToken));
	}
	
    function onTemporalEvent() {
		if (App.getApp().getProperty("code") == null) {
			initOAuth();
		} else {
			code = App.getApp().getProperty("code");
	        getAccessTokenFromRefresh(code.get("refresh_token"));
        }
    }
    
    function initOAuth() {
       Communications.makeOAuthRequest(
           $.AuthUri,
           {
               "client_id"=>App.getApp().getProperty("client_id"),
               "response_type"=>"code",
               "scope"=>Communications.encodeURL($.Scopes),
               "redirect_uri"=>$.RedirectUri
           },
           $.RedirectUri,
           Communications.OAUTH_RESULT_TYPE_URL,
           {"code"=>"value"});
    }
    
    function getAccessToken(accessCode) {
       code = accessCode.data["value"];
       Communications.makeWebRequest(
           $.ServerToken,
           {
               "client_secret"=>App.getApp().getProperty("client_secret"),
               "client_id"=>App.getApp().getProperty("client_id"),
               "redirect_uri" => $.RedirectUri,
               "code"=>accessCode.data["value"],
               "grant_type"=>"authorization_code"
           },
           {
               :method => Communications.HTTP_REQUEST_METHOD_POST
           },
           method(:handleAccessResponse)
       );
    }
    
    function handleAccessResponse(responseCode, data) {
    	if (responseCode == 200) {
	       code = data;
	       getCalendarData();
    	} else {
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
    
    function parseCalendarData(responseCode, data) {
		if (responseCode == 200) {
			getCalendarEventData(data.get("items")[App.getApp().getProperty("calendar_index")-1].get("id"));
      //getCalendarEventData(data.get("items")[6].get("id"));
    	} else {
    		Background.exit(code);
    	}
    }
    
    function getCalendarEventData(calendar_id) {
    	var today = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
		var dateStart = Lang.format(
		    "$1$-$2$-$3$T$4$:$5$:00Z",
		    [
		        today.year,
		        today.month,
		        today.day,
		        today.hour,
		        today.min
		    ]
		);
    today = Gregorian.info(Time.now().add(new Time.Duration(3600*24*4)), Time.FORMAT_SHORT); 
		var dateEnd = Lang.format(
		    "$1$-$2$-$3$T23:59:59Z",
		    [
		        today.year,
		        today.month,
		        today.day
		    ]
		);
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
    
    function parseCalendarEventData(responseCode, data) {
		if (responseCode == 200) {
			var events = [];
			for (var i = 0; i < data.get("items").size(); i++) {
				var event = data.get("items")[i];
				var eventTrim = {
					"name"=>event.get("summary"),
					"location"=>event.get("location"),
					"start"=>event.get("start").get("dateTime"),
					"end"=>event.get("end").get("dateTime")
				};
				events.add(eventTrim);
			}
			var code_events = {
				"code"=>code,
				"events"=>events
			};
	    	Background.exit(code_events);
    	} else {
    		Background.exit(code);
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
