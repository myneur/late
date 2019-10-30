using Toybox.Background;
using Toybox.System as Sys;
using Toybox.WatchUi as Ui;
using Toybox.Communications;
using Toybox.Application as App;
using Toybox.Time;
using Toybox.Time.Gregorian;

const ClientId = "*";
const ClientSecret = "*";
const ServerToken = "https://oauth2.googleapis.com/token";
const AuthUri = "https://accounts.google.com/o/oauth2/auth";
const ApiUrl = "https://www.googleapis.com/calendar/v3/calendars/";
const CalendarId = "*";
const RequestUrl = ApiUrl + CalendarId + "/events";
const RedirectUri = "http://localhost";

(:background)
class lateBackground extends Toybox.System.ServiceDelegate {
	var code = "";

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
    
    function parseCalendarData(responseCode, data) {
		if (responseCode == 200) {
			var events = [];
			for (var i = 0; i < data.get("items").size(); i++) {
				var event = data.get("items")[i];
				var eventTrim = {
					"name"=>event.get("summary"),
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
    
    function getCalendarData() {
    	var today = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
		var dateString = Lang.format(
		    "$1$-$2$-$3$T00:00:00Z",
		    [
		        today.year,
		        today.month,
		        today.day
		    ]
		);
 		Communications.makeWebRequest(
           $.RequestUrl,
           {
           	"maxResults"=>"10",
           	"orderBy"=>"startTime",
           	"singleEvents"=>"true",
           	"timeMin"=>dateString
           },
           {
               :method=>Communications.HTTP_REQUEST_METHOD_GET,
               :headers=>{ "Authorization"=>"Bearer " + code.get("access_token") }
           },
           method(:parseCalendarData)
       );
    }
    
    function handleAccessResponse(responseCode, data) {
    	if (responseCode == 200) {
	       code = data;
	       getCalendarData();
	       Background.exit(code);
    	} else {
			Background.exit(code);
    	}
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
    
    function getAccessTokenFromRefresh(refresh_token) {
       Communications.makeWebRequest(
           $.ServerToken,
           // POST parameters
           {
               "client_secret"=>$.ClientSecret,
               "client_id"=>$.ClientId,
               "refresh_token"=>refresh_token,
               "grant_type"=>"refresh_token"
           },
           {
               :method => Communications.HTTP_REQUEST_METHOD_POST
           },
           method(:handleAccessResponseRefresh)
       );
    }
    
    function getAccessToken(accessCode) {
       code = accessCode.data["value"];
       Communications.makeWebRequest(
           $.ServerToken,
           // POST parameters
           {
               "client_secret"=>$.ClientSecret,
               "client_id"=>$.ClientId,
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
    
    function initOAuth() {
       Communications.makeOAuthRequest(
           $.AuthUri,
           // POST parameters
           {
               "client_id"=> $.ClientId,
               "response_type"=>"code",
               "scope"=> Communications.encodeURL("https://www.googleapis.com/auth/calendar.events.readonly"),
               "redirect_uri"=> $.RedirectUri
           },
           $.RedirectUri,
           Communications.OAUTH_RESULT_TYPE_URL,
           {"code"=>"value"});
    }

    function draw(dc) {
        // Set the background color then call to clear the screen
        dc.setColor(Graphics.COLOR_TRANSPARENT, Application.getApp().getProperty("BackgroundColor"));
        dc.clear();
    }

}
