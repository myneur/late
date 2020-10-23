using Toybox.Background;
using Toybox.System as Sys;
using Toybox.Communications;
using Toybox.Application as App;
using Toybox.Time;
using Toybox.Time.Gregorian;

const GoogleTokenUrl = "https://oauth2.googleapis.com/token";

(:background)
class lateBackground extends Toybox.System.ServiceDelegate {

	var access_token;
	var refresh_token;
	var current_index = -1;
	var calendar_ids;
	var events_list = [];
	var primary_calendar = false;
	var app;
	var maxResults = 7;
	var subscription_id;

	function initialize() {
		///Sys.println(Sys.getSystemStats().freeMemory + " on init");
		Sys.ServiceDelegate.initialize();
		//Communications.registerForOAuthMessages(method(:onPurchase));
		app = App.getApp();
	}
	
	function onTemporalEvent() {
		Sys.println(Sys.getSystemStats().freeMemory + " onTemporalEvent ");
		app = App.getApp();
		var connected = Sys.getDeviceSettings().phoneConnected;

		System.println("last: "+app.getProperty("lastLoad")+(app.getProperty("weather")?" weather ":"")+(app.getProperty("activity")==6 ?" calendar":""));
		if(app.getProperty("weather")==true && (app.getProperty("lastLoad")=='c' || app.getProperty("activity")!=6)){	// alternating between loading calendar and weather by what lateApp.onBackgroundData saved was loaded before
			getWeatherForecast();
		} else {
			if (app.getProperty("refresh_token") != null) { 
				//Sys.println("has refresh_token");
				refresh_token = app.getProperty("refresh_token");
				if(connected){
					refreshTokenAndGetData();
				}
			} else {
				if(connected){
					if (app.getProperty("user_code") == null){ // && new Moment(app.getProperty("code_valid_till").compare(Time.now()) < -10))  
						getOAuthUserCode();
					} else {  
						getTokensAndData();
					}
				} else {
					Background.exit({"error_code"=>404}); // no phone connection = no internet
				}
			}
		}
	}

	function getOAuthUserCode(){
		///Sys.println(Sys.getSystemStats().freeMemory + " getOAuthUserCode");
		//Sys.println([App.getApp().getProperty("client_id"), $.GoogleDeviceCodeUrl, $.GoogleScopes]);
		Communications.makeWebRequest("https://accounts.google.com/o/oauth2/device/code", 
			{"client_id"=>app.getProperty("client_id"), "scope"=>"https://www.googleapis.com/auth/calendar.readonly"}, {:method => Communications.HTTP_REQUEST_METHOD_POST}, 
			method(:onOAuthUserCode)); 
	}

	function onOAuthUserCode(responseCode, data){ // {device_code, user_code, verification_url}
		///Sys.println(Sys.getSystemStats().freeMemory + " onOAuthUserCode: "+responseCode); //Sys.println(data);
		if(responseCode != 200){
			if(data == null) { // no data connection 
				data = {"error_code"=>responseCode};
			} else {
				data.put("error_code", responseCode);
			}
		} /*else {
			showInstructionOnMobile(data);	// wasn't reliable, but if it gets reliable in the future, it would be better experience
		}*/
		Background.exit(data);  // prompt to login or show the error
	}

	function getTokensAndData(){ // device_code can tell if the user granted access
		//Sys.println(Sys.getSystemStats().freeMemory + " on getTokensAndData"); //Sys.println(app.getProperty("user_code"));
		//Sys.println([$.GoogleTokenUrl,app.getProperty("device_code"),app.getProperty("client_id"),app.getProperty("client_secret"),"http://oauth.net/grant_type/device/1.0"]);
		Communications.makeWebRequest($.GoogleTokenUrl, {"client_id"=>app.getProperty("client_id"), "client_secret"=>app.getProperty("client_secret"),
			"code"=>app.getProperty("device_code"), "grant_type"=>"http://oauth.net/grant_type/device/1.0"}, {:method => Communications.HTTP_REQUEST_METHOD_POST}, 
			method(:onTokenRefresh2GetData));
	}

