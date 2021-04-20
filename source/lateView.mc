//// diff from analog marked //12// drawNowCircle + drawTime
//// set d24 prop: default 24 or 12h calendar
//// links in properties to help with -analog suffix !!!
//// drawtime switch
//// boldness

//// manifest app id

//// remove any debug variables
//// remove weather localisation property

// Ensure empiric limits: 2000 first event + 600 every other [B:5704/7 venusq, B:3872/5 fr945, exit:3592]


using Toybox.WatchUi as Ui;
using Toybox.Graphics as Gfx;
using Toybox.System as Sys;
using Toybox.Lang as Lang;
using Toybox.Time as Time;
using Toybox.Time.Gregorian as Calendar;
using Toybox as Toy;
using Toybox.Math as Math;
using Toybox.Application as App;

//enum {SUNRISET_NOW=0,SUNRISET_MAX,SUNRISET_NBR}
var meteoColors;

class lateView extends Ui.WatchFace {
	var app;
	hidden var dateForm; hidden var batThreshold = 33;
	hidden var centerX; hidden var centerY; hidden var height;
	hidden var color; hidden var timeColor; hidden var dateColor; hidden var activityColor; hidden var backgroundColor; hidden var dimmedColor;
	hidden var calendarColors; 
	var activity=null; var activityL=null; var activityR=null; var showSunrise = false; var dataLoading = false; var showWeather = false; var percentage = false;
	//hidden var icon=null; hidden var iconL=null; hidden var iconR=null; hidden var sunrs = null; hidden var sunst = null; //hidden var iconNotification;
	hidden var clockTime; 
	hidden var utcOffset; hidden var day = -1;
	//hidden var lonW; hidden var latN; 
	//hidden var sunrise = new [SUNRISET_NBR]; hidden var sunset = new [SUNRISET_NBR];
	hidden var sunrise; hidden var sunset;
	hidden var fontSmall = null; hidden var fontHours = null; hidden var fontCondensed = null;
	hidden var dateY = null; hidden var radius; hidden var circleWidth = 3; hidden var dialSize = 0; hidden var batteryY; hidden var activityY; hidden var messageY; hidden var sunR; //hidden var temp; //hidden var notifY;
	hidden var icons;
	hidden var d24;
	/* TODO AOD */ hidden var burnInProtection=0;
	
	hidden var events_list = [];
	var message = false;
	var weatherHourly = [];

	// redraw full watchface
	//hidden var redrawAll=2; 
	//hidden var lastRedrawMin=-1;
	//hidden var dataCount=0;hidden var wakeCount=0;

	function initialize (){
		app = App.getApp();
		if(Ui.loadResource(Rez.Strings.DataLoading).toNumber()==1){ // our code is ready for data loading for this device
			dataLoading = Sys has :ServiceDelegate;	// watch is capable of data loading
		}
		if(!dataLoading){
			if(app.getProperty("activity")==6){
				app.setProperty("activity", 0);
			}
			if(app.getProperty("weather")){
				app.setProperty("weather", false);
			}
		}
		WatchFace.initialize();
		var s=Sys.getDeviceSettings();
		height = s.screenHeight;
		centerX = s.screenWidth >> 1;
		centerY = height >> 1;
		clockTime = Sys.getClockTime();
		

		//Sys.println(["events_list before init", events_list ? events_list.toString().substring(0,30)+"...": ""]);
		var events = Toybox.Application has :Storage ? Toybox.Application.Storage.getValue("events") : app.getProperty("events");
if(!(events instanceof Lang.Array) && (Toybox.Application has :Storage)){
events = app.getProperty("events");
Toybox.Application.Storage.setValue("events", events);
app.setProperty("events", null); // migration	
}
		if(events instanceof Lang.Array){
			events_list = events;
		}


		//Sys.println("init: "+ weatherHourly);
		if(weatherHourly.size()==0){
			var weather = app.getProperty("weatherHourly");
			if(weather instanceof Lang.Array){
				weatherHourly = weather;
			}
		}
		//onBackgroundData({"weather"=>[17, -1, -1, 1, 5.960000, -1, -1, -1, -1, -1, -1, 4, 4, -1, -1, 4, 2, 4, -1, -1, -1, -1, -1, 4, 2, -1, -1, 4, 4]});
		d24 = app.getProperty("d24") == 1 ? true : false; // making sure it loads for the first time 
		//Sys.println("init: "+ weatherHourly);
	}

	(:release)
	function onLayout (dc) { 
		loadSettings();
	}

	(:debug)
	function onLayout (dc) {
		var mem = Sys.getSystemStats();
		System.println(" mem: free: " +mem.freeMemory + "/"+mem.totalMemory +" used: "+mem.usedMemory);
		/* HR prototyping Sys.println(Toy.UserProfile.getHeartRateZones(Toy.UserProfile.HR_ZONE_SPORT_GENERIC));
		If the watch device is newer it will likely support calling this method, which returns an heart rate value that is updated every second:
		Activity.getActivityInfo().currentHeartRate()
		Otherwise, you can call this method and use the most recent value, which will be the heart rate within the last minute:
		ActivityMonitor.getHeartRateHistory()
		In both cases you will need to check for a null value, which will happen if the sensor is not available or the user is not wearing the watch.*/

		presetTestVariables();
		loadSettings();
		resetTestVariables();	
	}

	(:debug)
	function presetTestVariables () {
		var data = Ui.loadResource(Rez.JsonData.testData);
		if(data.hasKey("CopyProperties")){
			var d = data["Properties"];
			var keys = d.keys();
			for(var i=0;i<keys.size();i++){
				Sys.println(" - copy property "+keys[i]+" to "+(d[keys[i]]!=null ? d[keys[i]].toString().substring(0,30) : "[MISSING]"));
				app.setProperty(keys[i], app.setProperty(keys[i],d[keys[i]]));
			}
		}
		if(data.hasKey("clearProperties")){
			var d = data["clearProperties"];
			for(var i=0;i<d.size();i++){
				Sys.println(" - clear property "+d[i]);
				app.setProperty(d[i], null);
			}
		}
		if(data.hasKey("Properties")){
			var d = data["Properties"];
			var keys = d.keys();
			for(var i=0;i<keys.size();i++){
				Sys.println(" - property "+keys[i]+": "+(d[keys[i]]!=null ? d[keys[i]].toString().substring(0,30) : "[MISSING]"));
				app.setProperty(keys[i], d[keys[i]]);
			}
		}
		if(data.hasKey("CharProperties")){
			var d = data["CharProperties"];
			var keys = d.keys();
			for(var i=0;i<keys.size();i++){
				Sys.println(" - char property "+keys[i]+": "+d[keys[i]].toCharArray()[0]);
				app.setProperty(keys[i], d[keys[i]]);
			}
		}
		if(data.hasKey("clearStorage")){
			var d = data["clearStorage"];
			for(var i=0;i<d.size();i++){
				if(Toybox.Application has :Storage){
					Sys.println(" - clear storage "+d[i]);	
					Toybox.Application.Storage.setValue(d[i], null);
				} else {
					Sys.println(" - clear property instead of storage "+d[i]);
					app.setProperty(d[i], null);
				}
			}
		}
		if(data.hasKey("Storage")){
			var d = data["Storage"];
			var keys = d.keys();
			for(var i=0;i<keys.size();i++){
				if(Toybox.Application has :Storage){
					Sys.println(" - storage "+keys[i]);	
					Toybox.Application.Storage.setValue(keys[i], (d[keys[i]]!=null ? d[keys[i]].toString().substring(0,30) : "[MISSING]"));
				} else {
					Sys.println(" - property instead of storage "+keys[i]+": "+d[keys[i]]);
					app.setProperty(keys[i], d[keys[i]]);
				}
			}
		}

		//app.setProperty("d24", Sys.getDeviceSettings().is24Hour); 
		//app.setProperty("units", 1);
		//set props: mainColor=1;circleWidth=9;
		//app.setProperty("activity", 6); app.setProperty("calendar_ids", ["myneur@gmail.com","petr.meissner@gmail.com"]);
		//app.setProperty("weather", true); app.setProperty("location", [50.1137639,14.4714428]); app.setProperty("sunriset", true);
		//app.setProperty("activityL", 2); app.setProperty("activityR", 1); 
		//app.setProperty("dialSize", 0);
		if(data.hasKey("Reinitialize")){
			Sys.println(" - Reinitialize");
			initialize();
		}
	}

