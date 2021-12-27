using Toybox.Background;
using Toybox.System as Sys;
using Toybox.Communications;
using Toybox.Application as App;
using Toybox.Time;
using Toybox.Time.Gregorian;

(:background)
class lateBackground extends Toybox.System.ServiceDelegate {

	var access_token;
	var refresh_token;
	var current_index = -1;
	var calendar_ids;
	var events_list = [];
	var primary_calendar = false;
	var app;
	//var maxResults = Toybox.Application has :Storage ? 6 : 5;
	var maxResults = 6;
	var subscription_id;

	function initialize() { ///Sys.println(Sys.getSystemStats().freeMemory + " on init");
		Sys.ServiceDelegate.initialize();
		//Communications.registerForOAuthMessages(method(:onPurchase));
		app = App.getApp();
	}
	
	function onTemporalEvent() {	//+*/var t = Gregorian.info(Time.now(), Gregorian.FORMAT_SHORT); Sys.println( t.hour +":" +t.min + ": " + Sys.getSystemStats().freeMemory + " onTemporalEvent, last: "+ app.getProperty("lastLoad") );
		app = App.getApp();
		//Sys.println(["onTemporalEvent " , app.getProperty("user_code"),app.getProperty("refresh_token")]);
		//+*/Sys.println("last: "+app.getProperty("lastLoad")+(app.getProperty("weather")?" weather ":"")+(app.getProperty("activity")==6 ?" calendar":""));
		//+*/Sys.println([app.getProperty("user_code"), app.getProperty("refresh_token"),app.getProperty("device_code")]);
		if(app.getProperty("weather")==true && (app.getProperty("lastLoad")=='c' || app.getProperty("activity")!=6)){	// alternating between loading calendar and weather by what lateApp.onBackgroundData saved was loaded before
			getWeatherForecast();
		} else {
			if(Sys.getDeviceSettings().phoneConnected==true){
				getTokensAndData();
			} else {
				if(app.getProperty("refresh_token") == null){
					Background.exit({"error_code"=>404}); // no phone connection = no internet
				}
			}
		}
	}

	function getOAuthUserCode(){	///Sys.println(Sys.getSystemStats().freeMemory + " getOAuthUserCode"); Sys.println("getOAuthUserCode");
		Communications.makeWebRequest("https://accounts.google.com/o/oauth2/device/code", 
			{"client_id"=>app.getProperty("Ggl_id"), "scope"=>"https://www.googleapis.com/auth/calendar.readonly"}, {:method => Communications.HTTP_REQUEST_METHOD_POST}, 
			method(:onOAuthUserCode)); 
	}

	function onOAuthUserCode(responseCode, data){ // {device_code, user_code, verification_url} ///Sys.println(Sys.getSystemStats().freeMemory + " onOAuthUserCode: "+responseCode); //Sys.println(data);
		if(responseCode != 200){
			if(data == null) { // no data connection 
				data = {};
			} 
			data.put("error_code", responseCode);
		} /*else { showInstructionOnMobile(data);	// wasn't reliable, but if it gets reliable in the future, it would be better experience }*/
		Background.exit(data);  // prompt to login or show the error
	}

	function getTokensAndData(){  ///Sys.println(Sys.getSystemStats().freeMemory + " on getTokensAndData");  // device_code can tell if the user granted access 
		var params = {"client_secret"=>app.getProperty("Ggl_secret"), "client_id"=>app.getProperty("Ggl_id")};
		if (app.getProperty("refresh_token") != null) { 
			refresh_token = app.getProperty("refresh_token");
			params.put("refresh_token",refresh_token);
			params.put("grant_type","refresh_token");
		} else {
			if (app.getProperty("user_code") == null){ // && new Moment(app.getProperty("code_valid_till").compare(Time.now()) < -10))  
				
				getOAuthUserCode();
				return;
			} else { 
				params.put("code",app.getProperty("device_code"));
				params.put("grant_type","http://oauth.net/grant_type/device/1.0");
			}
		}
		Communications.makeWebRequest("https://oauth2.googleapis.com/token", params, {:method => Communications.HTTP_REQUEST_METHOD_POST}, 
			method(:onTokenRefresh2GetData));
	}