	function onTokenRefresh2GetData(responseCode, data){
		///Sys.println(Sys.getSystemStats().freeMemory + " onTokenRefresh2GetData: "+responseCode); //Sys.println(data);
		if (responseCode == 200) {
			access_token = data.get("access_token");
			if(data.get("refresh_token")){
				refresh_token = data.get("refresh_token");
			}

			calendar_ids = app.getProperty("calendar_ids");
			//Sys.println(calendar_ids);
			if(calendar_ids == null || !(calendar_ids instanceof Toybox.Lang.Array) || calendar_ids.size()==0){ // because of [] and white-spaces
				getPrimaryCalendar();
			} 
			else {
				getNextCalendarEvents();
			}
		} 
		else {
			if(responseCode==428 || (responseCode == 400 && keyContains(data, "error", "authorization_pending"))){ 
				// polling for auth device user_code 428:{error=>authorization_pending, error_description=>Precondition Failed} || 400: {"error" : "authorization_pending","error_description": "Bad Request"}
				Background.exit({"user_code"=>app.getProperty("user_code"), "device_code"=>app.getProperty("device_code"), "verification_url"=>app.getProperty("verification_url")});
			} 
			else if(responseCode==403 || (responseCode == 400 && (keyContains(data, "error", "invalid_grant") || keyContains(data, "error", "expired_token")))){ 
				// 400: {error=> invalid_grant, error_description=> Token has been expired or revoked.} 
				//      {error=> expired_token, error_description=> Expired user code}
				// 403: {error=> access_denied, error_description=> Forbidden}
				getOAuthUserCode();
			} 
			else { 
				// 400: invalid_request || unsupported_grant_type
				// 401: invalid_client
				// 429: {error=> slow_down, error_description=>Rate Limit Exceeded}
				if(data==null){
					data = {"error_code"=>responseCode};
				} else {
					data.put("error_code", responseCode);
				}
				Background.exit(data);
			}
		}
	}

	function keyContains(dictionary, key, value){
		if(dictionary != null && dictionary instanceof Toybox.Lang.Dictionary){
			var val = dictionary.get(key);
			if(val != null){
				if(val.toString().find(value) != null){
					return true;
				}
			}
		}
		return false;
	}

	function getPrimaryCalendar(){
		///Sys.println(Sys.getSystemStats().freeMemory + " getPrimaryCalendar");
		Communications.makeWebRequest("https://www.googleapis.com/calendar/v3/users/me/calendarList",
			{"maxResults"=>"15", "fields"=>"items(id,primary)", "minAccessRole"=>"owner"/*, "showDeleted"=>false*/}, {:method=>Communications.HTTP_REQUEST_METHOD_GET, 
			:headers=>{ "Authorization"=>"Bearer " + access_token}},
			method(:onPrimaryCalendarCandidates));
	}

	function onPrimaryCalendarCandidates(responseCode, data) {  // expects calendar list already parsed to array
		///Sys.println(Sys.getSystemStats().freeMemory + " onPrimaryCalendarCandidates: "+responseCode);
		///Sys.println(data);
		if (responseCode == 200) {
			data = data.get("items");
			for(var i=0; i < data.size(); i++){
				if(data[i].get("primary") != null){
					primary_calendar = data[i].get("id");
					calendar_ids = [primary_calendar];
				}     
			}
			getNextCalendarEvents();
		} else {
			Background.exit({"error_code"=>responseCode});
		}
	}
		
	function getNextCalendarEvents() {
		current_index++;
		if (current_index<calendar_ids.size()) {
			///Sys.println(calendar_ids[current_index]);
			getEvents(calendar_ids[current_index]);
			return true;
		} else {
			return false;
		}
	}
	