	(:debug)
	function resetTestVariables () {
		var data = Ui.loadResource(Rez.JsonData.testData);

		if(data.hasKey("AfterLayoutProperties")){
			var d = data["AfterLayoutProperties"];
			var keys = d.keys();
			for(var i=0;i<keys.size();i++){
				Sys.println(" - property reset "+keys[i]+": "+(d[keys[i]]!=null ? d[keys[i]].toString().substring(0,30) : "[MISSING]"));
				app.setProperty(keys[i], d[keys[i]]);
			}
		}
		if(data.hasKey("AfterLayoutCharProperties")){
			var d = data["AfterLayoutCharProperties"];
			var keys = d.keys();
			for(var i=0;i<keys.size();i++){
				Sys.println(" - char property reset "+keys[i]+": "+d[keys[i]].toCharArray()[0]);
				app.setProperty(keys[i], d[keys[i]].toCharArray()[0]);
			}
		}
		if(data.hasKey("AfterLayoutStorage")){
			var d = data["AfterLayoutStorage"];
			var keys = d.keys();
			for(var i=0;i<keys.size();i++){
				if(Toybox.Application has :Storage){
					Sys.println(" - storage reset "+keys[i]);	
					Toybox.Application.Storage.setValue(keys[i], d[keys[i]]);
				} else {
					Sys.println(" - property instead of storage reset "+keys[i]+": "+(d[keys[i]] ? d[keys[i]].toString().substring(0,30) : "[MISSING]"));
					app.setProperty(keys[i], d[keys[i]]);
				}
			}
		}
		if(data.hasKey("Message")){
			Sys.println(" - Message");
			showMessage({"userPrompt"=>data["Message"]});
		}
		//weatherHourly = [18, 9, 0, 1, 6, 4, 5, 2, 3, 1, 6, 4, 5, 2, 3, 1, 6, 4, 5, 2, 3, 1, 6, 4, 5, 2, 3, 1, 6, 4, 5, 2, 3];
		//if(activity == :calendar && app.getProperty("refresh_token") == null){dialSize = 0;	/* there is no space to show code in strong mode */}
	}

	function loadSettings(){
		//rain = app.getProperty("rain");

		dateForm = app.getProperty("dateForm");
		
		var activities = [null, :steps, :calories, :activeMinutesDay, :activeMinutesWeek, :floorsClimbed, :calendar];
		activity = activities[app.getProperty("activity")];
		activityL = activities[app.getProperty("activityL")];
		activityR = activities[app.getProperty("activityR")];
		showSunrise = app.getProperty("sunriset");
		batThreshold = app.getProperty("bat");
		circleWidth = app.getProperty("boldness");
		if(height>280){
			circleWidth=circleWidth<<1;
		}
		dialSize = app.getProperty("dialSize");
		showWeather = app.getProperty("weather"); if(showWeather==null) {showWeather=false;} // because it is not in settings of non-data devices
		percentage = app.getProperty("percents");
		if(app.getProperty("subs")!=null && weatherHourly!=null && weatherHourly instanceof Array){
			if(weatherHourly.size()>5){	// if we know at least some forecast
				app.setProperty("lastLoad", 'w');	// to refresh the calendar first after the reload
			}
		}
		var d24new = app.getProperty("d24") == 1 ? true : false; 
//d24new=true; app.setProperty("d24", d24new); 
		if(( activity == :calendar) && (d24!= null && d24new != d24)){	// changing 24 / 12h 
			events_list=[];
			showMessage(app.scheduleDataLoading());
			/*	TODO: changing angle immediately
						var hour = clockTime.hour;
			var mul; var a; var b;
			if(d24new){
				mul = 2;
				a = Math.PI/(720.0) * (hour*60+clockTime.min);	// 720 = 2PI/24hod
				if(hour>11){ hour-=12;}
				if(0==hour){ hour=12;}
				b = Math.PI/(360.0) * (hour*60+clockTime.min);	// 360 = 2PI/12hod
			} else {
				mul = 0.5;
				if(hour>11){ hour-=12;}
				if(0==hour){ hour=12;}
				b = Math.PI/(360.0) * (hour*60+clockTime.min);	// 360 = 2PI/12hod
				hour = clockTime.hour;
				a = Math.PI/(720.0) * (hour*60+clockTime.min);	// 720 = 2PI/24hod
			}
			for(var i=0; i<events_list.size(); i++){
				events_list[5] = ((a - events_list[5])*mul +b).toNumber();
				events_list[6] = ((a - events_list[6])*mul +b).toNumber();
			}
			*/
		}
		d24 = d24new;
		var tone = app.getProperty("tone").toNumber()%5;
		var mainColor = app.getProperty("mainColor").toNumber()%6;
		if(dialSize>0){
			activityL=null;
			activityR=null;
		}
		// when running for the first time: load resources and compute sun positions
		if(showSunrise){ // TODO recalculate when day or position changes
			clockTime = Sys.getClockTime();
			utcOffset = clockTime.timeZoneOffset;
			computeSun();
			//Sys.println([sunrise, sunset]);
		}
		//	red, 	, yellow, 	green, 		blue, 	violet, 	grey
		color = [
			[0xFF0000, 0xFFAA00, 0x00FF00, 0x00AAFF, 0xFF00FF, 0xAAAAAA],
			[0xAA0000, 0xFF5500, 0x00AA00, 0x0000FF, 0xAA00FF, 0x555555], 
			[0xAA0055, 0xFFFF00, 0x55FFAA, 0x00AAAA, 0x5500FF, 0xAAFFFF]
		][tone<=2 ? tone : 0][mainColor];
		if(tone == 3){ 			// white background
			backgroundColor = 0xFFFFFF;
			timeColor = 0x0;
			dateColor = 0x0;
			activityColor = 0x555555;
			dimmedColor = 0xAAAAAA;
			if(color == 0xFFAA00){	// dark yellow background is more readable
				color = 0xFF5500;
			}
		} else if (tone == 4) {	// color background
			if(color == 0xFFAA00){	// dark yellow background is more readable
				color = 0xFF5500;
			} else if(color == 0xAAAAAA){	// dark gray background is more readable
				color = 0x555555;
			}
			backgroundColor = color;
			color = 0xFFFFFF;
			timeColor = 0x0;
			dateColor = 0x0;
			activityColor = 0xFFFFFF;
			dimmedColor = 0xAAAAAA;
		} else { 						// black background 
			backgroundColor = 0x0;
			timeColor = 0xFFFFFF;
			//activityColor = 0x555555;
			//dateColor = 0xAAAAAA;
			activityColor = 0xAAAAAA;
			dimmedColor = 0x555555;
			dateColor = 0xFFFFFF;

		}
		if(height==208 ){	// FR45 with 8 colors do not support gray. Contrary the simluator, the real watch do not support even LT_GRAY. 
			activityColor = Gfx.COLOR_WHITE; 
			if(tone != 3 && tone != 4){
				dateColor = Gfx.COLOR_WHITE;
			}
		}
		if(showWeather || activity == :calendar){
			loadDataColors(mainColor, tone, app);
		}
		setLayoutVars();
		onShow();
	}

	(:data)
	function loadDataColors(mainColor, tone, app){
		var mainColor = app.getProperty("mainColor").toNumber()%6;
		if(showWeather){
			meteoColors = Ui.loadResource(Rez.JsonData.metCol);
			//Sys.println([0xFFAA00,	0xAA5500,	0x005555, 0x00AAFF,	0xAAAAAA, 0xFFFFFF, 0x555500];);
				//enum {	clear, 		partly, 	lghtrain, rain,	 	mild snow, snow, clear neight} // clean moon can be 555555 instead of sun and mostly cloudy can be skipped
			if(tone>2){
				meteoColors[2]=0x0055FF;
				//meteoColors[3]=0x00AAFF;
				if(tone==4){		// color bg
					meteoColors[0]=0xFFFF55;
					meteoColors[1]=0xFFAA00;
					if(mainColor==2 || mainColor==3){	// green || blue
						meteoColors[2]= mainColor==2 ? 0x0055FF /* try 0AF */ : 0x005555;
						meteoColors[3]=0x0000AA;
					} else if(mainColor==5 ){	// gray
						meteoColors[2]=0x0055FF;
					}
				}
			}
			if(tone==3){	// white background
				meteoColors[4]=0x555555;
				meteoColors[5]=0x0;

			}
		}

		/*var colorsToOverride = app.getProperty("cheat");
		if(colorsToOverride != null){
			if(colorsToOverride.length()>=6){
				colorsToOverride = app.split(colorsToOverride);
				if(colorsToOverride.size()>0) {color = colorsToOverride[0].toNumberWithBase(0x10);}
				if(colorsToOverride.size()>1) {dateColor = colorsToOverride[1].toNumberWithBase(0x10);}
				if(colorsToOverride.size()>2) {activityColor = colorsToOverride[2].toNumberWithBase(0x10);}
				if(colorsToOverride.size()>3) {timeColor = colorsToOverride[3].toNumberWithBase(0x10);}
				if(colorsToOverride.size()>4) {backgroundColor = colorsToOverride[4].toNumberWithBase(0x10);}
			}
		}*/
		if(activity == :calendar){
			if(app.getProperty("calendar_colors")){	// match calendar colors to watch
				calendarColors = Ui.loadResource(Rez.JsonData.calCol)[mainColor];
				/*Sys.println( [
					[0xAA0055, 0xFFFF00, 0x555555], 
					[0xFFFF00, 0xAA00FF, 0x555555], 
					[0x55FFAA, 0x00AAFF, 0x555555], 
					[0x00AAAA, 0xFFFF00, 0x555555], 
					[0xAA00FF, 0xFFFF00, 0x555555], 
					[0x555555, 0xAA00FF, 0x00AAFF] 
					]);*/
				/*for(var i=0; i<calendarColors.size(); i++){
					calendarColors[i] = calendarColors[i].toNumberWithBase(0x10);
				}*/
				if(tone == 4) {	// color background 
					calendarColors[0] = 0xFFFFFF;
					calendarColors[2] = 0x0;
					if(mainColor==1 || mainColor==2){calendarColors[1]=0xFFFF55;}
					else if(mainColor==5){calendarColors[1]=0xAAFFFF;}
				} else if(tone == 3) { // white background
					if(mainColor==0 || mainColor==3){calendarColors[1]=0xAA00FF;}
					else if(mainColor==2){calendarColors[0]=0x00AA00;}
					else if(mainColor==2){calendarColors[0]=0xFF5500;}
				}
				app.setProperty("calendarColors", calendarColors);
			} else {	// keep last calendar colors
				if(app.getProperty("calendarColors")!=null){
					calendarColors = app.getProperty("calendarColors");
				} else {
					app.setProperty("calendarColors", calendarColors);
				}
			}
		}
	}


