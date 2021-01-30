using Toybox as Toy;
using Toybox.WatchUi as Ui;
using Toybox.Background;
using Toybox.System as Sys;
using Toybox.Time as Time;
using Toybox.StringUtil as Str;
//using Toybox.Weather as Weather;

class lateApp extends Toy.Application.AppBase {

	var watch;
	var app;
	//var locateAtTimer;

	function initialize() {
		AppBase.initialize();
		app = Toy.Application.getApp();
	}

	function onSettingsChanged() {
		if(watch!=null){
			watch.loadSettings();
			Ui.requestUpdate();
		}
		loadSettings();
	}

	function loadSettings(){
		app.setProperty("calendar_ids", split(app.getProperty("calendar_ids")));	
	}

	function getInitialView() {
		watch = new lateView();
		return [watch];
	}

	(:data)
	function scheduleDataLoading(){
		//+System.println("scheduling: " + [watch.dataLoading , watch.activity == :calendar , watch.showWeather]);
		loadSettings();
		if(watch.dataLoading && (watch.activity == :calendar || watch.showWeather)) {
			var nextEvent = durationToNextEvent();
			changeScheduleToMinutes(5);
			if(watch.activity == :calendar && app.getProperty("refresh_token") == null){	//////Sys.println("no auth");
				if(app.getProperty("user_code")){
					return promptLogin(app.getProperty("user_code"), app.getProperty("verification_url"));
				} else {
					var prompt = Ui.loadResource( Sys.getDeviceSettings().phoneConnected ? Rez.Strings.Wait4login : Rez.Strings.NotConnected );
					return ({"userPrompt"=>prompt, "error_code"=>511, "wait"=>nextEvent});
				}
			}  
			if(watch.showWeather && app.getProperty("subs") == null){
				var pos = app.getProperty("location"); // load the last location to fix a Fenix 5 bug that is loosing the location often
				var data = {"error_code"=>511, "wait"=>nextEvent};
				if(pos == null){
					data["userPrompt"] = Ui.loadResource(Rez.Strings.NoGPS);
					data["userContext"] = Ui.loadResource(Rez.Strings.HowGPS);
					data.put("permanent", true);
					
				} else {
					data.put("userPrompt", Ui.loadResource( Sys.getDeviceSettings().phoneConnected ? Rez.Strings.Subscribe : Rez.Strings.NotConnected ));
				}
				return (data);
			}
		} else { // not supported by the watch
			return ({"userPrompt"=>Ui.loadResource(Rez.Strings.NotSupportedData), "error_code"=>501}); 
		}
		return true;
	}

	(:data)
	function durationToNextEvent(){
		var lastEvent = Background.getLastTemporalEventTime();
		/////Sys.println("lastEvent: " + Time.now().compare(lastEvent));
		if (lastEvent==null){
			return 0;
		}
		else {
			var nextEvent = 360 - Time.now().compare(lastEvent); // 6*SECONDS_PER_MINUTE
			if(nextEvent<0){
				nextEvent = 0;
			}
			/////Sys.println(nextEvent);
			return nextEvent;
		}
	}

	(:data)
	function promptLogin(user_code, url){
		//////Sys.println([user_code, url]);
		return ({"userPrompt"=>url.substring(url.find("www.")+4, url.length()), "userContext"=>user_code, "permanent"=>true, "wait"=>durationToNextEvent()});
	}

	(:data)
	function changeScheduleToMinutes(minutes){
		///Sys.println("changeScheduleToMinutes: "+minutes);
		var duration = new Time.Duration( minutes * 60);
		/*if(locateAtTimer != null){
			locateAtTimer.stop();
		}
		locateAtTimer = new Toy.Timer.Timer().start(method(:decoy), duration.subtract(new Time.Duration(60)), true); // locate a minute before */
		//locateAt = Time.now().add(duration).subtract(new Time.Duration(180));
		return Background.registerForTemporalEvent(duration); // * SECONDS_PER_MINUTE
	}

	(:data)
	function unScheduleDataLoading(){
		Background.deleteTemporalEvent();
	}
	
