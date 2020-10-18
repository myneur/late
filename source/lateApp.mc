using Toybox.Application as App;
using Toybox.WatchUi as Ui;
using Toybox.Background;
using Toybox.System as Sys;
using Toybox.Time as Time;
using Toybox.Time.Gregorian as Calendar;
using Toybox.StringUtil as Str;
using Toybox.Weather as Weather;

class lateApp extends App.AppBase {

	var watch;
	var app;

	function initialize() {
		AppBase.initialize();
		app = App.getApp();
	}

	function onSettingsChanged() {
		watch.loadSettings();
		Ui.requestUpdate();
		loadSettings();
	}

	function loadSettings(){
		app.setProperty("calendar_ids", split(app.getProperty("calendar_ids")));	//?? how will it show in the properties?
	}

	function getInitialView() {
		watch = new lateView();
		return [watch];
	}

	(:data)
	function scheduleDataLoading(){
		///Sys.println("scheduling");
		loadSettings();

		if(watch.dataLoading && (watch.activity == :calendar || watch.showWeather)) {
			var nextEvent = durationToNextEvent();
			changeScheduleToMinutes(5);
			if(app.getProperty("refresh_token") == null){	///Sys.println("no auth");
				if(app.getProperty("user_code")){
					return promptLogin(app.getProperty("user_code"), app.getProperty("verification_url"));
				} else {
					var prompt = Ui.loadResource( Sys.getDeviceSettings().phoneConnected ? Rez.Strings.Wait4login : Rez.Strings.NotConnected );
					return ({"userPrompt"=>prompt, "error_code"=>511, "wait"=>nextEvent});
				}
			}  
		} else { // not supported by the watch
			return ({"userPrompt"=>Ui.loadResource(Rez.Strings.NotSupportedData), "error_code"=>501}); 
		}
		return true;
	}

	(:data)
	function durationToNextEvent(){
		var lastEvent = Background.getLastTemporalEventTime();
		//Sys.println("lastEvent: " + Time.now().compare(lastEvent));
		if (lastEvent==null){
			return 0;
		}
		else {
			var nextEvent = 6*Calendar.SECONDS_PER_MINUTE - Time.now().compare(lastEvent); 
			if(nextEvent<0){
				nextEvent = 0;
			}
			//Sys.println(nextEvent);
			return nextEvent;
		}
	}

	(:data)
	function promptLogin(user_code, url){
		///Sys.println([user_code, url]);
		return ({"userPrompt"=>url.substring(url.find("www.")+4, url.length()), "userContext"=>user_code, "permanent"=>true, "wait"=>durationToNextEvent()});
	}

	(:data)
	function changeScheduleToMinutes(minutes){
		Sys.println("changeScheduleToMinutes: "+minutes);
		return Background.registerForTemporalEvent(new Time.Duration( minutes * Calendar.SECONDS_PER_MINUTE));
	}

	(:data)
	function unScheduleDataLoading(){
		Background.deleteTemporalEvent();
	}
	