	function setLayoutVars(){
		icons = Ui.loadResource(Rez.Fonts.Ico);
		sunR = centerX-5;// - (height>=390 ? (showWeather ? 23:16) : (showWeather ? 15:11)); // base: -9-11, weather: 15
		if(showSunrise){
			//sunrs.getWidth()>>1;
			if(activity==:calendar){ sunR -= height<390 ? 9:13;}
			if(showWeather){ sunR -=  height<390 ? 4:6;}
			//if(activity==:calendar && showWeather) { sunR -= 2;}
			// TODO sunrs.width() - calendar f6: 6 venu: 10 / weather: f6: 3 venu: 5
		}
		if(dialSize>0){ // strong design
			fontHours = Ui.loadResource(Rez.Fonts.HoursStrong);
			fontSmall = Ui.loadResource(Rez.Fonts.SmallStrong);
			radius = (Gfx.getFontHeight(fontHours)*1.07).toNumber();
			if(centerX-radius-circleWidth>>1 <= 15){	// shrinking radius to fit day circle and sunriset on small screens
				radius = centerX-15-circleWidth>>1;
				sunR+=1;	
			}
			dateY = (centerY-radius*.5-Gfx.getFontHeight(fontSmall)).toNumber();
			circleWidth=circleWidth*3;
			batteryY=height-14;
			if(height<208){
				radius -= 11;
				dateY += 7;
			}
		} else { // elegant design
			fontHours = Ui.loadResource(Rez.Fonts.Hours);
			fontSmall = Ui.loadResource(Rez.Fonts.Small);
			radius = (Gfx.getFontHeight(fontHours)).toNumber();
			dateY = (centerY-(radius+Gfx.getFontHeight(fontSmall))*1.17).toNumber();
			batteryY = centerY+0.6*radius;			
		}
		fontCondensed = Ui.loadResource(Rez.Fonts.Condensed);
		if(activity != null || showWeather){
			if(dialSize==0){
				activityY = (height>180) ? height-Gfx.getFontHeight(fontCondensed)-10 : centerY+80-Gfx.getFontHeight(fontCondensed)>>1 ;
				if(dataLoading && (activity == :calendar || showWeather)){
					messageY = (centerY-radius+10)>>2 - Gfx.getFontHeight(fontCondensed)-1 + centerY+radius+10;						
				} else if(activity == :calendar){ 
					activity = null;
				}
			} else {
				activityY= centerY+Gfx.getFontHeight(fontHours)>>1+15;
				if(height<208){
					activityY -= 7;
				}
				if(activity==:calendar || showWeather){
					messageY =activityY - Gfx.getFontHeight(fontSmall)>>1 -10; 
				}
			}
		}
		/*if(batteryY<centerY+radius+circleWidth>>1){
			if(activity!=:calendar){
				batteryY = activityY - 10;
				activityY += 10;
			} else {
				batteryY = dateY+Gfx.getFontHeight(fontSmall);
			}
			
		}*/
		if(dataLoading){
			if(activity == :calendar || showWeather){
				showMessage(app.scheduleDataLoading());
				if(activity == :calendar){
					activityY = messageY;
				}
			} else {
				app.unScheduleDataLoading();
			}
		}

		var langTest = Calendar.info(Time.now(), Time.FORMAT_MEDIUM).day_of_week.toCharArray()[0]; // test if the name of week is in latin. Name of week because name of month contains mix of latin and non-latin characters for some languages. 
		if(langTest.toNumber()>382){ // fallback for not-supported latin fonts 
			fontSmall = Gfx.FONT_SMALL;
		}
		/////Sys.println("Layout finish free memory: "+Sys.getSystemStats().freeMemory);
	}

	//! Called when this View is brought to the foreground. Restore the state of this View and prepare it to be shown. This includes loading resources into memory.
	function onShow() {
		//App.getApp().setProperty("l", App.getApp().getProperty("l")+"w");
		//Sys.println(clockTime.min+"w");
		//Sys.println("onShow");
		
		/*if(centerX <=104){ // FR45 and VA4 needs to redraw the display every second. Better to 
			redrawAll=100;
		} else {
			redrawAll=2; // 2: 2 clearDC() because of lag of refresh of the screen ?
		}*/
	}
	
	//! Called when this View is removed from the screen. Save the state of this View here. This includes freeing resources from memory.
	function onHide(){
		//App.getApp().setProperty("l", App.getApp().getProperty("l")+"h");
		//Sys.println(clockTime.min+"h");
		/////Sys.println("onHide");
		//redrawAll=0;
	}
	
	//! The user has just looked at their watch. Timers and animations may be started here.
	function onExitSleep(){
		/* TODO AOD */ if(Sys.getDeviceSettings().requiresBurnInProtection){burnInProtection=0;circleWidth = app.getProperty("boldness");if(height>280){circleWidth=circleWidth<<1;}}
		//onShow();
		//App.getApp().setProperty("l", App.getApp().getProperty("l")+"x");
		//Sys.println(clockTime.min+"x");
		//////Sys.println("onExitSleep");
		//wakeCount++;
		
		/*if(showWeather){
			locateAt = new Toy.Timer.Timer().start(method(:loadSettings), getTemporalEventRegisteredTime(), true);
		}*/
	}

	//! Terminate any active timers and prepare for slow updates.
	function onEnterSleep(){
		/* TODO AOD */ if(Sys.getDeviceSettings().requiresBurnInProtection){burnInProtection=1;circleWidth=2;}
		//App.getApp().setProperty("l", App.getApp().getProperty("l")+"e");
		//Sys.println(clockTime.min+"e");
		//////Sys.println("onEnterSleep");
		/*if(centerX <=104){ // FR 45 needs to redraw the display every second
			redrawAll=100;
			Ui.requestUpdate();
		} else {
			redrawAll=0; // 2: 2 clearDC() because of lag of refresh of the screen ?
		}*/
		//redrawAll=0; // 2: 2 clearDC() because of lag of refresh of the screen ?
	}

	/*function openTheMenu(){
		menu = new MainMenu(self);
		Ui.pushView(new Rez.Menus.MainMenu(), new MyMenuDelegate(), Ui.SLIDE_UP);
	}*/