	function getEvents(calendar_id) {
		///Sys.println(Sys.getSystemStats().freeMemory + " getCalendarData");
		var today = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
		var sys_time = System.getClockTime();
		var UTCdelta = sys_time.timeZoneOffset < 0 ? sys_time.timeZoneOffset * -1 : sys_time.timeZoneOffset;
		var to = (UTCdelta/3600).format("%02d") + ":00";
		var sign = sys_time.timeZoneOffset < 0 ? "-" : "+";

		var dateStart = Lang.format("$1$-$2$-$3$T$4$:$5$:00", [today.year, today.month, today.day, today.hour, today.min]);
		dateStart += sign + to;
		today = Gregorian.info(Time.now().add(new Time.Duration(3600*24)), Time.FORMAT_SHORT); 
		var dateEnd = Lang.format("$1$-$2$-$3$T$4$:$5$:00", [today.year, today.month, today.day, today.hour, today.min]);
		dateEnd += sign + to;

		calendar_id = Communications.encodeURL(calendar_id);
		
		//Sys.println($.GoogleCalendarEventsUrl + calendar_id + "/events");
		//Sys.println({"maxResults"=>"8", "orderBy"=>"startTime", "singleEvents"=>"true", "timeMin"=>dateStart, "timeMax"=>dateEnd, "fields"=>"items(summary,location,start/dateTime,end/dateTime)"});
		//Sys.println({"timeMin"=>dateStart, "timeMax"=>dateEnd});
		//Sys.println({:method=>Communications.HTTP_REQUEST_METHOD_GET, :headers=>{ "Authorization"=>"Bearer " + access_token }});

		/*Communications.makeWebRequest($.GoogleCalendarEventsUrl + calendar_id + "/events", {
			 "timeMin"=>dateStart, "timeMax"=>dateEnd}, {:method=>Communications.HTTP_REQUEST_METHOD_GET, :headers=>{ "Authorization"=>"Bearer " + access_token }},
			method(:onEvents));*/
		///Sys.println("maxResults: "+maxResults.toString());
		Communications.makeWebRequest("https://www.googleapis.com/calendar/v3/calendars/" + calendar_id + "/events", {
			"maxResults"=>maxResults.toString(), "orderBy"=>"startTime", "singleEvents"=>"true", "timeMin"=>dateStart, "timeMax"=>dateEnd, "fields"=>"items(summary,location,start/dateTime,end/dateTime)"}, {:method=>Communications.HTTP_REQUEST_METHOD_GET, 
				:headers=>{ "Authorization"=>"Bearer " + access_token }},
			method(:onEvents));
		// TODO optimize memory to load more events: if there are too many items (probably memory limit) onEvents gets -403 responseCode although the response is good
		//Sys.println(Sys.getSystemStats().freeMemory + " after loading " + calendar_id );
	}
	
	var events_list_size = 0;
	function onEvents(responseCode, data) {
		///Sys.println(Sys.getSystemStats().freeMemory +" onEvents: "+responseCode); 
		//Sys.println(data);
		if(responseCode == 200) { // TODO handle non 200 codes
			data = data.get("items");
			var eventsToSafelySend = primary_calendar ? 8 : 9;
			///Sys.println(Sys.getSystemStats().freeMemory + " events: "+ data.size());
			for (var i = 0; i < data.size() && events_list.size() < eventsToSafelySend; i++) { // 10 events not to get out of memory
				var event = data[i];
				data[i] = null;
				//if(events_list_size>500){break;}
				///Sys.println(Sys.getSystemStats().freeMemory+" "+i /*+" "+event["start"]["dateTime"]*/);
				if(event["start"]){ // skip day events that have only "summary"
					try {
						var eventTrim = [
							(event.get("start").get("dateTime")),
							(event.get("end").get("dateTime")), 
							i<= 3 ? (event.get("summary") ? event.get("summary").substring(0,25) : "") : "",
							i<= 3 ? event.get("location") : null,
							current_index
						];
						if(eventTrim[3]){  // trimming and event to fit the screen right 
							eventTrim[3] = eventTrim[3].substring(0,12);
							var split = eventTrim[3].find(",");
							if(split && split>0){
									eventTrim[3] = eventTrim[3].substring(0,split);
							}
						}
						events_list.add(eventTrim);
						events_list_size += eventTrim.toString().length();
						eventTrim = null;
						///Sys.println(Sys.getSystemStats().freeMemory);
						/*if(Sys.getSystemStats().freeMemory<4800){
							exitWithDataAndToken();
						}*/
					} catch(ex) {
						events_list = events_list.size() ? [events_list[0]] : null;
						///Sys.println("ex: " + ex.getErrorMessage()); Sys.println( ex.printStackTrace());
						exitWithDataAndToken(responseCode);
					}
				}
			}
		} else {
			if(responseCode==-403 || responseCode==-402){ // out of memory while parsing the response
				if(maxResults>2){
					maxResults-=2; // let's try to load smaller volume
					current_index--;	
				}
			}
		}
		if (!getNextCalendarEvents()) { // done
			if(events_list.size()>0){	// we tolerate if some loads did not work, but at least some of them must
				exitWithDataAndToken(200);
			} else{
				exitWithDataAndToken(responseCode);
			}
		} 
	}