	(:data)
	function onBackgroundData(data) {
		Sys.println(Sys.getSystemStats().freeMemory+" onBackgroundData app+ "+(data.hasKey("weather")? "weather ":"")+(data.hasKey("subscription_id")?"subscription ":"")+(data.hasKey("events")?"events ":"")+(data.hasKey("refresh_token")?"token ":""));
		Sys.println(data);
		try {
			if(!(data instanceof Toybox.Lang.Dictionary)){
				return;
			}
			if(data.hasKey("subscription_id")){
					app.setProperty("subs", data["subscription_id"]);
					//System.println("saved "+data["subscription_id"]);
				}
			if(data.hasKey("weather") && data["weather"] instanceof Array){ // array with weaather forecast
				//System.println(["weather array ", data["weather"].size(), data["weather"]]);
				if(data["weather"].size()>2){
					var color;
					data["weather"][1] = Math.round( data["weather"][1].toFloat() ).toNumber(); // current temperature
					for(var i=2; i<data["weather"].size();i++){
						color = data["weather"][i];
						if(color<=9){color = 4;}	// snow: [freezing_rain_heavy-light, freezing_drizzle, ice_pellets_heavy-light, snow_heavy-light]
						else if(color==10){color=-1;}	// clouds: [flurries]
						else if(color<=13){color=3;}	// rain: [tstorm, rain_heavy, rain]
						else if(color<=15){color=2;}	// light rain: [rain_light, drizzle]
						else if(color<=19){color=-1;}	// clouds: [fog_light, fog, cloudy, mostly_cloudy]
						else if(color==20){color=1;}	// partly cloudy: [partly, cloudy]
						else if(color>=21){color=0;}	// sun: [clear, mostly_clear]
						data["weather"][i] = color;
					}
					//System.println(data["weather"]	);
					app.setProperty("weatherHourly", data["weather"]);
					
					/* // Garmin Weather API 12h
						var c;
						data = Weather.getCurrentConditions();
						Sys.println([data.observationLocationName, data.observationLocationPosition.toDegrees(), data.observationTime.value()]);
						data = Weather.getHourlyForecast();
						for(var j=0; j<data.size(); j++){
							c = data[j].condition;
							
							// https://developer.garmin.com/connect-iq/api-docs/Toybox/Weather.html
							if(c==Weather.CONDITION_FAIR || c==Weather.CONDITION_MOSTLY_CLEAR){c=1;} // Partly Cloudy 
							
							else if( c==Weather.CONDITION_LIGHT_RAIN || c==Weather.CONDITION_DRIZZLE || c==Weather.CONDITION_SHOWERS || c==Weather.CONDITION_HEAVY_SHOWERS ){c=4;} // Light rain 
							else if(c==Weather.CONDITION_THUNDERSTORMS || c==Weather.CONDITION_HEAVY_RAIN || c==Weather.CONDITION_RAIN_SNOW || c==Weather.CONDITION_TORNADO || 
							c==Weather.CONDITION_SANDSTORM || c==Weather.CONDITION_HURRICANE || c==Weather.CONDITION_TROPICAL_STORM || c==Weather.CONDITION_FREEZING_RAIN || 
							c==Weather.CONDITION_HEAVY_SHOWERS || c==Weather.CONDITION_SLEET){c=5;} // rain

							else if(c==Weather.CONDITION_SNOW || c>=Weather.CONDITION_LIGHT_SNOW && c<=Weather.CONDITION_HEAVY_RAIN_SNOW || c==Weather.CONDITION_ICE_SNOW || c==Weather.CONDITION_HAIL)
							{c=6;} // snow

							if(c>6){c=6;} // ignoring everything else
							data[j]=c;
						}
					data = {"weather"=>[13, 0].addAll(data)};*/
					changeScheduleToMinutes(app.getProperty("refresh_freq")); // once de data were loaded, continue with the settings interval
					app.setProperty("lastLoad", 'w');	// for background process to know the next time what was loaded to alternate between weather and calendar loading
				}
			}
			else {
				if(data.hasKey("refresh_token")){
					app.setProperty("refresh_token", data.get("refresh_token"));
					app.setProperty("user_code", null);
				}
				if (data.hasKey("primary_calendar")){
					app.setProperty("calendar_ids", [data["primary_calendar"]]);
				}
				if (data.hasKey("events")) {
					///Sys.println("dict events");
					data = parseEvents(data.get("events"));
					app.setProperty("events", data);
					if(!(app.getProperty("weather")==true)){
						changeScheduleToMinutes(5);	// load also weather as soon as possible
					} else {
						changeScheduleToMinutes(app.getProperty("refresh_freq")); // all loaded, wait for next data loading period 
					}
					app.setProperty("lastLoad", 'c'); // for background process to know the next time what was loaded to alternate between weather and calendar loading
				} 
				else if(data.hasKey("user_code")){ // prompt login
					app.setProperty("refresh_token", null); 
					app.setProperty("user_code", data.get("user_code")); 
					app.setProperty("verification_url", data.get("verification_url")); 
					app.setProperty("device_code", data.get("device_code")); 
					//app.setProperty("code_valid_till", new Time.now().value() + add(data.get("expires_in").toNumber()));
					changeScheduleToMinutes(5);
					data = promptLogin(data.get("user_code"), data.get("verification_url"));
				}
				else if(data.hasKey("error_code")){
					var error = data["error_code"];
					var connected = Sys.getDeviceSettings().phoneConnected;

					if(error==-300 || (error==404 && app.getProperty("lastLoad")=="c" && app.getProperty("refresh_token")!=null)){ // no internet
						return;
					}
					data["wait"] = durationToNextEvent();

					if(error==429){
						if(data.hasKey("msBeforeNext")){
							if(data["wait"]*1000 < data["msBeforeNext"]){
								data["wait"]=data["msBeforeNext"]/1000;
							}							
						}
						changeScheduleToMinutes(data["wait"]);
						} else {
						changeScheduleToMinutes(5);
					}

					/* if(error==511 ){ // login prompt on OAuth 
						Sys.println("login request");
						data["userPrompt"] = Ui.loadResource( connected ? Rez.Strings.Wait4login : Rez.Strings.NotConnected);
					} else */
				
					if(error == 404 ){  // no internet or not connected when logging in
						data["userPrompt"] = Ui.loadResource( connected ? Rez.Strings.NoInternet : Rez.Strings.NotConnected);
					} else if (error == -204){
						data["userPrompt"] = Ui.loadResource(Rez.Strings.NoGPS);
					}
					else if(data.hasKey("error")){	// when reason is passed from background
						///Sys.println(data["error"]);
						data["userPrompt"] = data["error"];
						data.put("permanent", true);
					} else if(error==400 || error==401 || error==403) { // general codes of not being authorized and not explained: invalid user_code || unauthorized || access denied
						///Sys.println("unauthorized");
						if(data.hasKey("subscription_id")){	// subscription is not in db: expired or wasn't paid at all
							app.setProperty("subscription_id", null);
							data["userPrompt"] = Ui.loadResource(error==400 ? Rez.Strings.Expired : Rez.Strings.Unauthorized);
						} else {
							app.setProperty("refresh_token", null);
							app.setProperty("user_code", null);
							data["userPrompt"] = Ui.loadResource(error==400 ? Rez.Strings.Expired : Rez.Strings.Unauthorized);
						}
					} else if(error==-403){
						data["userPrompt"] = Ui.loadResource(Rez.Strings.OutOfMemory);
					}
					else { // all other unanticipated errors
						data["userPrompt"] = Ui.loadResource(Rez.Strings.NastyError);
						data["userContext"] = data.get("error_code");
						data.put("permanent", true);
					}
				}
			}
			if(watch){
				watch.onBackgroundData(data);
			}
			Ui.requestUpdate();
		} catch (ex){
			///Sys.println("ex: " + ex.getErrorMessage());Sys.println( ex.printStackTrace());
			if(watch){
				watch.onBackgroundData({data["userPrompt"] => Ui.loadResource(Rez.Strings.NastyError)});
			}
		}
	}   