	//! Update the view
	// TODO AOD-X // var dx=5;var dy=5;
	function onUpdate (dc) {	//Sys.println("onUpdate ");
		clockTime = Sys.getClockTime();
		var cal = Calendar.info(Time.now(), Time.FORMAT_MEDIUM);
		//if (lastRedrawMin != clockTime.min && redrawAll==0) { redrawAll = 1; }
		//var ms = [Sys.getTimer()];
		//if (redrawAll>0){
		//////Sys.println([clockTime.min, redrawAll, Sys.getSystemStats().freeMemory]);
		if(dc has :setAntiAlias) {
			dc.setAntiAlias(true);
		}
		dc.setColor(backgroundColor, backgroundColor);
		dc.clear();
		/* TODO AOD */ if(burnInProtection){var diff = 4;if(burnInProtection>1){centerX = centerX + ((centerX == (height>>1)) ? diff : -diff);burnInProtection=1;}else{var move = (centerY==(height>>1)) ? diff : -diff;centerY = centerY + move;dateY = dateY + move;burnInProtection=2;}} else {
		// TODO AOD-X // if(burnInProtection){Sys.println([clockTime.hour, dx,dy]);if(burnInProtection>1){dx = dx == -5 ? dx+10 : dx-10;centerX = centerX + dx;centerY = centerY + dy;burnInProtection=1;}else{dy = dy == -5 ? dy+10 : dy-10;centerX = centerX + dx;centerY = centerY + dy;burnInProtection=2;}} else {
			//lastRedrawMin=clockTime.min;
			drawBatteryLevel(dc);
			
			//ms.add(Sys.getTimer()-ms[0]);

			// function drawDate(x, y){}
			dc.setColor(dateColor, Gfx.COLOR_TRANSPARENT);
			var text = "";
			if(dateForm != null){
				text = Lang.format("$1$ ", ((dateForm == 0) ? [cal.month] : [cal.day_of_week]) );
			}
			text += cal.day.format("%0.1d");
			dc.drawText(centerX, dateY, fontSmall, text, Gfx.TEXT_JUSTIFY_CENTER);
			if(Sys.getDeviceSettings().notificationCount){
				dc.setColor(activityColor, backgroundColor);
				dc.drawText(centerX-dc.getTextWidthInPixels(text+"  ", fontSmall)>>1, dateY+dc.getFontHeight(fontSmall)>>1+1, icons, "!" /*"!xb"*/, Gfx.TEXT_JUSTIFY_RIGHT | Gfx.TEXT_JUSTIFY_VCENTER);
				//dc.fillCircle(centerX-dc.getTextWidthInPixels(text, fontSmall)>>1-14, dateY+dc.getFontHeight(fontSmall)>>1+1, 5);
			}
			/*dc.drawText(centerX, height-20, fontSmall, Toy.ActivityMonitor.getInfo().moveBarLevel, Gfx.TEXT_JUSTIFY_CENTER | Gfx.TEXT_JUSTIFY_VCENTER);dc.setPenWidth(2);dc.drawArc(centerX, height-20, 12, Gfx.ARC_CLOCKWISE, 90, 90-(Toy.ActivityMonitor.getInfo().moveBarLevel.toFloat()/(ActivityMonitor.MOVE_BAR_LEVEL_MAX-ActivityMonitor.MOVE_BAR_LEVEL_MIN)*ActivityMonitor.MOVE_BAR_LEVEL_MAX)*360);*/
			dc.setColor(activityColor, Gfx.COLOR_TRANSPARENT);
			var x = centerX-radius - (sunR-radius)>>1-(dc.getTextWidthInPixels("1", fontSmall)/3).toNumber();	// scale 4 with resolution
			drawActivity(dc, activityL, x, centerY, false);
			drawActivity(dc, activityR, centerX<<1-x, centerY, false);
		/* TODO AOD */ }
		drawTime(dc);
		/* TODO AOD */ if(burnInProtection==0){
			if(activity != null || message){
				if(activity == :calendar || message){
					drawEvent(dc);
				} else { 
					drawActivity(dc, activity, centerX, activityY, true);
				}
			}
			if(showWeather){
				drawWeather(dc);
			}
			if(activity == :calendar){
				drawEvents(dc);
			}
			if(showSunrise){
				drawSunBitmaps(dc, cal);
			}
			// TODO recalculate sunrise and sunset every day or when position changes (timezone is probably too rough for traveling)
			drawNowCircle(dc, clockTime.hour);
		/* TODO AOD */ }

		//}
		//ms.add(Sys.getTimer()-ms[0]);
		/////Sys.println("ms: " + ms + " sec: " + clockTime.sec + " redrawAll: " + redrawAll);
		//if (redrawAll>0) { redrawAll--; }
	}

	
	function steps(info){
		return info.steps.toFloat()/info.stepGoal;
	}
	function calories(info){
		var h = ActivityMonitor.getHistory();
		if(h.size()>0){
			return info.calories.toFloat()/ActivityMonitor.getHistory()[0].calories;	
		} else {
			return 0;
		}
		
	}
	function activeMinutesDay(info){
		return info.activeMinutesDay.total.toFloat()/(info.activeMinutesWeekGoal.toFloat()/7);
	}
	function activeMinutesWeek(info){
		return info.activeMinutesWeek.total.toFloat()/info.activeMinutesWeekGoal;
	}
	function floorsClimbed(info){
		return info.floorsClimbed.toFloat()/info.floorsClimbedGoal;
	}

	function drawActivity(dc, activity, x, y, horizontal){
		if(activity != null){
			//Sys.println("ActivityMonitor");
			var info = Toy.ActivityMonitor.getInfo();
			var activityChar = {:steps=>'s', :calories=>'c', :activeMinutesDay=>'a', :activeMinutesWeek=>'a', :floorsClimbed=>'f'}[activity];	// todo optimize
			//var activityChar = activity==:steps ? 's' : activity==:calories ? 'c' : activity==:floorsClimbed? 'a' : 'f';
			//var activityChar;switch(activity){case :steps: activityChar='s';case :calories: activityChar='c';case :floorsClimbed: activityChar='f';default: activityChar='a';}
			if(percentage){
				info = method(activity).invoke(info);
				var r = Gfx.getFontHeight(icons)-3;
				dc.setPenWidth(2);
				dc.setColor(activityColor, Gfx.COLOR_TRANSPARENT);	
				drawIcon(dc, x, y, activityChar); // dc.drawBitmap(x-icon.getWidth()>>1, y-icon.getHeight()>>1, icon);	
				if(info>0.0001){
					dc.setColor(info<2 ? activityColor : dateColor, Gfx.COLOR_TRANSPARENT);	
					if(info>1){	
						if(info<3){
							dc.drawArc(x, y, r, Gfx.ARC_CLOCKWISE, 90-info*360-10, 100); 
							dc.setColor( info<2 ? dateColor : color, Gfx.COLOR_TRANSPARENT);
						} else {
							dc.setColor( color, Gfx.COLOR_TRANSPARENT);
							dc.drawCircle(x, y, r);
						}
					}
					dc.drawArc(x, y, r, Gfx.ARC_CLOCKWISE, 90, 90-info*360); 
				}
			} else {
				info = info[activity];
				info = humanizeNumber( (activity==:activeMinutesDay || activity==:activeMinutesWeek) ? info.total : info);
				var icoHalf = dc.getTextWidthInPixels(activityChar.toString(), icons)>>1;
				dc.setColor(activityColor, Gfx.COLOR_TRANSPARENT);	
				if(horizontal){	// bottom activity
					dc.drawText(x + icoHalf+1, y, fontCondensed, info, Gfx.TEXT_JUSTIFY_CENTER | Gfx.TEXT_JUSTIFY_VCENTER); 
					drawActivityIcon(dc, x - dc.getTextWidthInPixels(info, fontCondensed)>>1 -2, y, activityChar);
				} else {
					drawActivityIcon(dc, x  -3, y-Gfx.getFontHeight(icons)-1, activityChar);
					dc.drawText(x, y+1, fontCondensed, info, Gfx.TEXT_JUSTIFY_CENTER | Gfx.TEXT_JUSTIFY_VCENTER); 
				}
			}
		}
	}

	function drawIcon(dc, x, y, char){
		//dc.setColor(activityColor, 0xffffff);
		dc.drawText(x, y, icons, char, Gfx.TEXT_JUSTIFY_CENTER | Gfx.TEXT_JUSTIFY_VCENTER);
		//dc.setColor(0xff0000, 0xff0000);dc.setPenWidth(1);dc.drawLine(x-20, y, x+20, y);dc.drawLine(x, y-20, x, y+20);
	}
	function drawActivityIcon(dc, x, y, activityChar){
		//dc.setColor(activityColor, 0xffffff);
		dc.drawText(x, y, icons, activityChar, Gfx.TEXT_JUSTIFY_CENTER | Gfx.TEXT_JUSTIFY_VCENTER);
		//dc.setColor(0xff0000, 0xff0000);dc.setPenWidth(1);dc.drawLine(x-20, y, x+20, y);dc.drawLine(x, y-20, x, y+20);
	}

/*	function positionMetric(icon, text, vertical) {
		if(vertical){
			y: icon/2 down, icon: (text+icon)/2 up -gap

		} else {
			x: icon/2 right icon: (text+icon)/2 left -gap
			x: (text+icon)/2
				+icon
				-gap
		}
	}*/

	function showMessage(msg){	//Sys.println("message "+message);
		if(msg instanceof Lang.Dictionary && msg.hasKey("userPrompt")){
			var nowError = Time.now().value();
			message = true;
			if(msg.hasKey("wait")){
				nowError += msg["wait"].toNumber();
			}
			var context = msg.hasKey("userContext") ? " "+ msg["userContext"] : "";
			var calendar = msg.hasKey("permanent") ? -1 : 0;

			var fromAngle = ((nowError-Time.today().value())/240.0).toFloat(); // seconds_in_day/360 // TODO bug: for some reason it won't show it at all althought the degrees are correct. 
			events_list = [[nowError, nowError+86400, msg["userPrompt"].toString(), context, calendar, fromAngle, fromAngle+2]].addAll(events_list); // seconds_in_day
		}
	}