	function exitWithDataAndToken(responseCode){ // TODO don't return events on errors
		///Sys.println("exitWithDataAndToken");
		var code_events = {"refresh_token"=>refresh_token};
		if(primary_calendar){
			code_events["primary_calendar"] = primary_calendar; 
		}
		try {  
			///Sys.println(Sys.getSystemStats().freeMemory +" before exit with "+ events_list.size() +" events taking "+events_list_size);
			///Sys.println(Sys.getSystemStats().freeMemory);
			if(responseCode==200){
				code_events.put("events", events_list);
			} else {
				code_events.put("error_code", responseCode);
			}
			///Sys.println(Sys.getSystemStats().freeMemory);
			Background.exit(code_events);
		} catch(ex) {
				///Sys.System.println("exc: "+Sys.getSystemStats().freeMemory+" "+ex);
				///Sys.println(Sys.getSystemStats().freeMemory);
				code_events["events"] = code_events["events"].size() ? [code_events["events"][0]] : null;
				///Sys.println(Sys.getSystemStats().freeMemory);
				Background.exit(code_events);
		}
	}
	
	function refreshTokenAndGetData() {
		Communications.makeWebRequest($.GoogleTokenUrl, {"client_secret"=>app.getProperty("client_secret"), "client_id"=>app.getProperty("client_id"), 
			"refresh_token"=>refresh_token, "grant_type"=>"refresh_token"}, {:method => Communications.HTTP_REQUEST_METHOD_POST},
			method(:onTokenRefresh2GetData));
	}

	function getWeatherForecast() {
		app = App.getApp();
		if(subscription_id==null){
			subscription_id = app.getProperty("subs");	// must be read at first call (which is this one) so we don't lose it
		}
		Sys.println(Sys.getSystemStats().freeMemory + " getWeatherForecast paid by: "+subscription_id);
		if(subscription_id instanceof String && subscription_id.length()>0){
			var pos = app.getProperty("location"); // load the last location to fix a Fenix 5 bug that is loosing the location often
			if(pos == null){
				Background.exit({"error_code"=>-204});
				return;
			}
			System.println("location: "+pos);
			//Sys.println("https://almost-late-middleware.herokuapp.com/api/"+pos[0].toFloat()+"/"+pos[1].toFloat()+"/"+{ "Authorization"=>"Bearer " + subscription_id });
			Communications.makeWebRequest("https://almost-late-middleware.herokuapp.com/api/"+pos[0].toFloat()+"/"+pos[1].toFloat(), 
				{"unit"=>(app.getProperty("units") ? "c":"f")}, 
				{:method => Communications.HTTP_REQUEST_METHOD_GET, :headers=>{ "Authorization"=>"Bearer " + subscription_id }},
				method(:onWeatherForecast));
		} else {
			getSubscriptionId();
		}
	}

	function onWeatherForecast(responseCode, data){	Sys.println(Sys.getSystemStats().freeMemory + " onWeatherForecast: "+responseCode ); Sys.println(data instanceof Array ? data.slice(0, 3)+"..." : data);
		if (responseCode==200) {
			try { 
				data = {"weather"=>data};	// returning array with the wheather forecast
				if(subscription_id instanceof String && subscription_id.length()>0){
					data.put("subscription_id", subscription_id);
				} 
			} catch(ex){
				Sys.System.println("exc: "+Sys.getSystemStats().freeMemory+" "+ex);
				data = (subscription_id instanceof String && subscription_id.length()>0) ? {"subscription_id"=>subscription_id} : {"weather"=>data};	// priority is to keep the subscription_id
			}
		} else {
			// 400: missing ID
			// 401 unknown device
			// 402 payment required
			// 404: no internet
			// 429 throttling with msBeforeNext to wait
			// 500 server error
			// 403 expired / 402 not paid yet with data like {msg=>Invalid subscriptionId!, code=>INV_SUBS_ID}  
			if(responseCode == 401){
				subscription_id = false;	// indicating to callBack that reason was expired subscription
	  		}
			if(responseCode>=401 && responseCode<=403 ){ 
				buySubscription(responseCode);
				return; // there will be a second call to exit
			}
			if(!(data instanceof Toybox.Lang.Dictionary)){
				data = {};
			}
			data.put("error_code", responseCode);
		}
		Background.exit(data);
	}

	function getSubscriptionId(){	System.println("getWeatherId");
		Communications.makeWebRequest("https://almost-late-middleware.herokuapp.com/auth/code",
			{"client_id"=>app.getProperty("weather_id")},  {:method=>Communications.HTTP_REQUEST_METHOD_GET},
			method(:onSubscriptionId));
	}
	