	(:data)
	function onBackgroundData(data) {	
		//+Sys.println(Sys.getSystemStats().freeMemory+" onBackgroundData app+ "+data.keys());
		//Sys.println(data);
		try {
			if(data instanceof Toybox.Lang.Dictionary){
				if(data.hasKey("subscription_id")){	
					app.setProperty("subs", data["subscription_id"]);
					if(watch!=null && watch.activity != :calendar){ // clearing the potential message
						watch.message = false;
					}
				}
				if(data.hasKey("weather") && data["weather"] instanceof Array){ // array with weaather forecast
					//System.println(data["weather"]);
					if(data["weather"].size()>2){
						//System.println(data);
						data["weather"][1] = Math.round( data["weather"][1].toFloat() ).toNumber(); // current temperature
						/*var c;
						for(var i=2; i<data["weather"].size();i++){
						c = data["weather"][i];
						// new yr.no if(c<8){c=0;}else if(c<12){c=1;}else if(c<36){c=2;}else if(c<73){c=3;}else if(c<79){c=4;}else if(c<98){c=5;}else {c=-1;}
						// climacell if(c<3){c=0;}else if(c<4){c=1;}else if(c<8){c=2;}else if(c<13){c=3;}else if(c<15){c=4;}else if(c<19){c=5;}else {c=-1;}
						// old climacell if(c<=9){c = 4;}	// snow: [freezing_rain_heavy-light, freezing_drizzle, ice_pellets_heavy-light, snow_heavy-light] else if(c==10){c=-1;}	// clouds: [flurries] else if(c<=13){c=3;}	// rain: [tstorm, rain_heavy, rain] else if(c<=15){c=2;}	// light rain: [rain_light, drizzle] else if(c<=19){c=-1;}	// clouds: [fog_light, fog, cloudy, mostly_cloudy] else if(c==20){c=1;}	// partly cloudy: [partly, cloudy] else if(c>=21){c=0;}	// sun: [clear, mostly_clear] */
						/* old yrno if(c>=24&&c<28){c=1;}	// partly else if((c>=48&&c<52) || (c>=33&&c<37)){c=0;}	// clear else if(c==23 || c==45){c=-1;} // cloudy else if(c==28 || c==32 || c==38 || (c>=41&&c<46) || c==52 || (c<=58&&c>62) || c==83 || (c>=91&&c<99)){c=4;} // snow else if(c<19 || c==31 || c==37 || c==40 || c==47 || (c>=62&&c<66) || c==70 || (c>=79&&c<83) || c==99){c=3;} // rain else {c=2;} // light rain data["weather"][i] = c;*/
						//System.println(data["weather"]	);
						app.setProperty("weatherHourly", data["weather"]);
						changeScheduleToMinutes(app.getProperty("refresh_freq")); // once de data were loaded, continue with the settings interval
						app.setProperty("lastLoad", 'w');	// for background process to know the next time what was loaded to alternate between weather and calendar loading
					}
					// Garmin Weather API 12h
					// https://developer.garmin.com/connect-iq/api-docs/Toybox/Weather.html
						// 54 values possible | 22 ifs
						/*
						0 CLEAR				2x	CLEAR | FAIR | MOSTLY_CLEAR
						1 PARTLY_CLOUDY		3x	PARTLY_CLOUDY | PARTLY_CLEAR 
						  MOSTLY_CLOUDY		10x
						3 RAIN				12x	RAIN | THUNDERSTORMS | HAIL | HEAVY_RAIN | HEAVY_RAIN_SNOW | RAIN_SNOW | HEAVY_SHOWERS | CHANCE_OF_THUNDERSTORMS | TORNADO | HURRICANE | TROPICAL_STORM | SLEET
						5 SNOW				2x	SNOW | HEAVY_SNOW
						  WINDY		
						3 THUNDERSTORMS		
						  WINTRY_MIX		
						  FOG		
						  HAZY		
						3 HAIL		
						2 SCATTERED_SHOWERS	7x SCATTERED_SHOWERS > LIGHT_RAIN_SNOW | LIGHT_SHOWERS < CHANCE_OF_SHOWERS | DRIZZLE | CHANCE_OF_RAIN_SNOW > FREEZING_RAIN
						2 SCATTERED_THUNDERSTORMS		
						2 UNKNOWN_PRECIPITATION		
						2 LIGHT_RAIN		
						3 HEAVY_RAIN		
						4 LIGHT_SNOW		2x	LIGHT_SNOW | CHANCE_OF_SNOW | CLOUDY_CHANCE_OF_SNOW | ICE_SNOW
						5 HEAVY_SNOW		
						2 LIGHT_RAIN_SNOW		
						3 HEAVY_RAIN_SNOW		
						  CLOUDY		
						3 RAIN_SNOW		
						1 PARTLY_CLEAR		
						0 MOSTLY_CLEAR		
						2 LIGHT_SHOWERS		
						2 SHOWERS		
						3 HEAVY_SHOWERS		
						2 CHANCE_OF_SHOWERS		
						3 CHANCE_OF_THUNDERSTORMS		
						  MIST		
						  DUST		
						2 DRIZZLE		
						3 TORNADO		
						  SMOKE		
						  ICE		
						  SAND		
						  SQUALL		
						  SANDSTORM		
						  VOLCANIC_ASH		
						  HAZE		
						0 FAIR		
						3 HURRICANE		
						3 TROPICAL_STORM		
						4 CHANCE_OF_SNOW		
						2 CHANCE_OF_RAIN_SNOW		
						2 CLOUDY_CHANCE_OF_RAIN		
						4 CLOUDY_CHANCE_OF_SNOW		
						2 CLOUDY_CHANCE_OF_RAIN_SNOW		
						2 FLURRIES		
						2 FREEZING_RAIN		
						3 SLEET		
						4 ICE_SNOW		
						  THIN_CLOUDS		
						  UNKNOWN		
						*/
					/*var c;
					data = Weather.getHourlyForecast();
					// +800 kB with array
					//var weather_map = [0,1,-1,3,5,-1,3,-1,-1,-1,3,2,2,2,2,3,4,5,2,3,-1,3,1,0,2,2,3,2,3,-1,-1,2,3,-1,-1,-1,-1,-1,-1,-1,0,3,3,4,2,2,4,2,2,2,3,4,-1,-1];
					for(var j=0; j<data.size(); j++){
						//c = weather_map[data[j].condition];
						c = data[j].condition;
						// +600 kb with ifs
						if( c==Weather.CONDITION_CLEAR || c==Weather.CONDITION_FAIR || c==Weather.CONDITION_MOSTLY_CLEAR) {c=0;}
						else if( c==Weather.CONDITION_PARTLY_CLOUDY || c==Weather.CONDITION_PARTLY_CLEAR ) {c=1;}
						else if( c==Weather.CONDITION_SNOW || c==Weather.CONDITION_HEAVY_SNOW) {c=5;}
						else if( c==Weather.CONDITION_LIGHT_SNOW || c==Weather.CONDITION_CHANCE_OF_SNOW || c==Weather.CONDITION_CLOUDY_CHANCE_OF_SNOW || c==Weather.CONDITION_ICE_SNOW) {c=4;}
						else if( c==Weather.CONDITION_RAIN || c==Weather.CONDITION_THUNDERSTORMS || c==Weather.CONDITION_HAIL || c==Weather.CONDITION_HEAVY_RAIN || c==Weather.CONDITION_HEAVY_RAIN_SNOW || 
							c==Weather.CONDITION_RAIN_SNOW || c==Weather.CONDITION_HEAVY_SHOWERS || c==Weather.CONDITION_CHANCE_OF_THUNDERSTORMS || c==Weather.CONDITION_TORNADO || c==Weather.CONDITION_HURRICANE || 
							c==Weather.CONDITION_TROPICAL_STORM || c==Weather.CONDITION_SLEET) {c=3;}
						else if( (c>=Weather.CONDITION_SCATTERED_SHOWERS && c<=Weather.CONDITION_LIGHT_RAIN_SNOW) || (c>=Weather.CONDITION_LIGHT_SHOWERS && c<=Weather.CONDITION_CHANCE_OF_SHOWERS) || c==Weather.CONDITION_DRIZZLE || 
							(c>=Weather.CONDITION_CHANCE_OF_RAIN_SNOW  && c<=Weather.CONDITION_FREEZING_RAIN)) {c=2;}
						else {c= -1;}
						data[j]=c;
					}
					var t = Weather.getCurrentConditions().feelsLikeTemperature; 
					if (t==null) {t="";}	// yes, they ocassionally realy can return null. No kidding. 
					data = {"weather"=>[Sys.getClockTime().hour, t].addAll(data)}; // for prod code real temperature and hour */
					//Sys.println([data.observationLocationName, data.observationLocationPosition.toDegrees(), data.observationTime.value()]);
					
				} else {
					if(data.hasKey("refresh_token")){
						app.setProperty("refresh_token", data.get("refresh_token"));
						app.setProperty("user_code", null);
					}
					if (data.hasKey("primary_calendar")){
						app.setProperty("calendar_ids", [data["primary_calendar"]]);
					}
					if (data.hasKey("events")) {
						data = parseEvents(data.get("events"));
						app.setProperty("events", data);
						app.setProperty("lastLoad", 'c'); // for background process to know the next time what was loaded to alternate between weather and calendar loading
						if(app.getProperty("weather")==true){
							changeScheduleToMinutes(5);	// when weather not loaded yet, load ASAP						
							if(app.getProperty("subs") == null){	// first time loading forecast => instruct to check the phone
								data = scheduleDataLoading();
							}
						} else {
							changeScheduleToMinutes(app.getProperty("refresh_freq"));	// when weather not loaded yet, load ASAP		
						}
						// TODO message to wait to load weather
					} else if(data.hasKey("user_code")){ // prompt login
						app.setProperty("refresh_token", null); 
						app.setProperty("user_code", data.get("user_code")); 
						app.setProperty("verification_url", data.get("verification_url")); 
						app.setProperty("device_code", data.get("device_code")); 
						changeScheduleToMinutes(5);
						data = promptLogin(data.get("user_code"), data.get("verification_url"));
						//app.setProperty("code_valid_till", new Time.now().value() + add(data.get("expires_in").toNumber()));
					} else if(data.hasKey("error_code")){
						var error = data["error_code"];
						//System.println(data);
						data["wait"] = durationToNextEvent();
						var connected = Sys.getDeviceSettings().phoneConnected;
						if(error==-300 || error==404 || error==-2 || error==-5 || error==-104 || error==-400){ // no internet or bluetooth or no-json
							//System.println([watch.activity == :calendar , app.getProperty("lastLoad")!="c", watch.showWeather==false, app.getProperty("refresh_token")==null]);
							//System.println([watch.activity == :calendar ,app.getProperty("refresh_token") , watch.showWeather ,app.getProperty("subs")]);
							if(watch!=null && ((watch.activity == :calendar && app.getProperty("refresh_token")==null) || (watch.showWeather && app.getProperty("subs")==null)) ){
							//if(watch.activity == :calendar && (app.getProperty("lastLoad")!="c" || showWeather==false) && app.getProperty("refresh_token")==null){	// no internet or not connected when logging in
								// TODO: 404 with msg no data might actually mean also problem with Google: https://developers.google.com/calendar/v3/errors
								data["userPrompt"] = Ui.loadResource(connected ? Rez.Strings.NoInternet : Rez.Strings.NotConnected);
							} else {	
								return;
							}
						} else if(error==429){
							if(data.hasKey("msBeforeNext")){
								//System.println([data["wait"], data["msBeforeNext"]]);
								if(data["wait"]*1000 < data["msBeforeNext"]){
									data["wait"]=data["msBeforeNext"]/1000;
								}							
							}
							changeScheduleToMinutes(data["wait"]/60);
						} else {
							changeScheduleToMinutes(5);
							// if(error==511 ){ // ///Sys.println("login request");// login prompt on OAuth data["userPrompt"] = Ui.loadResource( connected ? Rez.Strings.Wait4login : Rez.Strings.NotConnected);} else 
							if (error == -204){
								data["userPrompt"] = Ui.loadResource(Rez.Strings.NoGPS);
								data["userContext"] = Ui.loadResource(Rez.Strings.HowGPS);
								data.put("permanent", true);
							} else if(data.hasKey("error")){	// when reason is passed from background
								//////Sys.println(data["error"]);
								data["userPrompt"] = data["error"];
								data.put("permanent", true);
							} else if(error>=400 && error<=403) { // general codes of not being authorized and not explained: invalid user_code || unauthorized || access denied
								if(data.hasKey("subscription_id")){	// subscription is not in db: expired or wasn't paid at all
									app.setProperty("subscription_id", null);
									data["userPrompt"] = Ui.loadResource(Rez.Strings.Subscribe);
									///Sys.println(Ui.loadResource(Rez.Strings.Subscribe));
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
				}
				if(watch!=null){
					watch.onBackgroundData(data);
				}
				Ui.requestUpdate();
			}
		} catch(ex){	//Sys.println("ex: " + ex.getErrorMessage());///Sys.println( ex.printStackTrace());
			if(watch!=null){
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
			id_list = Toy.StringUtil.charArrayToString(id_list);
			
			
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
			//////Sys.println(list);
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
	function parseEvents(data){
		var events_list = [];
		var dayDegrees = 86400.0 / (app.getProperty("d24") == 1 ? 360 : 720);	// SECONDS_PER_DAY /
		var midnight = Time.today();		
		var date; var dateTo;
		var fromAngle;
		var toAngle;

		if(data instanceof Toybox.Lang.Array) { 
			// parse dates
			for(var i=0; i<data.size() ;i++){
				date = parseISODate(data[i][0]);
				dateTo = parseISODate(data[i][1]);
				fromAngle = Math.round(date.compare(midnight)/dayDegrees).toNumber();
				toAngle = Math.round(dateTo.compare(midnight)/dayDegrees).toNumber();
				if(fromAngle == toAngle){
					toAngle = fromAngle+1;
				}
				//if(fromAngle>360){fromAngle-=360;}if(toAngle>360){toAngle-=360;}
				if(date!=null){
					events_list.add([
						date.value(),                                               // start
						dateTo.value(),                           // end
						data[i][2],                                                 // name
						data[i][3] ? ": " + data[i][3] : "",                        // location
						data[i][4],                                                 // calendar
						fromAngle,         // degree start
						toAngle       // degree end
					]);
				}
			}
			// sort
			var i; var j;
			for(i=0; i<events_list.size()-1; i++){
				for (j=0; j<events_list.size()-i-1; j++) {
					if (events_list[j][0]>(events_list[j+1][0])){
						data=events_list[j];
						events_list[j]=events_list[j+1];
						events_list[j+1]=data;
					}
				}
			}
		}
		return(events_list);
	}

	function locate(){
	    //App.getApp().setProperty("l", App.getApp().getProperty("l")+" "+Sys.getClockTime().min);
	    var position;
	    if(Toy.Position has :getInfo){
	        position = Toy.Position.getInfo();
	    } else {
	        position = Toy.ActivityMonitor.getInfo();
	    }
	    var loc = sanitizeLoc(position.position);   
		Sys.println("locate: "+loc);
	    if(Toy has :Weather){
	        if(position.accuracy == null || position.accuracy <=1 ){    // 0 N/A, 1 LAST, 2 POOR, 3 USABLE, 4 GOOD
	            var weather = Toy.Weather.getCurrentConditions();
	            if(weather != null){
	                loc = sanitizeLoc(weather.observationLocationPosition);
	                //App.getApp().setProperty("w", loc);
	            }
	        }
	    }
	    if (loc == null){
	        loc = app.getProperty("location"); // load the last location to fix a Fenix 5 bug that is loosing the location often       
	    } else {
	        app.setProperty("location", loc); // save the location to fix a Fenix 5 bug that is loosing the location often
	    }
	    /////Sys.println("computeSun: "+loc);
	    return loc;
	}

	function sanitizeLoc(loc){
	    if(loc!=null){
	        loc = loc.toDegrees();
	        if(loc!=null){
	            if((loc[0]==0 && loc[1]==0) || loc[0]>=90 || loc[1]>=90 || loc[1]>=180 || loc[1]>=180){ // bloody bug that the currentLocation sometimes returns [0.000000, 0.000000] or [180.0, 180.0] / [lat, lon]. Garmin guys, I hate you so much! 
	                return null;
	            } 
	            return loc;
	        }
	    }
	    return null;
	}
}