	(:data)
	function onBackgroundData(data) { //Sys.println("onBackgroundData view"); Sys.println(data);
		if(data instanceof Array){	
			events_list = data;
		} 
		else if(data instanceof Lang.Dictionary){
			if(data.hasKey("weather")){
				weatherHourly = data["weather"];
				//Sys.println(weatherHourly);
				var h = Sys.getClockTime().hour; // first hour of the forecast
//Sys.println([weatherHourly]);
				if (weatherHourly instanceof Array && weatherHourly.size()>5){	
					if(weatherHourly[0]!=h){ // delayed response or time passed
						if((h+1)%24 == weatherHourly[0]){	// forecast from future
							var gap = weatherHourly[0]-h;
							if(gap<0){
								gap += 24;
							}
							var balast = new [gap];
							while(gap>0){
								gap--;
								balast[gap]= -1;
							}
							weatherHourly = [h].addAll(weatherHourly.slice(1,5)).addAll(balast).addAll(weatherHourly.slice(5,null));
						} else if(!(h==(weatherHourly[0]+1)%24)){ // all except forecast in past
							weatherHourly[0]=h;	// ignoring difference because of the bug 
						}
					}
				} 
				var hourAngle = (trimPastHoursInWeatherHourly())%24;
				//Sys.println(weatherHourly);
				if(hourAngle>=0 && showSunrise && sunrise != null){	// dimming clear-night colors
					var sunAngle = toAngle(sunrise);
					var moonAngle = toAngle(sunset);
					//Sys.println([sunAngle,moonAngle]);
					for(var i =5; i<weatherHourly.size();i++){
						if(weatherHourly[i] <= 1 && (hourAngle+1 < sunAngle || hourAngle>moonAngle) ){	// partly cloudy not shown at night
							weatherHourly[i] = weatherHourly[i]==0 ? 6 : -1; // clear night for clear sky and dim partly cloudy
						} else {
							weatherHourly[i] = weatherHourly[i].toNumber();
						}
						//Sys.println(hourAngle);
						hourAngle=(hourAngle+1)%24;
					}
				}
				app.setProperty("weatherHourly", weatherHourly);
			}
			else if(data.hasKey("userPrompt")){
				showMessage(data);
			}
			//debug();
		}
		onShow();
		Ui.requestUpdate();
	}


/*function debug(){
	if(Toy has :Weather){
		var weather = Toy.Weather.getDailyForecast();
		if(weather != null){
			weather = weather[0];
			rain = [weather.lowTemperature, weather.highTemperature, weather.precipitationChance];
			if(weatherHourly.size()>4){
				var t = weatherHourly[1];
				if(t<rain[0]){rain[0] = t;}
				if(t>rain[1]){rain[1] = t;}
			}
			app.setProperty("rain", rain);
			//Sys.println(rain);
		}
	}

	//if(App.getApp().getProperty("calendar_ids").size()>0){
		//if(App.getApp().getProperty("calendar_ids")[0].find("myneur")!=null){//showMessage({"userPrompt"=> message});
		//weatherHourly = [13, 9, 0, 1, 6, 4, 5, 2, 3];App.getApp().setProperty("weatherHourly", weatherHourly);}}
}*/

	function humanizeNumber(number){
		if(number>1000) {
			return (number.toFloat()/1000).format("%1.1f")+"k";
		} else {
			return number.toString();
		}
	}

	function drawNowCircle(dc, hour){
		// show now in a day
		if( !(events_list.size()>0 && events_list[0][4]==-1) /* permanent message =-1 in 4th events_list item */ && (activity == :calendar || showSunrise || showWeather) ){
			var a;
			if(d24){
				a = Math.PI/(720.0) * (hour*60+clockTime.min);	// 720 = 2PI/24hod
			} else { 
				//return; // so far for 12h //12//
				if(hour>11){ hour-=12;}
				if(0==hour){ hour=12;}
				a = Math.PI/(360.0) * (hour*60+clockTime.min);	// 360 = 2PI/12hod
			}
			var x = centerX+(sunR*Math.sin(a));
			var y = centerY-(sunR*Math.cos(a));
			dc.setColor(backgroundColor, backgroundColor);
			dc.fillCircle(x, y, 5);
			if(activity == :calendar || showWeather){
				dc.setColor(dateColor, backgroundColor);
				dc.fillCircle(x, y, 4);
			} else {
				dc.setColor(activityColor, backgroundColor);
				dc.setPenWidth(1);
				dc.drawCircle(x, y, 4);
			}
			// line instead of circle dc.drawLine(centerX+(r*Math.sin(a)), centerY-(r*Math.cos(a)),centerX+((r-11)*Math.sin(a)), centerY-((r-11)*Math.cos(a)));
		}
	}

	(:data)
	function drawEvent(dc){ 
		// calculate time to first event
		var eventStart;   
		var eventStartTime; 
		var eventLocation="";    
		var i=0;
		for(; i<events_list.size(); i++){
			eventStartTime = new Time.Moment(events_list[i][0]);
			var timeNow = Time.now();
			var tillStart = eventStartTime.compare(timeNow);
			if(tillStart >= (d24 ? 86400 : 43200)){ 
				continue;
			}
			var eventEnd = new Time.Moment(events_list[i][1]);
			
			if(eventEnd.compare(timeNow)<0){
				events_list.remove(events_list[i]);
				if(events_list.size()==0){
					message = false;
				}
				i--;
				continue;
			}
			if(tillStart < -300){
			  continue;  
			}
			if(tillStart <= 0){
				eventStart = "now!";
			} else {

				if(tillStart < 3480){	// 58 mins
					var secondsFromLastHour = events_list[i][0] - (Time.now().value()-(clockTime.min*60+clockTime.sec));
					var a = (secondsFromLastHour).toFloat()/1800*Math.PI; // 2Pi/hour
					var r = tillStart>=120 || clockTime.min<10 ? radius : radius-Gfx.getFontHeight(fontSmall)>>1-1; //12//
					//var r = dialSize ? radius : 1.12*radius; //12//
					var x= Math.round(centerX+(r*Math.sin(a)));
					var y = Math.round(centerY-(r*Math.cos(a)));

					//12// marker 
					
					dc.setColor(backgroundColor, backgroundColor);
					dc.fillCircle(x, y, 4);
					dc.setColor(dateColor, backgroundColor);
					dc.fillCircle(x, y, 2);
					
					/*dc.setPenWidth(1);
					dc.setColor(dateColor, backgroundColor);
					dc.drawCircle(x, y, circleWidth>>1);*/
				}
				if (tillStart < 3600) {	// hour
					eventStart = tillStart/60 + "m";
				} else if (tillStart < 28800) {	// 8 hours
					eventStart = tillStart/3600 + "h" + tillStart%3600 / 60 ;
				} else {
					var time = Calendar.info(eventStartTime, Calendar.FORMAT_SHORT);
					var h = time.hour;
					if(Sys.getDeviceSettings().is24Hour == false){
						if(h>11){ h-=12;}
						else if(0==h){ h=12;}	
					}
					eventStart = h.toString() + ":"+ time.min.format("%02d");
				}
			}
			eventLocation = height>=280 || events_list[i][4]<0 ? events_list[i][3] : events_list[i][3].substring(0,8); // big screen or emphasized event without date 
			//event["name"] += "w"+wakeCount+"d"+dataCount;	// debugging how often the watch wakes for updates every seconds
			break;
		}

		// draw first event if it is close enough
		if(eventStart != null){
			if(events_list[i][4]<0){ // no calendar event, but prompt
				dc.setColor(dateColor , Gfx.COLOR_TRANSPARENT); // emphasized event without date
			} else {
				dc.setColor(activityColor , Gfx.COLOR_TRANSPARENT);
			}
			dc.drawText(centerX, messageY, fontCondensed, height>=280 ? events_list[i][2] : events_list[i][2].substring(0,21), Gfx.TEXT_JUSTIFY_CENTER);
			dc.setColor(dateColor, Gfx.COLOR_TRANSPARENT);
			// TODO remove prefix for simplicity and size limitations
			var x = centerX;
			var justify = Gfx.TEXT_JUSTIFY_CENTER;
			var eventHeight=Gfx.getFontHeight(fontCondensed)-1;  
			
			if(events_list[i][4]>=0){ // no calendar event, but prompt
				dc.setColor(dateColor , Gfx.COLOR_TRANSPARENT); // empha
				x-=(dc.getTextWidthInPixels(eventStart+eventLocation, fontCondensed)>>1 
					-(dc.getTextWidthInPixels(eventStart, fontCondensed)));
				dc.drawText(x, messageY+eventHeight, fontCondensed, eventStart, Gfx.TEXT_JUSTIFY_RIGHT);
				dc.setColor(activityColor, Gfx.COLOR_TRANSPARENT);
				justify = Gfx.TEXT_JUSTIFY_LEFT;
			}

			//else {dc.drawText(x,  height-batteryY, fontCondensed, eventStart, Gfx.TEXT_JUSTIFY_VCENTER);}
			dc.drawText(x, messageY+eventHeight, fontCondensed, eventLocation, justify);
		}
	}