	function onTokenRefresh2GetData(responseCode, data){	///Sys.println("onTokenRefresh2GetData: "+responseCode); Sys.println(data);
		if (responseCode == 200) {
			access_token = data.get("access_token");
			if(data.get("refresh_token")){
				refresh_token = data.get("refresh_token");
			}

			calendar_ids = app.getProperty("calendar_ids");
			//Sys.println(calendar_ids);
			if(calendar_ids == null || !(calendar_ids instanceof Toybox.Lang.Array) || calendar_ids.size()==0){ // because of [] and white-spaces
				getPrimaryCalendar();
			} else {
				getNextCalendarEvents();
			}
		} 
		else {
			if(responseCode==428 || (responseCode == 400 && keyContains(data, "error", "authorization_pending"))){ 
				// polling for auth device user_code 428:{error=>authorization_pending, error_description=>Precondition Failed} || 400: {"error" : "authorization_pending","error_description": "Bad Request"}
				Background.exit({"user_code"=>app.getProperty("user_code"), "device_code"=>app.getProperty("device_code"), "verification_url"=>app.getProperty("verification_url")});
			} 
			else if(responseCode==403 
				|| (responseCode == 400 && (keyContains(data, "error", "invalid_grant") || keyContains(data, "error", "expired_token")))
				|| (responseCode == 401 && (keyContains(data, "error", "unauthorized_client")))
				){ 
				// 400: {error=> invalid_grant, error_description=> Token has been expired or revoked.} 
				//      {error=>invalid_grant, error_description=>Bad Request}				
				// 401: invalid_client // probably renewed client_id/client_secret
				//      {error=>unauthorized_client, error_description=>Unauthorized} // client_id + client_secret changed
				//      {error=> expired_token, error_description=> Expired user code}
				//      {error=>invalid_client, error_description=>Unauthorized} // client_secret
				//		{error=>invalid_client, error_description=>The OAuth client was not found.}	// client_id changed
				// 403: {error=> access_denied, error_description=> Forbidden}
				getOAuthUserCode();
			} 
			else { 
				// 400: invalid_request || unsupported_grant_type
				// 429: {error=> slow_down, error_description=>Rate Limit Exceeded}
				onOAuthUserCode(responseCode, data); // returning the error same way 
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

	function getPrimaryCalendar(){	///Sys.println(Sys.getSystemStats().freeMemory + " getPrimaryCalendar");
		Communications.makeWebRequest("https://www.googleapis.com/calendar/v3/users/me/calendarList",
			{"maxResults"=>"15", "fields"=>"items(id,primary)", "minAccessRole"=>"owner"/*, "showDeleted"=>false*/}, {:method=>Communications.HTTP_REQUEST_METHOD_GET, 
			:headers=>{ "Authorization"=>"Bearer " + access_token}},
			method(:onPrimaryCalendarCandidates));
	}

	function onPrimaryCalendarCandidates(responseCode, data) {  // expects calendar list already parsed to array ///Sys.println(Sys.getSystemStats().freeMemory + " onPrimaryCalendarCandidates: "+responseCode); ///Sys.println(data);
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
		if (current_index<calendar_ids.size()) { ///Sys.println(calendar_ids[current_index]);
			getEvents(calendar_ids[current_index]);
			return true;
		} else {
			return false;
		}
	}

// DEBUG MEM //var m=Sys.getSystemStats().freeMemory;function mem(label){Sys.println([Sys.getSystemStats().freeMemory, Sys.getSystemStats().freeMemory-m, label]); m=Sys.getSystemStats().freeMemory;}
// DEBUG MEM BALAST //var balast = new [460];

	function getEvents(calendar_id) { 	//+mem+*/Sys.println(Sys.getSystemStats().freeMemory + " getCalendarData "+ calendar_id);
// DEBUG MEM //mem("getEvents max "+maxResults/*+" with balast "+balast.size()*/);
// DEBUG MEM //mem("getEvents "+calendar_id);
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
// DEBUG MEM //mem("request vars " + Sys.getSystemStats().freeMemory/maxResults + " per item "+maxResults);


/*while(maxResults>1 && (Sys.getSystemStats().freeMemory-2000)/(maxResults-1)<600){
	Sys.println("maxResults down to "+(Sys.getSystemStats().freeMemory-2000)/(maxResults-1)+" downto =>"+maxResults + " = "+(Sys.getSystemStats().freeMemory-2000)/(maxResults-2));
	maxResults=maxResults-1;
}*/
		Communications.makeWebRequest("https://www.googleapis.com/calendar/v3/calendars/" + calendar_id + "/events", {
			"maxResults"=>maxResults.toString(), "orderBy"=>"startTime", "singleEvents"=>"true", "timeMin"=>dateStart, "timeMax"=>dateEnd, "fields"=>"items(summary,location,start/dateTime,end/dateTime)"}, {:method=>Communications.HTTP_REQUEST_METHOD_GET, 
				:headers=>{ "Authorization"=>"Bearer " + access_token }},
			method(:onEvents));
// DEBUG MEM //mem("requested");
		// TODO optimize memory to load more events: if there are too many items (probably memory limit) onEvents gets -403 responseCode although the response is good
		///*/ln(Sys.getSystemStats().freeMemory + " after loading " + calendar_id );
	}
	
	function onEvents(responseCode, data) {	//+mem+*/Sys.println(Sys.getSystemStats().freeMemory +" onEvents: "+responseCode + ", max: "+maxResults); //Sys.println(data);
// DEBUG MEM //mem("onEvents "+responseCode);
		if(responseCode == 200) { // TODO handle non 200 codes
			data = data.get("items");
// DEBUG MEM //mem("events: "+data.size());
			var event;
			//var eventsToSafelySend = primary_calendar ? 7 : 8;
			//var limit = Toybox.Application has :Storage ? 12 : 9;
			var limit = 11;
//Sys.println(data.size());
			for (var i = 0; i < data.size() && events_list.size() < limit; i++) { // limit events not to get out of memory
				//+mem+*/Sys.println(Sys.getSystemStats().freeMemory+" "+i /*+" "+event["start"]["dateTime"]*/);
				event = data[i];
//Sys.println(event);
				data[i] = null;
				if(event["start"]){ // skip day events that have only "summary"
					try {
						var eventTrim = [
							(event.get("start").get("dateTime")),
							(event.get("end").get("dateTime")), 
							i<= 3 ? (event.get("summary") ? event.get("summary").substring(0,23) : "") : "",
							i<= 3 ? event.get("location") : null,
							current_index
						];
						if(eventTrim[3]){  // trimming and event to fit the screen nicely
							eventTrim[3] = eventTrim[3].substring(0,10);
							var split = eventTrim[3].find(",");
							if(split && split>0){
								eventTrim[3] = eventTrim[3].substring(0,split);
							}
						}
						events_list.add(eventTrim);
						/*if(Sys.getSystemStats().freeMemory<4800){
							exitWithDataAndToken();
						}*/
					} catch(ex) {
// DEBUG MEM //mem("catch onEvents");
						events_list = events_list.size() ? [events_list[0]] : null;
						//+mem+*/Sys.println("ex: " + ex.getErrorMessage()); Sys.println( ex.printStackTrace());
// DEBUG MEM //mem("catch onEvents cleaned");
						exitWithDataAndToken(responseCode);
// DEBUG MEM //mem("catch onEvents exited");
					}
				}
			}
//Sys.println(events_list.size());
			maxResults = limit-events_list.size(); // TODO limit must not exceed maxResults
			// DEBUG MEM //mem("limiting results to " +maxResults + " with events loaded: "+ events_list.size());
			//Sys.println(data.size()+" "+events_list.size()+"/"+limit);
		} else {
			if(responseCode==-403 || responseCode==-402){ // out of memory while parsing the response
				if(maxResults>1){
					maxResults=1; // let's try to load smaller volume
// DEBUG MEM //mem("maxResults=1: "+maxResults);
					current_index--; // it never helped to load the same calendar with not even a one item for some reason: 
				}
			}
		}
		if (!getNextCalendarEvents() || maxResults==0) { // done
			if(events_list.size()>0){	// we tolerate if some loads did not work, but at least some of them must
				exitWithDataAndToken(200);
			} else{
				exitWithDataAndToken(responseCode);
			}
		} 
// DEBUG MEM //mem("onEvents done "+events_list.size());
	}

	function exitWithDataAndToken(responseCode){ //Sys.println("exitWithDataAndToken"); // TODO don't return events on errors 
// DEBUG MEM //mem("exitWithDataAndToken "+responseCode);
		var code_events = {"refresh_token"=>refresh_token};
		if(primary_calendar){
			code_events["primary_calendar"] = primary_calendar; 
		}
// DEBUG MEM //mem("exitWithDataAndToken primary calendar "+primary_calendar + " events "+events_list.size());
		try {  
			if(responseCode==200){
				/*if(Toybox.Application has :Storage && events_list!=null && events_list.size()>1){ // try passing through storage if there's a risk of running out of memory
					try {
						Toybox.Application.Storage.setValue("events", events_list); 
						code_events.put("events", true)	;
					} catch(ex) { //Sys.println("excs: "+Sys.getSystemStats().freeMemory+" "+ex.getErrorMessage()); Sys.println( ex.printStackTrace() ); // catch background storage save failure or out of memory
						code_events.put("events", events_list);
					}
				} else {	// pass by exit if no storage or small enough */
					code_events.put("events", events_list);
				//}
			} else {
				code_events.put("error_code", responseCode);
			}
			//Sys.println(Sys.getSystemStats().freeMemory +" exiting with "+events_list.size());
			refresh_token=null; access_token=null; calendar_ids=null; events_list=null;// cleaning memory before exiting not to reach out of memory
			//+mem+*/Sys.println(Sys.getSystemStats().freeMemory +" exiting");
// DEBUG MEM //mem("exitWithDataAndToken try exit ");
			Background.exit(code_events);
// DEBUG MEM //mem("exitWithDataAndToken exited ");

		} catch(ex) { //Sys.println("exc: "+Sys.getSystemStats().freeMemory+" "+ex.getErrorMessage()); Sys.println( ex.printStackTrace() );
// DEBUG MEM //mem("exitWithDataAndToken catch ");
				code_events["events"] = (code_events["events"] instanceof Array && code_events["events"].size()) ? [code_events["events"][0]] : null;
// DEBUG MEM //mem("exitWithDataAndToken catch cleaned");
				Background.exit(code_events);
// DEBUG MEM //mem("exitWithDataAndToken catch exited");
		}
	}

	function getWeatherForecast() {
		var pos = app.locate(false);
		if(pos == null){
			app.getProperty("location"); // load the last location to fix a Fenix 5 bug that is loosing the location often
		}
		//Sys.println("getWeatherForecast: "+pos);
		if(pos == null){
			Background.exit({"error_code"=>-204});
			return;
		}
		if(subscription_id==null){
			subscription_id = app.getProperty("subs");	// must be read at first call (which is this one) so we don't lose it
		}
		var hours = (app.getProperty("d24") == 1 ? 24:12);
		//+//System.println(Sys.getSystemStats().freeMemory + " getWeatherForecast paid by: "+subscription_id);
		//Sys.println("https://almost-late-middleware.herokuapp.com/api/"+pos[0].toFloat()+"/"+pos[1].toFloat());
		if(subscription_id instanceof String && subscription_id.length()>0){
			// STAGING */Communications.makeWebRequest("https://almost-late-middleware-staging.herokuapp.com/api/"+pos[0].toFloat()+"/"+pos[1].toFloat(), 
			/* OLD PROD */Communications.makeWebRequest("https://almost-late-middleware.herokuapp.com/api/"+pos[0].toFloat()+"/"+pos[1].toFloat(), 
			// NEW PROD not working yet */Communications.makeWebRequest("https://subscription.sl8.ch/api/"+pos[0].toFloat()+"/"+pos[1].toFloat(), 
				{"unit"=>(app.getProperty("units") ? "c":"f"), 
					"service"=>"yrno", // app.getProperty("provider") ? "climacell":"yrno"
					"period_w"=>(hours+1),
					"period_p"=>hours,
					"period_t"=>16
				}, 
				{	:method => Communications.HTTP_REQUEST_METHOD_GET, 
					:headers=>{ 
						"Authorization"=>"Bearer " + subscription_id, 
						"Accept-Version" => "v2",
						"X-Device-Identifier" => Sys.getDeviceSettings().uniqueIdentifier
						}, 

					},
				method(:onWeatherForecast));
		} else {
			getSubscriptionId();
		}
	}

	function onWeatherForecast(responseCode, data){		//+*/Sys.println(Sys.getSystemStats().freeMemory + " onWeatherForecast: "+responseCode ); Sys.println(data instanceof Array ? data.slice(0, 8)+"..." : data);
		if (responseCode==200) {
			try { 
				//Sys.println(data);
				for(var i=1 ; i<=3; i++){ // round temperatures
					if(data[i] != null){
						data[i] = Math.round( data[i].toFloat() ).toNumber(); // current temperature	
					}
				}
				data = {"weather"=>data};	// returning array with the wheather forecast
				if(subscription_id instanceof String && subscription_id.length()>0){
					data.put("subscription_id", subscription_id);
				} 
			} catch(ex){
				//Sys.System.println("exc: "+Sys.getSystemStats().freeMemory+" "+ex);
				data = (subscription_id instanceof String && subscription_id.length()>0) ? {"subscription_id"=>subscription_id} : {"weather"=>data};	// priority is to keep the subscription_id
			}
		} else {
			// 400: missing ID
			// 401 unknown device
			// 402 payment required
			// 403 expired / 402 not paid yet with data like {msg=>Invalid subscriptionId!, code=>INV_SUBS_ID}  
			// 404: no internet
			// 429 throttling with msBeforeNext to wait
			// 500 server errors
			if(responseCode==401){
				subscription_id = false;
				getSubscriptionId();
				return;
			} 
			if(responseCode==402 || responseCode==403 ){ 
				buySubscription(responseCode);	// response code will indicate to show expiration page instead of subsription
				return; // there will be a second call to exit
			}
			if(!(data instanceof Toybox.Lang.Dictionary)){
				data = {};
			}
			data.put("error_code", responseCode);
		}
		Background.exit(data);
	}

	function getSubscriptionId(){	//+*/System.println("getSubscriptionId");
		//Communications.makeWebRequest("https://almost-late-middleware-staging.herokuapp.com/auth/code",
		Communications.makeWebRequest("https://subscription.sl8.ch/auth/code",
			{"client_id"=>app.getProperty("Weather_id")},  
				{	:method=>Communications.HTTP_REQUEST_METHOD_GET, 
					:headers=> {"X-Device-Identifier" => Sys.getDeviceSettings().uniqueIdentifier}
					},
			method(:onSubscriptionId));
	}
	
	function buySubscription(responseCode){	//+*/System.println("buySubscription "+responseCode);
		var data = {"device_code"=>subscription_id};
		if(responseCode==403){ // especially 401: handle as expiration?
			data.put("expired", "1");
		}
		data.put("r", Math.rand().toString());
		//Sys.println(["https://almost-late-middleware.herokuapp.com/" + (responseCode==407 ? "waitlist" : "checkout/pay"), data]);
		//Communications.openWebPage("https://almost-late-middleware-staging.herokuapp.com/" + (responseCode==407 ? "waitlist" : "checkout/pay"), 
		Communications.openWebPage("https://subscription.sl8.ch/" + (responseCode==407 ? "waitlist" : "checkout/pay"), 
			data, 
			{	:method=>Communications.HTTP_REQUEST_METHOD_GET, 
				:headers=> {"X-Device-Identifier" => Sys.getDeviceSettings().uniqueIdentifier}
				}); 
		data = {"subscription_id"=>subscription_id};
		if(responseCode!=200){
			data.put("error_code", responseCode);
		}
		Background.exit(data);
	}

	function onSubscriptionId(responseCode, data) {		//+*/Sys.println("onPurchase: " + responseCode +" "+data);
		if (responseCode == 200) {
			//data = data.get("items");
			if(data instanceof Toybox.Lang.Dictionary && data.hasKey("device_code") && data["device_code"] instanceof String ){ 
				//Sys.System.println("have it: "+subscription_id);
				if(subscription_id == false){	// indicating to the subscriptino page that the subscription expired
					responseCode = 403;
				} 
				subscription_id = data["device_code"];
				buySubscription(responseCode); 
				return;
			} 
		} else {
			// 400 TODO wrong client_id: {msg=>Incorrect device identification, code=>MISSING_ID}
			// 404: no internet
			// 405: device code expired
			// 407: No Quota
			// 429 throttling with msBeforeNext to wait
			// 500: Internal server error
			if(responseCode == 407 || responseCode == 405){
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
}