	function buySubscription(responseCode){	System.println("buySubscription "+responseCode);
		var data = {"device_code"=>subscription_id, "client_id"=>app.getProperty("weather_id")};
		if(responseCode!=200){
			data.put("expired", "1");
		}
		Communications.openWebPage("https://almost-late-middleware.herokuapp.com/checkout/" + (responseCode==407 ? "wait" : "pay"), 
			data, {:method=>Communications.HTTP_REQUEST_METHOD_GET}); 
		data = {"subscription_id"=>subscription_id};
		if(responseCode!=200){
			data.put("error_code", responseCode);
		}
		Background.exit(data);
		/*Communications.makeOAuthRequest("https://almost-late-middleware.herokuapp.com/auth/code?r=" + Math.rand(), {}, 
			"http://simplylate", Communications.OAUTH_RESULT_TYPE_URL, 
			{"subscription_id"=>"subscription_id", "responseCode" => "error_code", "responseError" => "error"});
		//Communications.makeOAuthRequest("https://almost-late-middleware.herokuapp.com/test?rand=" + Math.rand(), {}, 
			//"http://localhost/callback", Communications.OAUTH_RESULT_TYPE_URL, 
			//{"testval"=>"testval"});*/
	}


	/*function buySubscription(){
		System.println("buySubscription");
		Communications.makeOAuthRequest("https://almost-late-middleware.herokuapp.com/auth/code?r=" + Math.rand(), {}, 
			"http://simplylate", Communications.OAUTH_RESULT_TYPE_URL, 
			{"subscription_id"=>"subscription_id", "responseCode" => "error_code", "responseError" => "error"});
		//Communications.makeOAuthRequest("https://almost-late-middleware.herokuapp.com/test?rand=" + Math.rand(), {}, 
			//"http://localhost/callback", Communications.OAUTH_RESULT_TYPE_URL, 
			//{"testval"=>"testval"});
	}*/


	function onSubscriptionId(responseCode, data) {		Sys.println("onPurchase: " + responseCode +" "+data);
		if (responseCode == 200) {
			//data = data.get("items");
			if(data instanceof Toybox.Lang.Dictionary && data.hasKey("device_code") && data["device_code"] instanceof String ){ 
				Sys.System.println("have it: "+subscription_id);
				if(subscription_id == false){	// indicating to the subscriptino page that the subscription expired
					responseCode = 403;
				} 
				subscription_id = data["device_code"];
				buySubscription(responseCode); 
				return;
			} 
		} else {
			// 404: no internet
			// 407: No Quota
			// 429 throttling with msBeforeNext to wait
			// 500: Internal server error
			if(responseCode == 407){
				buySubscription(responseCode); 
				return;
			}
			if(!(data instanceof Toybox.Lang.Dictionary)){
				data = {};
			}
			data.put("subscription_id", subscription_id);
			data.put("error_code", responseCode);
		}
		Background.exit(data);
	}

	/*function onPurchase(message)  {
		Sys.println("onPurchase: " + message.data);
		if(message != null && message.data != null){
			if(message.data has :subscription_id && message.data["subscription_id"] != null && message.data["subscription_id"].length()>0){ // OK: 200 || 301
				Sys.println(message.data["subscription_id"]);
				subscription_id = message.data["subscription_id"];
				Background.exit({"subscription_id"=>subscription_id}); // Don’t request API immediately after success. It takes around 10-20 seconds for Stripe.com to make a request to our server.
				var error = message.data["error_code"];
			} else if(error==401 || error==403 || error==500){ 	// error interrupted probably won't propagate to the watch: //canceled or no internet/data => prompt to turn off // interupted subs: probably unreachable http://simplylate/?error=true =>
				buySubscription();
			}
			Background.exit(message.data); // error==429: throttling => returns msBeforeNext to wait
			return;
			// getWeatherForecast(); // The new event will call it for us, so we needn't to
		} 
		// no data means error: start again
		buySubscription();
		Background.exit(message.data); 
	}*/

/*  function showInstructionOnMobile(data){
		var user_code = data.hasKey("user_code") ? data["user_code"] : app.getProperty("user_code");
		var verification_url = data.hasKey("verification_url") ? data["verification_url"] : app.getProperty("verification_url");

		Communications.makeOAuthRequest("https://sl8.ch/how-to-load-calendar", 
			{"verification_url"=>verification_url, "user_code"=>user_code, "client_secret"=>app.getProperty("client_secret")}, 
			"http://localhost", Communications.OAUTH_RESULT_TYPE_URL, 
			{"refresh_token"=>"refresh_token", "calendar_ids"=>"calendar_ids"});
		//Communications.openWebPage(url, params, options);
	}*/
}