	(:data)
	function drawEvents(dc){
		var radius = centerY;
		var width;
		if(height >= 390){
			radius -= showWeather ? 13:7;
			width = 12;
		} else {
			radius -= showWeather ? 8:4;
			width = 8;	
		}
		var nowAngle = ((clockTime.min+clockTime.hour*60.0)/ (d24? 4 : 2 )).toNumber(); // 360/1440;
		var tomorrow = Time.now().value() + (d24 ? 86400 : 43200); // 86400= Calendar.SECONDS_PER_DAY 
		var fromAngle; var toAngle;
		var center; 
		/*var h; var idx=2;	// offset 
		var weatherStart; var weatherEnd;*/

		for(var i=0; i <events_list.size() && events_list[i][0]<tomorrow; i++){			
			fromAngle = events_list[i][5];
			toAngle = events_list[i][6];	
			/*var midnight = Time.today().value();	
			var dayDegrees = 86400.0 / (App.getApp().getProperty("d24") == 1 ? 360 : 720);	// SECONDS_PER_DAY /
			fromAngle = Math.round((events_list[i][0]-(midnight))/dayDegrees).toNumber();
			toAngle = Math.round((events_list[i][1]-(midnight))/dayDegrees).toNumber();
			if(fromAngle == toAngle){
				toAngle = fromAngle+1;
			}*/
			//Sys.println([i, events_list[i][0], nowAngle,tomorrow, fromAngle, toAngle]);		
			if(events_list[i][1] >= events_list[0][0] + (d24 ? 86400 : 43200)){	// not to overlapp the start of the current event
				toAngle = events_list[0][5].toNumber()%360;
				//toAngle = Math.round((events_list[0][0]-(midnight))/dayDegrees).toNumber()%360;
				if((fromAngle.toNumber()+1)%360>=toAngle){
					//Sys.println([i, nowAngle,tomorrow, fromAngle, toAngle]);		
					continue;
				}
				toAngle-=1;
			} 
			if(events_list[i][1]>=tomorrow && events_list[i][6]>nowAngle ) { // crop tomorrow event overlapping now on 360° dial
			//if(events_list[i][1]>=tomorrow && Math.round((events_list[i][1]-(midnight))/dayDegrees).toNumber()>nowAngle ) { // crop tomorrow event overlapping now on 360° dial
				toAngle=nowAngle.toNumber()%360;
				if((fromAngle.toNumber()+1)%360>=toAngle){
					//Sys.println([i, nowAngle,tomorrow, fromAngle, toAngle]);		
					continue;
				}
				toAngle-=1;

			} 
			/*if(showWeather && weatherHourly.size()>2){
				// counting overlap // first attempt was: // weatherStart = ((weatherHourly[0]+idx-2)*360/24)%360;weatherEnd = ((weatherHourly[0]+idx-2+1)*360/24)%360;fromAngle = fromAngle.toNumber()%360;toAngle = toAngle.toNumber()%360;while(idx<weatherHourly.size() && (fromAngle>weatherEnd || toAngle<weatherStart)){idx++;}radius = centerY - (idx<weatherHourly.size()? 2:7);
				weatherStart = (fromAngle*24.0/360).toNumber()%24;
				weatherEnd = Math.ceil(toAngle*24.0/360).toNumber()%24;
				h = weatherStart;
				idx = h-weatherHourly[0]+2; /////Sys.println([weatherHourly[0], idx, weatherStart, weatherEnd]);
				if(idx<2){
					idx = 24-weatherHourly[0]+weatherStart+2;
				}
				while(h<weatherEnd && idx<weatherHourly.size()){
					if(weatherHourly[idx]!=-1){	
						break; // no weather to add padding 
					}
					idx++;
					h++;
				}
				radius = centerY - (h<weatherEnd? 8:2); //System.println([h,weatherEnd,radius]);
			}*/
			// drawing
			//Sys.println([fromAngle, toAngle]);
			//Sys.println([i, nowAngle,tomorrow, fromAngle, toAngle]);		
			dc.setColor(backgroundColor, backgroundColor);
			dc.setPenWidth(width);
			dc.drawArc(centerX, centerY, radius, Gfx.ARC_CLOCKWISE, 90-fromAngle+1, 90-fromAngle);
			if(events_list[i][4]>=0){
				dc.setColor(calendarColors[events_list[i][4]%(calendarColors.size())], backgroundColor);
			}
			dc.setPenWidth(width);
			center = fromAngle>=60 && fromAngle<240 ? centerX-1 : centerX; // correcting the center is not in the center because the display resolution is even
			dc.drawArc(centerX, centerY, radius, Gfx.ARC_CLOCKWISE, 90-fromAngle, 90-toAngle);	// draw event on dial

		}
	}

	/*function drawIconP(percent, icon, dc){
		var a = percent * 2*Math.PI;
		var r = centerX-9;
		dc.drawText(0, 0, icons, "1", Gfx.TEXT_JUSTIFY_CENTER); //dc.drawBitmap(centerX+(r*Math.sin(a))-8, centerY-(r*Math.cos(a))-8, icon);
		return a;
	}*/
	
	/*
	function drawTime (dc){

		// draw hour
		var r; var v;
		var h=clockTime.hour;
		var set = Sys.getDeviceSettings();
		if(set.is24Hour == false){
			if(h>11){ h-=12;}
			if(0==h){ h=12;}
		}

		// minutes
		dc.setColor(timeColor, Gfx.COLOR_TRANSPARENT);
		dc.setPenWidth(1);
		var minutes = clockTime.min; 
		var angle =  minutes.toFloat()/30.0*Math.PI;
		v = circleWidth>>1+1;
		r = dialSize ? radius.toFloat() : 1.12*radius;
		var rX = r*Math.sin(angle);
		var rY = r*Math.cos(angle);
		
		var beta = angle + Math.PI/2;
		var offX = v*Math.sin(beta);
		var offY = v*Math.cos(beta);
		var gap = (0.1*r).toNumber();
		var gapX = gap*Math.sin(angle);
		var gapY = gap*Math.cos(angle);		
		dc.drawLine(Math.round(centerX+gapX+offX), Math.round(centerY-gapY-offY), Math.round(centerX+rX+offX), Math.round(centerY-rY-offY));
		beta = beta - Math.PI;
		offX = v*Math.sin(beta);
		offY = v*Math.cos(beta);
		dc.drawLine(Math.round(centerX+gapX+offX), Math.round(centerY-gapY-offY), Math.round(centerX+rX+offX), Math.round(centerY-rY-offY));
		angle = 360*angle/(2*Math.PI)-90;
		dc.drawArc(Math.round(centerX+rX), Math.round(centerY-rY), v, Gfx.ARC_CLOCKWISE, -angle+90, -angle-90);

		// Hours
		var mode24 = false;
		angle =  h/(mode24==false ? 6.0 : 12.0)*Math.PI;
		dc.setColor(timeColor, Gfx.COLOR_TRANSPARENT);
		dc.drawText(Math.round(centerX + radius * Math.sin(angle)), Math.round(centerY - radius * Math.cos(angle)), fontSmall, h, Gfx.TEXT_JUSTIFY_CENTER | Gfx.TEXT_JUSTIFY_VCENTER);
		if(mode24==false && h==12){h=0;}
		h = h.toFloat() + minutes.toFloat()/60;
		
		dc.setColor(color, Gfx.COLOR_TRANSPARENT);
		angle =  h/(mode24==false ? 6.0 : 12.0)*Math.PI;

		//r = (0.7*radius-circleWidth/4).toNumber();
		//dc.drawLine(centerX+Math.round(circleWidth*Math.sin(angle)/2), centerY-Math.round(circleWidth*Math.cos(angle)/2), Math.round(centerX+r*Math.sin(angle)), Math.round(centerY-r*Math.cos(angle)));
		//r = (0.7*radius).toNumber();
		//dc.fillCircle(centerX, centerY, v);dc.fillCircle(Math.round(centerX+r*Math.sin(angle)), Math.round(centerY-r*Math.cos(angle)), v);

		r = 0.7*radius;
		beta = angle + Math.PI/2;
		rX = r*Math.sin(angle);
		rY = r*Math.cos(angle);
		
		
		offX = v*Math.sin(beta);
		offY = v*Math.cos(beta);
		beta = beta - Math.PI;
		var offX2 = v*Math.sin(beta);
		var offY2 = v*Math.cos(beta);
		dc.fillPolygon( [
			[Math.round(centerX+offX), 		Math.round(centerY-offY)], 
			[Math.round(centerX+rX+offX), 	Math.round(centerY-rY-offY)], 
			[Math.round(centerX+rX+offX2), 	Math.round(centerY-rY-offY2)], 
			[Math.round(centerX+offX2), 	Math.round(centerY-offY2)]
		]);
		v=v-1;
		dc.fillCircle(Math.round(centerX+rX), Math.round(centerY-rY), v);
		dc.fillCircle(centerX, centerY, v);
	}
	*/