	(:data)
	function split(id_list){	
		if(id_list instanceof Toybox.Lang.String){
			// this really has to be that ugly, because monkey c cannot replace or split strings like human
			var i; 
			id_list = id_list.toCharArray();
			for(i=0;i<id_list.size();i++){
				if(id_list[i]=='[' || id_list[i]==']' || id_list[i]==',' || id_list[i]=='\"'){
					id_list[i] = ' ';
				}
			}
			id_list = Str.charArrayToString(id_list);
			
			
			var list = [];
			while(id_list.length()>1){
				i = id_list.find(" ");
				if(i != null){
					if(i>4){ // id must be at least 5 chars (can rise to 7)
						list.add(id_list.substring(0, i));
					}
					id_list = id_list.substring(i+1, id_list.length());
				} else {
					list.add(id_list);
					break;
				}
			}
			///Sys.println(list);
			return list;
		} else {
			return id_list;
		}
	}

	(:data)
	function getServiceDelegate() {
		return [new lateBackground()];
	}
	
	(:data)
	function swap(data, x, y) {
		var tmp = data[x];
		data[x] = data[y];
		data[y] = tmp;
		return data;
	}
	
	(:data)
	function parseEvents(data){
		var events_list = [];
		var dayDegrees = Calendar.SECONDS_PER_DAY.toFloat()/360;
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
				if(date!=null){
					events_list.add([
						date.value(),                                               // start
						parseISODate(data[i][1]).value(),                           // end
						data[i][2],                                                 // name
						data[i][3] ? ": " + data[i][3] : "",                        // location
						data[i][4],                                                 // calendar
						(date.compare(midnight)/dayDegrees).toFloat(),                          // degree start
						(parseISODate(data[i][1]).compare(midnight)/dayDegrees).toFloat()       // degree end
					]);
				}
			}
		}
		return(events_list);
	}

	// converts rfc3339 formatted timestamp to Time::Moment (null on error)
	(:data)
	function parseISODate(date) {
		// assert(date instanceOf String)

		// 0123456789012345678901234
		// 2011-10-17T13:00:00-07:00
		// 2011-10-17T16:30:55.000Z
		// 2011-10-17T16:30:55Z
		if (date.length() < 20) {
			return null;
		}

		var moment = Calendar.moment({
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
			tzOffset = suffix.substring(tz + 1, tz + 3).toNumber() * Calendar.SECONDS_PER_HOUR;
			tzOffset += suffix.substring(tz + 4, tz + 6).toNumber() * Calendar.SECONDS_PER_MINUTE;

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