	function drawTime (dc){
		// draw hour
		var h=clockTime.hour;
		var set = Sys.getDeviceSettings();
		if(set.is24Hour == false){
			if(h>11){ h-=12;}
			if(0==h){ h=12;}
		}
		// TODO if(set.notificationCount){dc.drawBitmap(centerX, notifY, iconNotification);}
		var minutes = clockTime.min; 
		// minutes=m; m++; // testing rendering
		//////Sys.println(minutes+ " mins mem " +Sys.getSystemStats().freeMemory);
		var angle =  minutes/60.0*2*Math.PI;
		var cos = Math.cos(angle);
		var sin = Math.sin(angle);
		var offset=0;
		var gap=0;
		dc.setColor(timeColor, Gfx.COLOR_TRANSPARENT);
		// TODO AOD overlapping 4>5 outlines etc // h=(h+7)%24; var d= new [24];for(var q=0;q<d.size();q++){d[q]=[0,0];}d[5]=[4,2];
		
		/* TODO AOD */ 
		if(burnInProtection){ 
			var stroke = (minutes==0 || minutes == 59 ) ? 3 : 1;
			for(var i=0;i<4;i++){
				dc.drawText((i&1<<1-1)*stroke + centerX, (i&3>>1<<1-1)*stroke + centerY-(dc.getFontHeight(fontHours)>>1), fontHours, h.format("%0.1d"), Gfx.TEXT_JUSTIFY_CENTER); 
			} 
			dc.setColor(backgroundColor, Gfx.COLOR_TRANSPARENT);
			if(stroke==2){
				for(var i=0;i<4;i++){
					dc.drawText(i&1<<1-1 + centerX,(i&3>>1<<1-1) + centerY-(dc.getFontHeight(fontHours)>>1), fontHours, h.format("%0.1d"), Gfx.TEXT_JUSTIFY_CENTER); 
				} 
			}

		}  else { /* TODO AOD */ 
			dc.setColor(timeColor, Gfx.COLOR_TRANSPARENT);
			dc.drawText(Math.round(centerX + (radius * sin)), Math.round(centerY - (radius * cos)) , fontSmall, minutes, Gfx.TEXT_JUSTIFY_CENTER | Gfx.TEXT_JUSTIFY_VCENTER);
		}
Sys.println(minutes);
			

		//}/* TODO AOD */ 
		dc.drawText(centerX, centerY-(dc.getFontHeight(fontHours)>>1), fontHours, h.format("%0.1d"), Gfx.TEXT_JUSTIFY_CENTER);
		if(minutes>0){
			dc.setColor(color, backgroundColor);
			dc.setPenWidth(circleWidth);
			
			// correct kerning not to have wild gaps between arc and minutes number
			//	padding values in px:
			//	1: 		4 
			//	2-6: 	6 
			//	7-9: 	8 
			//	10-11: 	11 
			//	12-22: 	9 
			//	23-51: 	11 
			//	52-59: 	12
			//	59: start offsetted by 4
			if(minutes>=10){
				if(minutes>=52){
					offset=12;	// 52-59
					if(minutes==59){
						gap=4;	
					} 
				} else {
					if(minutes>=12 && minutes<=22){ // 12-22
						offset=9;
					} else {
						offset=11;	// 10-11+23-51
					}
				}
			} else {
				if(minutes>=7){
					offset=8;	// 7-9
				} else {
					if(minutes==1){
						offset=4;	// 1
					} else {
						offset=6;	// 2-6
					}
				}
			}
			//if(burnInProtection){offset=0;gap=0;}
			dc.drawArc(centerX, centerY, radius, Gfx.ARC_CLOCKWISE, 90-gap, 90-minutes*6+offset);
		}
	}

	function drawBatteryLevel (dc){
		var bat = Sys.getSystemStats().battery;
		if(bat<=batThreshold){
			var xPos = centerX-10;
			var yPos = batteryY;

			// print the remaining %
			//var str = bat.format("%d") + "%";
			dc.setColor(backgroundColor, backgroundColor);
			dc.setPenWidth(1);
			dc.fillRectangle(xPos,yPos,20, 10);
			dc.setColor(bat<=15 ? Gfx.COLOR_RED : activityColor, backgroundColor);

			// draw the battery
			dc.drawRectangle(xPos, yPos, 19, 10);
			dc.fillRectangle(xPos + 19, yPos + 3, 1, 4);

			var lvl = floor((15.0 * (bat / 99.0)));
			if (1.0 <= lvl) { dc.fillRectangle(xPos + 2, yPos + 2, lvl, 6); }
			else {
				dc.setColor(Gfx.COLOR_ORANGE, backgroundColor);
				dc.fillRectangle(xPos + 1, yPos + 1, 1, 8);
			}
		}
	}

	(:data)
	function trimPastHoursInWeatherHourly(){
		var h = Sys.getClockTime().hour; // first hour of the forecast
		if (weatherHourly instanceof Array && weatherHourly.size()>5){
			if(weatherHourly[0]!=h){ // delayed response or time passed
				var gap = 5+h-weatherHourly[0];
				if(weatherHourly[0]>h){	// the delay is over midnight 
					gap = gap + 24;
				}
				weatherHourly = [h].addAll(weatherHourly.slice(1,5)).addAll(weatherHourly.slice(gap,null));
			} else {
				return h;
			}
		} else {
			weatherHourly = [];
			h = -1;
		}	
		app.setProperty("weatherHourly", weatherHourly);
		return h;
	}


	(:data)
	function drawWeather(dc){  //Sys.println("drawWeather: " + Sys.getSystemStats().freeMemory+ " " + weatherHourly);
		var h = trimPastHoursInWeatherHourly();
		/////Sys.println("weather from hour: "+h + " offset: "+offset);
		var limit; var step; var hours;
		if(d24){ 
			limit = 29; step = 15; hours = 24;
		} else {
			limit = 17; step = 30; hours = 12;
		}
		if(h>=0){
			dc.setPenWidth(height>=390 ? 8 : 5);
			var color; var center;
			//weatherHourly[10]=9;weatherHourly[12]=13;weatherHourly[13]=15;weatherHourly[15]=20;weatherHourly[16]=21; // testing colors

			// draw weather arcs
			for(var i=5; i<weatherHourly.size() && i<limit; i++, h++){
				color = weatherHourly[i];
				if(color>=0 && color < meteoColors.size()){
					color = meteoColors[color];
					h = h%hours;
					if(hours==12){
						center = h>=2 && h<8 ? centerX-1 : centerX; // correcting the center is not in the center because the display resolution is even
					} else {
						center = h>=4 && h<16 ? centerX-1 : centerX; // correcting the center is not in the center because the display resolution is even
					}
					/////Sys.println([i, h, weatherHourly[i], color]);
					dc.setColor(color, Gfx.COLOR_TRANSPARENT);
					dc.drawArc(center, center, centerY-1, Gfx.ARC_CLOCKWISE, 90-h*step, 90-(h+1)*step);
				}
			}
			// write temperature
			if(weatherHourly.size()>=5){ 
				var x = centerX+centerX>>1+4;
				var y = centerY-0.5*(dc.getFontHeight(fontCondensed));
				var gap = 0; 
				if(dialSize==0){
					y -= centerY>>1;
					//x += gap;
				} else {
					//x += dc.getFontHeight(icons)>>1;
					y -= dc.getFontHeight(icons)>>1;
				}		
				var min = weatherHourly[2];
				var max = weatherHourly[3];
				var t = weatherHourly[1];
				//min=80;max=99;t=99;
				/*var range;
					if(max-min>1){	// now, min-max
						range = min.toString();
						if(min<0){
							if(max>0){
								range += "+";
							} else if(max == 0){
								range += "-";
							}
						} else {
							range += "-";
						}
						range += max.toString()+"°";
						x -= dc.getTextWidthInPixels(range, fontCondensed)>>1;
						dc.setColor(dimmedColor, Gfx.COLOR_TRANSPARENT);
						dc.drawText(x, y+line, fontCondensed, range, Gfx.TEXT_JUSTIFY_LEFT);
					} 
					dc.setColor(activityColor, Gfx.COLOR_TRANSPARENT);
					dc.drawText(x, y, fontCondensed, t+"°", Gfx.TEXT_JUSTIFY_LEFT);	
					*/
				//var line = Gfx.getFontHeight(fontCondensed).toNumber()-6;
				var line;
				//t=90;min=90;max=99;
				if(max-min>1 && dialSize==0){	// now-range	
					var c = activityColor;
					var from; var to;
					if(t-min>max-t){
						from = min;
						to = t;
						c = dimmedColor;
					} else {
						from = t;
						to = max;
					}
					if(to>=0){
						if(from==t){
							if(to<100){	// tripple digits won't fit the screen
								to = (from>=0 || to == 0 ? "-" : "+") + to.toString();
							} else {
								to = "!";
							}
							from = from.toString()+ "°";
						} else {
							if(to<100){	// tripple digits won't fit the screen
								from = from.toString() + ( from>=0 || to == 0 ? "-" : "+");
							} else {
								from ="";
							}
							to = to.toString() + "°";
						}
					} else {
						if(from==t){
							from = from.toString()+"°";
							to = to.toString();
						} else {
							to = to.toString()+"°";
							from=from.toString();
						}
					}
					gap=((dc.getTextWidthInPixels(from, fontCondensed))-dc.getTextWidthInPixels(from+to, fontCondensed)>>1);

					var wd = dc.getTextWidthInPixels("0", fontCondensed)*3;
					line = Gfx.getFontHeight(fontCondensed).toNumber();
					dc.setPenWidth(1);
					dc.setColor(dimmedColor, backgroundColor);
					dc.drawLine(x-wd>>1, y+line, x+wd>>1, y+line);
					var bound = (t-min>max-t) ? x-wd>>1 : x+wd>>1;
					dc.drawLine(bound, y+line, x-wd>>1, y+line);
					var pct = (t-min).toFloat()/(max-min);
					dc.setPenWidth(3);
					dc.setColor(activityColor, backgroundColor);
					dc.drawLine(x-wd>>1 + pct*wd , y+line+1, x-wd>>1 + pct*wd, y+line+2);

					//x -= dc.getTextWidthInPixels(range, fontCondensed)>>1;
					dc.setColor(c, Gfx.COLOR_TRANSPARENT);
					dc.drawText(x+gap-1, y, fontCondensed, from, Gfx.TEXT_JUSTIFY_RIGHT);
					c = c == activityColor ? dimmedColor : activityColor;
					dc.setColor(c, Gfx.COLOR_TRANSPARENT);
					dc.drawText(x+gap+1, y, fontCondensed, to, Gfx.TEXT_JUSTIFY_LEFT);	
				} else {
					dc.setColor(activityColor, Gfx.COLOR_TRANSPARENT);
					dc.drawText(x, y, fontCondensed, t+"°", Gfx.TEXT_JUSTIFY_CENTER);	
				}
				//dc.drawText(x, y, fontCondensed, Math.round(weatherHourly[1]).toString()+"°", Gfx.TEXT_JUSTIFY_CENTER);	
				// precipitation
				var mm = weatherHourly[4];
				if(mm != null && mm>0.5){
					x = centerX-centerX>>1-6;
					//y -= (Gfx.getFontHeight(fontCondensed)*.2).toNumber();
					line = Math.round(0.55*Gfx.getFontHeight(fontCondensed)).toNumber();
					dc.setColor(dimmedColor, Gfx.COLOR_TRANSPARENT);
					dc.drawText(x-2, y+line, fontCondensed, "mm", Gfx.TEXT_JUSTIFY_CENTER);	
					dc.setColor(activityColor, Gfx.COLOR_TRANSPARENT);
					dc.drawText(x, y, fontCondensed, mm.format("%1.0f"), Gfx.TEXT_JUSTIFY_CENTER);	
				}
				//dc.setPenWidth(circleWidth);dc.drawArc(centerX, centerY, radius, Gfx.ARC_CLOCKWISE, 90, 90-350); // test overlapping
			}
		}
	}
	
	/*function abs(a){
		return a>=0 ? a : -a;
	}*/

	function toAngle(t){
		return (t + t.toNumber()%24-t.toNumber());
	}

	function drawIconAtTime(dc, t, icon){
		 var a = toAngle(t) * Math.PI/ (d24 ? 12.0 : 6.0 ) ; // radians (*= 60 * 2*PI/(24*60))  
		 drawIcon(dc, centerX + sunR*Math.sin(a), centerY - sunR*Math.cos(a), icon);
	}

	function drawSunBitmaps (dc, cal) {
		if(day != cal.day || utcOffset != clockTime.timeZoneOffset ){ // TODO should be recalculated rather when passing sunrise/sunset
			computeSun();
		}
		if(sunrise!= null) {
			dc.setColor(activityColor, Gfx.COLOR_TRANSPARENT);
			if(d24){ 
				drawIconAtTime(dc, sunrise, "*");	// sun
				drawIconAtTime(dc, sunset, "(");	// moon
				//Sys.println([sunrise, sunset]);
			} else {
				var time = clockTime.hour + clockTime.min/60.0;
				if(time>sunrise && time<=sunset ){
					drawIconAtTime(dc, sunset, "(");	// moon						
				} else {
					drawIconAtTime(dc, sunrise, "*");	// sun
				}
				//Sys.println([time, sunrise, sunset]);
			}

			//Sys.println(sunset.toNumber()+":"+(sunset.toFloat()*60-sunset.toNumber()*60).format("%1.0d")); /*dc.setColor(0x555555, 0); dc.drawText(centerX + (r * Math.sin(a))+moon.getWidth()+2, centerY - (r * Math.cos(a))-moon.getWidth()>>1, fontCondensed, sunset.toNumber()+":"+(sunset.toFloat()*60-sunset.toNumber()*60).format("%1.0d"), Gfx.TEXT_JUSTIFY_VCENTER|Gfx.TEXT_JUSTIFY_LEFT);*//*a = (clockTime.hour*60+clockTime.min).toFloat()/1440*360; System.println(a + " " + (centerX + (r*Math.sin(a))) + " " +(centerY - (r*Math.cos(a)))); dc.drawArc(centerX, centerY, 100, Gfx.ARC_CLOCKWISE, 90-a+2, 90-a);*/
		}
	}

	function computeSun() {	//var t = Calendar.info(Time.now(), Calendar.FORMAT_SHORT);//+Sys.println(t.hour +":"+ t.min + " computeSun: " + App.getApp().getProperty("location") + " accuracy: "+ Activity.getActivityInfo().accuracy);
		var loc = app.locate(true);
		if(loc == null){
			sunrise = null;
			return;
		}	
		// use absolute to get west as positive
		var lonW = loc[1].toFloat();
		var latN = loc[0].toFloat();


		// compute current date as day number from beg of year
		utcOffset = clockTime.timeZoneOffset;
		var timeInfo = Calendar.info(Time.now().add(new Time.Duration(utcOffset)), Calendar.FORMAT_SHORT);

		day = timeInfo.day;
		var now = dayOfYear(timeInfo.day, timeInfo.month, timeInfo.year);
		/////Sys.println("dayOfYear: " + now.format("%d"));
		sunrise = computeSunriset(now, lonW, latN, true);
		sunset = computeSunriset(now, lonW, latN, false);

		/*// max
		var max;
		if (latN >= 0){
			max = dayOfYear(21, 6, timeInfo.year);
			/////Sys.println("We are in NORTH hemisphere");
		} else{
			max = dayOfYear(21,12,timeInfo.year);			
			/////Sys.println("We are in SOUTH hemisphere");
		}
		sunrise[SUNRISET_MAX] = computeSunriset(max, lonW, latN, true);
		sunset[SUNRISET_MAX] = computeSunriset(max, lonW, latN, false);
		*/

		//adjust to timezone + dst when active
		var offset=new Time.Duration(utcOffset).value()/3600;
		sunrise += offset;
		sunset += offset;

		if(sunrise<0){
			sunrise = sunrise +24;
		}
		if(sunset<0){
			sunset = sunset +24;
		}

		/*for (var i = 0; i < SUNRISET_NBR; i++){
			sunrise[i] += offset;
			sunset[i] += offset;
		}


		for (var i = 0; i < SUNRISET_NBR-1 && SUNRISET_NBR>1; i++){
			if (sunrise[i]<sunrise[i+1]){
				sunrise[i+1]=sunrise[i];
			}
			if (sunset[i]>sunset[i+1]){
				sunset[i+1]=sunset[i];
			}
		}*/

		/*var sunriseInfoStr = new [SUNRISET_NBR]; var sunsetInfoStr = new [SUNRISET_NBR]; for (var i = 0; i < SUNRISET_NBR; i++){sunriseInfoStr[i] = Lang.format("$1$:$2$", [sunrise[i].toNumber() % 24, ((sunrise[i] - sunrise[i].toNumber()) * 60).format("%.2d")]); sunsetInfoStr[i] = Lang.format("$1$:$2$", [sunset[i].toNumber() % 24, ((sunset[i] - sunset[i].toNumber()) * 60).format("%.2d")]); //var str = i+":"+ "sunrise:" + sunriseInfoStr[i] + " | sunset:" + sunsetInfoStr[i]; /////Sys.println(str);}*/
		return;
	}
}