using Toybox.WatchUi as Ui;
using Toybox.Graphics as Gfx;
using Toybox.System as Sys;
using Toybox.Lang as Lang;
using Toybox.Time as Time;
using Toybox.Time.Gregorian as Calendar;
using Toybox.Activity as Activity;
using Toybox.Math as Math;
//using Toybox.ActivityMonitor as ActivityMonitor;
using Toybox.Application as App;

enum {SUNRISET_NOW=0,SUNRISET_MAX,SUNRISET_NBR}
var meteoColors;

class lateView extends Ui.WatchFace {
	hidden var dateForm; hidden var batThreshold = 33;
	hidden var centerX; hidden var centerY; hidden var height;
	hidden var color; hidden var timeColor = Gfx.COLOR_WHITE; hidden var dateColor = Gfx.COLOR_LT_GRAY; hidden var activityColor = Gfx.COLOR_DK_GRAY; hidden var backgroundColor = Gfx.COLOR_BLACK;
	hidden var calendarColors;
	var activity=null; var activityL=null; var activityR=null; var showSunrise = false; var dataLoading = false; var showWeather = false; var percentage = false;
	//hidden var icon=null; hidden var iconL=null; hidden var iconR=null; hidden var sunrs = null; hidden var sunst = null; //hidden var iconNotification;
	hidden var clockTime; hidden var utcOffset; hidden var day = -1;
	hidden var lonW; hidden var latN; hidden var sunrise = new [SUNRISET_NBR]; hidden var sunset = new [SUNRISET_NBR];
	hidden var fontSmall = null; hidden var fontHours = null; hidden var fontCondensed = null;
	hidden var dateY = null; hidden var radius; hidden var circleWidth = 3; hidden var dialSize = 0; hidden var batteryY; hidden var activityY; hidden var messageY; hidden var sunR; //hidden var temp; //hidden var notifY;
	hidden var icons;
	
	hidden var eventStart=null; hidden var eventName=""; hidden var eventLocation=""; hidden var eventTab=0; hidden var eventHeight=23; hidden var eventMarker=null; //eventEnd=0;
	hidden var events_list = [];
	var message = false;
	hidden var weatherHourly = [];
	// redraw full watchface
	hidden var redrawAll=2; 
	hidden var lastRedrawMin=-1;
	//hidden var dataCount=0;hidden var wakeCount=0;

	function initialize (){
		if(Ui.loadResource(Rez.Strings.DataLoading).toNumber()==1){ // our code is ready for data loading for this device
			dataLoading = Sys has :ServiceDelegate;	// watch is capable of data loading
		}
		WatchFace.initialize();
		var s=Sys.getDeviceSettings();
		height = s.screenHeight;
		centerX = s.screenWidth >> 1;
		centerY = height >> 1;
		clockTime = Sys.getClockTime();
		if(events_list.size()==0){
			var events = App.getApp().getProperty("events");
			if(events instanceof Toybox.Lang.Array){
				events_list = events;
			}
		}
		//Sys.println("init: "+ weatherHourly);
		if(weatherHourly.size()==0){
			var weather = App.getApp().getProperty("weatherHourly");
			if(weather instanceof Toybox.Lang.Array){
				weatherHourly = weather;
			}
		}
		//Sys.println("init: "+ weatherHourly);
	}

	function onLayout (dc) {
		loadSettings();
	}

	function loadSettings(){
		//////Sys.println("loadSettings");
		var app = App.getApp();
		dateForm = app.getProperty("dateForm");
		
		var activities = [null, :steps, :calories, :activeMinutesDay, :activeMinutesWeek, :floorsClimbed, :calendar];
		activity = activities[app.getProperty("activity")];
		activityL = activities[app.getProperty("activityL")];
		activityR = activities[app.getProperty("activityR")];

		showSunrise = app.getProperty("sunriset");
		batThreshold = app.getProperty("bat");
		circleWidth = app.getProperty("boldness");
		dialSize = app.getProperty("dialSize");
		showWeather = app.getProperty("weather");
		percentage = app.getProperty("percents");
		var tone = app.getProperty("tone").toNumber()%5;
		var mainColor = app.getProperty("mainColor").toNumber()%6;

activity = :calendar;
app.setProperty("activity", 6);
activityL = :steps;
activityR = :activeMinutesWeek;
showWeather = true; app.setProperty("weather", showWeather);
showSunrise = true;
dialSize=0;
circleWidth=7;
percentage = true;
mainColor = 3;
tone=0;
//weatherHourly = [21, 9, 0, 1, 2, 3, 4, 5];
app.setProperty("units", 1);
app.setProperty("location", [50.11, 14.49]);
//app.setProperty("calendar_ids", ["myneur@gmail.com","petr.meissner@gmail.com"]);
		//if(activity == :calendar && app.getProperty("refresh_token") == null){dialSize = 0;	/* there is no space to show code in strong mode */}

		if(dialSize>0){
			activityL=null;
			activityR=null;
		}
		// when running for the first time: load resources and compute sun positions
		if(showSunrise){ // TODO recalculate when day or position changes
			clockTime = Sys.getClockTime();
			utcOffset = clockTime.timeZoneOffset;
			computeSun();
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
		} else { 						// black background 
			backgroundColor = 0x0;
			timeColor = 0xFFFFFF;
			dateColor = 0xAAAAAA;
			activityColor = 0x555555;
		}

		meteoColors = [0xFFAA00,	0xAA5500,	0x005555, 0x0055FF,	0xAAAAAA, 0xFFFFFF];
			//enum {	clear, 		partly, 	lghtrain, rain,	 	mild snow, snow} // clean moon can be 555555 instead of sun and mostly cloudy can be skipped
		if(tone>2){
			meteoColors[2]=0x0055FF;
			meteoColors[3]=0x00AAFF;
			if(tone==4){		// color bg
				meteoColors[0]=0xFFFF55;
				meteoColors[1]=0xFFAA00;
				if(mainColor==2 || mainColor==3){	// green || blue
					meteoColors[2]=0;
					meteoColors[3]=0x0055FF;
				}
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

		if(height==208){	// FR45 with 8 colors do not support gray. Contrary the simluator, the real watch do not support even LT_GRAY. 
			activityColor = Gfx.COLOR_WHITE;
			dateColor = Gfx.COLOR_WHITE;
		}

		if(activity == :calendar){
			if(app.getProperty("calendar_colors")){	// match calendar colors to watch
				calendarColors = Ui.loadResource(Rez.JsonData.calendarColors)[mainColor];
				for(var i=0; i<calendarColors.size(); i++){
					calendarColors[i] = calendarColors[i].toNumberWithBase(0x10);
				}
				if(tone == 4) {	// clear current color
					calendarColors[0] = 0xFFFFFF;
					calendarColors[2] = 0x0;
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

		setLayoutVars();
		onShow();
	}

	function setLayoutVars(){
		/////Sys.println("Layout free memory: "+Sys.getSystemStats().freeMemory);
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
				sunR+=4;	
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
		if(activity != null){
			fontCondensed = Ui.loadResource(Rez.Fonts.Condensed);
			if(dialSize==0){
				activityY = (height>180) ? height-Gfx.getFontHeight(fontCondensed)-10 : centerY+80-Gfx.getFontHeight(fontCondensed)>>1 ;
				if(dataLoading && (activity == :calendar || showWeather)){
					eventHeight = Gfx.getFontHeight(fontCondensed)-1;
					messageY = (centerY-radius+10)>>2 - eventHeight + centerY+radius+10;						
				} else if(activity == :calendar){ 
					activity = null;
				}
			} else {
				activityY= centerY+Gfx.getFontHeight(fontHours)>>1+5;
				if(height<208){
					activityY -= 7;
				}
				if(activity==:calendar || showWeather){
					messageY =activityY - Gfx.getFontHeight(fontSmall)>>1; 
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
				showMessage(App.getApp().scheduleDataLoading());
				if(activity == :calendar){
					activityY = messageY;
				}
			} else {
				App.getApp().unScheduleDataLoading();
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
		//////Sys.println("onShow");
		
		if(centerX <=104){ // FR 45 needs to redraw the display every second
			redrawAll=100;
		} else {
			redrawAll=2; // 2: 2 clearDC() because of lag of refresh of the screen ?
		}
	}
	
	//! Called when this View is removed from the screen. Save the state of this View here. This includes freeing resources from memory.
	function onHide(){
		/////Sys.println("onHide");
		redrawAll=0;
	}
	
	//! The user has just looked at their watch. Timers and animations may be started here.
	function onExitSleep(){
		//////Sys.println("onExitSleep");
		//wakeCount++;
		onShow();
	}

	//! Terminate any active timers and prepare for slow updates.
	function onEnterSleep(){
		//////Sys.println("onEnterSleep");
		if(centerX <=104){ // FR 45 needs to redraw the display every second
			redrawAll=100;
			Ui.requestUpdate();
		} else {
			redrawAll=0; // 2: 2 clearDC() because of lag of refresh of the screen ?
		}
	}

	/*function openTheMenu(){
		menu = new MainMenu(self);
		Ui.pushView(new Rez.Menus.MainMenu(), new MyMenuDelegate(), Ui.SLIDE_UP);
	}*/

	//! Update the view
	function onUpdate (dc) {
		/////Sys.println("onUpdate "+redrawAll);
		clockTime = Sys.getClockTime();
		if (lastRedrawMin != clockTime.min && redrawAll==0) { redrawAll = 1; }
		//var ms = [Sys.getTimer()];
		if (redrawAll>0){
			//////Sys.println([clockTime.min, redrawAll, Sys.getSystemStats().freeMemory]);
			if(dc has :setAntiAlias) {
				dc.setAntiAlias(true);
			}
			dc.setColor(backgroundColor, backgroundColor);
			dc.clear();
			lastRedrawMin=clockTime.min;
			var info = Calendar.info(Time.now(), Time.FORMAT_MEDIUM);
			var h=clockTime.hour;
			// draw hour
			var set = Sys.getDeviceSettings();
			if(set.is24Hour == false){
				if(h>11){ h-=12;}
				if(0==h){ h=12;}
			}
			// TODO if(set.notificationCount){dc.drawBitmap(centerX, notifY, iconNotification);}
			dc.setColor(timeColor, Gfx.COLOR_TRANSPARENT);
			dc.drawText(centerX, centerY-(dc.getFontHeight(fontHours)>>1), fontHours, h.format("%0.1d"), Gfx.TEXT_JUSTIFY_CENTER);	
			drawBatteryLevel(dc);
			drawMinuteArc(dc);
			//ms.add(Sys.getTimer()-ms[0]);
			if(centerY>89){
				// function drawDate(x, y){}
				dc.setColor(dateColor, Gfx.COLOR_TRANSPARENT);
				var text = "";
				if(dateForm != null){
					text = Lang.format("$1$ ", ((dateForm == 0) ? [info.month] : [info.day_of_week]) );
				}
				text += info.day.format("%0.1d");
				dc.drawText(centerX, dateY, fontSmall, text, Gfx.TEXT_JUSTIFY_CENTER);

				if(Sys.getDeviceSettings().notificationCount){
					dc.setColor(activityColor, backgroundColor);
					dc.fillCircle(centerX-dc.getTextWidthInPixels(text, fontSmall)>>1-14, dateY+dc.getFontHeight(fontSmall)>>1+1, 5);
				}

				/*dc.drawText(centerX, height-20, fontSmall, ActivityMonitor.getInfo().moveBarLevel, Gfx.TEXT_JUSTIFY_CENTER | Gfx.TEXT_JUSTIFY_VCENTER);dc.setPenWidth(2);dc.drawArc(centerX, height-20, 12, Gfx.ARC_CLOCKWISE, 90, 90-(ActivityMonitor.getInfo().moveBarLevel.toFloat()/(ActivityMonitor.MOVE_BAR_LEVEL_MAX-ActivityMonitor.MOVE_BAR_LEVEL_MIN)*ActivityMonitor.MOVE_BAR_LEVEL_MAX)*360);*/
				dc.setColor(activityColor, Gfx.COLOR_TRANSPARENT);
				var x = centerX-radius - (sunR-radius)>>1-(dc.getTextWidthInPixels("1", fontSmall)/3).toNumber();	// scale 4 with resolution
				drawActivity(dc, activityL, x, centerY, false);
				drawActivity(dc, activityR, centerX<<1-x, centerY, false);
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
					if(day != info.day || utcOffset != clockTime.timeZoneOffset ){ // TODO should be recalculated rather when passing sunrise/sunset
						computeSun();
					}
					drawSunBitmaps(dc);
				}
				// TODO recalculate sunrise and sunset every day or when position changes (timezone is probably too rough for traveling)
				drawNowCircle(dc, clockTime.hour);
			}
		}
		//ms.add(Sys.getTimer()-ms[0]);
		/////Sys.println("ms: " + ms + " sec: " + clockTime.sec + " redrawAll: " + redrawAll);
		if (redrawAll>0) { redrawAll--; }
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
			var info = ActivityMonitor.getInfo();
			var activityChar = activity.toString().toCharArray()[0];	// replace with something less silly everywhere, like swithing everything to invoke and keeping just 1 char as the identifier
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
					drawActivityIcon(dc, x - dc.getTextWidthInPixels(info, fontCondensed)>>1 -2, y, activity);
				} else {
					drawActivityIcon(dc, x  -3, y-Gfx.getFontHeight(icons)-1, activity);
					dc.drawText(x, y+1, fontCondensed, info, Gfx.TEXT_JUSTIFY_VCENTER); 
				}
			}
		}
	}

	function drawIcon(dc, x, y, char){
		//dc.setColor(activityColor, 0xffffff);
		dc.drawText(x, y, icons, char, Gfx.TEXT_JUSTIFY_CENTER | Gfx.TEXT_JUSTIFY_VCENTER);
		//dc.setColor(0xff0000, 0xff0000);dc.setPenWidth(1);dc.drawLine(x-20, y, x+20, y);dc.drawLine(x, y-20, x, y+20);
	}
	function drawActivityIcon(dc, x, y, activity){
		//dc.setColor(activityColor, 0xffffff);
		dc.drawText(x, y, icons, activity.toString().toCharArray()[0], Gfx.TEXT_JUSTIFY_CENTER | Gfx.TEXT_JUSTIFY_VCENTER);
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

	function showMessage(msg){
		/////Sys.println("message "+message);
		if(msg instanceof Toybox.Lang.Dictionary && msg.hasKey("userPrompt")){
			var nowError = Time.now().value();
			message = true;
			if(msg.hasKey("wait")){
				nowError += msg["wait"].toNumber();
			}
			var context = msg.hasKey("userContext") ? " "+ msg["userContext"] : "";
			var calendar = msg.hasKey("permanent") ? -1 : 0;

			var degreeStart = ((nowError-Time.today().value())/(Calendar.SECONDS_PER_DAY.toFloat()/360)).toFloat(); // TODO bug: for some reason it won't show it at all althought the degrees are correct. 

			events_list = [[nowError, nowError+Calendar.SECONDS_PER_DAY, msg["userPrompt"].toString(), context, calendar, degreeStart, degreeStart+2]]; 
		}
	}

	(:data)
	function onBackgroundData(data) {
		//Sys.println("onBackgroundData view");
		//Sys.println(data);
		//dataCount++;
		if(data instanceof Array){	
			events_list = data;
		} 
		else if(data instanceof Toybox.Lang.Dictionary){
			if(data.hasKey("weather")){
				weatherHourly = data["weather"];
			}
			else if(data.hasKey("userPrompt")){
				showMessage(data);
			}
		}
		onShow();
	}

	(:data)
	function updateCurrentEvent(dc){
		for(var i=0; i<events_list.size(); i++){
			/////Sys.println("updateCurrentEvent: "+events_list);
			eventStart = new Time.Moment(events_list[i][0]);
			var timeNow = Time.now();
			var tillStart = eventStart.compare(timeNow);
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
			//eventEnd = (new Time.Moment(events_list[i][1])).value(); 
			eventName = height>=280 ? events_list[i][2] : events_list[i][2].substring(0,21); 

			//event["name"] += "w"+wakeCount+"d"+dataCount;	// debugging how often the watch wakes for updates every seconds
			if( tillStart <=0){
				eventStart = "now!";
				eventMarker = null;
			}
			else {
				if(tillStart >= Calendar.SECONDS_PER_HOUR-Calendar.SECONDS_PER_MINUTE*2 ) {
					eventMarker = null;				 
				} else {
					eventMarker = getMarkerCoords(events_list[i][0], tillStart);
				}
				if (tillStart < Calendar.SECONDS_PER_HOUR) {
					eventStart = tillStart/Calendar.SECONDS_PER_MINUTE + "m";
				} else if (tillStart < Calendar.SECONDS_PER_HOUR*8) {
					eventStart = tillStart/Calendar.SECONDS_PER_HOUR + "h" + tillStart%Calendar.SECONDS_PER_HOUR/Calendar.SECONDS_PER_MINUTE ;
				} else {
					var time = Calendar.info(eventStart, Calendar.FORMAT_SHORT);
					if(Sys.getDeviceSettings().is24Hour){
						eventStart = time.hour + ":"+ time.min.format("%02d");
					} else {
						var h = time.hour;
						if(h>11){ h-=12;}
						if(0==h){ h=12;}
						eventStart = (h.toString() + ":"+ time.min.format("%02d"));
					}
				}
			}
			eventLocation = height>=280 ? events_list[i][3] : events_list[i][3].substring(0,8);
			
			if(events_list[i][4]<0){ // no calendar event, but prompt
				eventTab = null;
				eventLocation = events_list[i][3];
			} else {
				eventTab = (
					dc.getTextWidthInPixels(eventStart+eventLocation, fontCondensed)>>1 
					-(dc.getTextWidthInPixels(eventStart, fontCondensed))
				);
			}
			return;
		}
		eventStart = null;
		eventMarker = null;
	}


	function humanizeNumber(number){
		if(number>1000) {
			return (number.toFloat()/1000).format("%1.1f")+"k";
		} else {
			return number.toString();
		}
	}

	function drawNowCircle(dc, hour){
		// show now in a day
		if(showSunrise || showWeather || (activity == :calendar && App.getApp().getProperty("refresh_token") != null)){
			var a = Math.PI/(12*60.0) * (hour*Calendar.SECONDS_PER_MINUTE+clockTime.min);
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
		updateCurrentEvent(dc);
		if(eventStart){
			dc.setColor(eventTab==null ? dateColor : activityColor, Gfx.COLOR_TRANSPARENT); // emphasized event without date
			dc.drawText(centerX, messageY, fontCondensed, eventName, Gfx.TEXT_JUSTIFY_CENTER);
			dc.setColor(dateColor, Gfx.COLOR_TRANSPARENT);
			// TODO remove prefix for simplicity and size limitations

			var x = centerX;
			var justify = Gfx.TEXT_JUSTIFY_CENTER;
			if(eventTab!=null){
				x-=eventTab;
				dc.drawText(x, messageY+eventHeight, fontCondensed, eventStart, Gfx.TEXT_JUSTIFY_RIGHT);
				dc.setColor(activityColor, Gfx.COLOR_TRANSPARENT);
				justify = Gfx.TEXT_JUSTIFY_LEFT;
			} 
			//else {dc.drawText(x,  height-batteryY, fontCondensed, eventStart, Gfx.TEXT_JUSTIFY_VCENTER);}
			dc.drawText(x, messageY+eventHeight, fontCondensed, eventLocation, justify);
		}
		if(eventMarker){
			var coord = eventMarker;
			dc.setColor(backgroundColor, backgroundColor);
			dc.fillCircle(coord[0], coord[1], 4);
			dc.setColor(dateColor, backgroundColor);
			dc.fillCircle(coord[0], coord[1], 2);
		}
	}

	(:data)
	function drawEvents(dc){
		var radius = centerY;
		var width;
		if(height >= 390){
			radius -= showWeather ? 11:7;
			width = 10;
		} else {
			radius -= showWeather ? 8:4;
			width = 6;	
		}
		
		var nowBoundary = ((clockTime.min+clockTime.hour*60.0)/1440)*360;
		var tomorrow = Time.now().value()+Calendar.SECONDS_PER_DAY;
		var degreeStart; var degreeEnd;

		/*var h; var idx=2;	// offset 
		var weatherStart; var weatherEnd;*/
		
		for(var i=0; i <events_list.size(); i++){
			//////Sys.println(events_list[i]);
			if(events_list[i][1]>=tomorrow && (events_list[i][6].toNumber() > nowBoundary )){ // crop tomorrow event overlapping now on 360° dial
				degreeStart=events_list[i][5].toNumber()%360;
				degreeEnd=nowBoundary-1;
				if(degreeEnd > events_list[0][5].toNumber()%360){	// not to overlapp the start of the current event
					degreeEnd = events_list[0][5].toNumber()%360-1;
				}
				if(degreeEnd-1 >= degreeStart){	// ensuring the 1° gap between the events did not switch the order of the start/end
					dc.setColor(backgroundColor, backgroundColor);
				}
			} else {
				degreeStart = events_list[i][5];
				degreeEnd = events_list[i][6]-1;
			}
			if(degreeEnd-1 >= degreeStart){ // ensuring the 1° gap between the events did not switch the order of the start/end
				/*if(showWeather && weatherHourly.size()>2){
					// counting overlap // first attempt was: // weatherStart = ((weatherHourly[0]+idx-2)*360/24)%360;weatherEnd = ((weatherHourly[0]+idx-2+1)*360/24)%360;degreeStart = degreeStart.toNumber()%360;degreeEnd = degreeEnd.toNumber()%360;while(idx<weatherHourly.size() && (degreeStart>weatherEnd || degreeEnd<weatherStart)){idx++;}radius = centerY - (idx<weatherHourly.size()? 2:7);
					weatherStart = (degreeStart*24.0/360).toNumber()%24;
					weatherEnd = Math.ceil(degreeEnd*24.0/360).toNumber()%24;
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
				dc.setColor(backgroundColor, backgroundColor);
				dc.setPenWidth(width);
				dc.drawArc(centerX, centerY, radius, Gfx.ARC_CLOCKWISE, 90-degreeStart+1, 90-degreeStart);
				if(events_list[i][4]>=0){
					dc.setColor(calendarColors[events_list[i][4]%(calendarColors.size())], backgroundColor);
				}
				dc.setPenWidth(width);
				dc.drawArc(centerX, centerY, radius, Gfx.ARC_CLOCKWISE, 90-degreeStart, 90-degreeEnd);	// draw event on dial
			}
		}
	}

	/*function drawIconP(percent, icon, dc){
		var a = percent * 2*Math.PI;
		var r = centerX-9;
		dc.drawText(0, 0, icons, "1", Gfx.TEXT_JUSTIFY_CENTER); //dc.drawBitmap(centerX+(r*Math.sin(a))-8, centerY-(r*Math.cos(a))-8, icon);
		return a;
	}*/

	(:data)
	function getMarkerCoords(event, tillStart){
		var secondsFromLastHour = event - (Time.now().value()-(clockTime.min*60+clockTime.sec));
		var a = (secondsFromLastHour).toFloat()/Calendar.SECONDS_PER_HOUR * 2*Math.PI;
		var r = tillStart>=120 || clockTime.min<10 ? radius : radius-Gfx.getFontHeight(fontSmall)>>1-1;
		return [centerX+(r*Math.sin(a)), centerY-(r*Math.cos(a))];
	}
	//var m = 0; testing rendering
	function drawMinuteArc (dc){
		var minutes = clockTime.min; 
		// minutes=m; m++; // testing rendering
		//////Sys.println(minutes+ " mins mem " +Sys.getSystemStats().freeMemory);
		var angle =  minutes/60.0*2*Math.PI;
		var cos = Math.cos(angle);
		var sin = Math.sin(angle);
		var offset=0;
		var gap=0;

		dc.setColor(timeColor, Gfx.COLOR_TRANSPARENT);
		dc.drawText(centerX + (radius * sin), centerY - (radius * cos) , fontSmall, minutes /*clockTime.min.format("%0.1d")*/, Gfx.TEXT_JUSTIFY_CENTER | Gfx.TEXT_JUSTIFY_VCENTER);
		
		
		if(minutes>0){
			dc.setColor(color, backgroundColor);
			dc.setPenWidth(circleWidth);
			
			/* correct kerning not to have wild gaps between arc and minutes number
				padding values in px:
				1: 		4 
				2-6: 	6 
				7-9: 	8 
				10-11: 	11 
				12-22: 	9 
				23-51: 	11 
				52-59: 	12
				59: start offsetted by 4
			*/
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

			if(bat<=15){
				dc.setColor(Gfx.COLOR_RED, backgroundColor);
			} else {
				dc.setColor(activityColor, backgroundColor);
			}
				
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
	function drawWeather(dc){ // hardcoded testing how to render the forecast
		//Sys.println("drawWeather: " + Sys.getSystemStats().freeMemory+ " " + weatherHourly);
		var h = Sys.getClockTime().hour; // first hour of the forecast
		if (weatherHourly instanceof Array && weatherHourly.size()>2){
			if(weatherHourly[0]<h){	// delayed response or time passed
				weatherHourly = weatherHourly.slice(0, 2).addAll(weatherHourly.slice(2+h-weatherHourly[0], null));
				weatherHourly[0]=h;
				App.getApp().setProperty("weatherHourly", weatherHourly);
				///Sys.println("trunc: "+ [h, weatherHourly]);
			} else if (weatherHourly[0]>h){
				weatherHourly = weatherHourly.slice(0, 2).addAll(weatherHourly.slice(2+h+24-weatherHourly[0], null));
				weatherHourly[0]=h;
				App.getApp().setProperty("weatherHourly", weatherHourly);
				///Sys.println("trunc: "+ [h, weatherHourly]);
			}
		} else {
			App.getApp().setProperty("weatherHourly", []);
			return; 
		}	
		/////Sys.println("weather from hour: "+h + " offset: "+offset);
		
		dc.setPenWidth(height>=390 ? 5 : 3);
		
		var color; var center;
		//weatherHourly[10]=9;weatherHourly[12]=13;weatherHourly[13]=15;weatherHourly[15]=20;weatherHourly[16]=21; // testing colors
		for(var i=2; i<weatherHourly.size() &&i<26; i++, h++){
			color = weatherHourly[i];
			/*if(i==10){color=3;}	// testing colors
			if(i==12){color=0;}
			if(i==13){color=1;}*/
			/////Sys.println([i, offset, color]);
			if(color>=0 && color < meteoColors.size()){
				color = meteoColors[color];
				h = h%24;
				center = h>=4 && h<16 ? centerX-1 : centerX; // correcting the center is not in the center because the display resolution is even
				/////Sys.println([i, h, weatherHourly[i], color]);
				dc.setColor(color, Gfx.COLOR_TRANSPARENT);
				dc.drawArc(center, center, centerY-1, Gfx.ARC_CLOCKWISE, 90-h*15, 90-(h+1)*15);
			}
		}
		if(weatherHourly.size()>1){
			dc.setColor(activityColor, Gfx.COLOR_TRANSPARENT);
			var x=centerX+centerX>>1;
			var y = centerY-(dc.getFontHeight(fontCondensed)>>1);
			if(dialSize==0){
				y -= centerY>>1;
			} else {
				x += dc.getFontHeight(icons)>>2;
			}
			dc.drawText(x, y, fontCondensed, weatherHourly[1].toString()+'°', Gfx.TEXT_JUSTIFY_CENTER);	
		}
	}

	function drawSunBitmaps (dc) {
		if(sunrise[SUNRISET_NOW] != null) {
			// SUNRISE (sun)
			dc.setColor(activityColor, Gfx.COLOR_TRANSPARENT);
			var a = ((sunrise[SUNRISET_NOW].toNumber() % 24) * 60) + ((sunrise[SUNRISET_NOW] - sunrise[SUNRISET_NOW].toNumber()) * 60);
			a *= Math.PI/(12 * 60.0);
			var r = sunR;
			drawIcon(dc, centerX + r*Math.sin(a), centerY - r*Math.cos(a), "*");
			
			// SUNSET (moon)
			a = ((sunset[SUNRISET_NOW].toNumber() % 24) * 60) + ((sunset[SUNRISET_NOW] - sunset[SUNRISET_NOW].toNumber()) * 60); 
			a *= Math.PI/(12 * 60.0);
			drawIcon(dc, centerX + r*Math.sin(a), centerY - r*Math.cos(a), "(");
			//System.println(sunset[SUNRISET_NOW].toNumber()+":"+(sunset[SUNRISET_NOW].toFloat()*60-sunset[SUNRISET_NOW].toNumber()*60).format("%1.0d")); /*dc.setColor(0x555555, 0); dc.drawText(centerX + (r * Math.sin(a))+moon.getWidth()+2, centerY - (r * Math.cos(a))-moon.getWidth()>>1, fontCondensed, sunset[SUNRISET_NOW].toNumber()+":"+(sunset[SUNRISET_NOW].toFloat()*60-sunset[SUNRISET_NOW].toNumber()*60).format("%1.0d"), Gfx.TEXT_JUSTIFY_VCENTER|Gfx.TEXT_JUSTIFY_LEFT);*//*a = (clockTime.hour*60+clockTime.min).toFloat()/1440*360; System.println(a + " " + (centerX + (r*Math.sin(a))) + " " +(centerY - (r*Math.cos(a)))); dc.drawArc(centerX, centerY, 100, Gfx.ARC_CLOCKWISE, 90-a+2, 90-a);*/
		}
	}

	function computeSun() {
		var pos = Activity.getActivityInfo().currentLocation;
		//pos = [50.11, 14.49];
		if (pos == null){
			pos = App.getApp().getProperty("location"); // load the last location to fix a Fenix 5 bug that is loosing the location often
			if(pos == null){
				sunrise[SUNRISET_NOW] = null;
				return;
			}			
		} else {
			pos = pos.toDegrees();
			App.getApp().setProperty("location", pos); // save the location to fix a Fenix 5 bug that is loosing the location often
		}
		//pos = [50.11, 14.49];
		/////Sys.println("computeSun: "+pos);
		// use absolute to get west as positive
		lonW = pos[1].toFloat();
		latN = pos[0].toFloat();


		// compute current date as day number from beg of year
		utcOffset = clockTime.timeZoneOffset;
		var timeInfo = Calendar.info(Time.now().add(new Time.Duration(utcOffset)), Calendar.FORMAT_SHORT);

		day = timeInfo.day;
		var now = dayOfYear(timeInfo.day, timeInfo.month, timeInfo.year);
		/////Sys.println("dayOfYear: " + now.format("%d"));
		sunrise[SUNRISET_NOW] = computeSunriset(now, lonW, latN, true);
		sunset[SUNRISET_NOW] = computeSunriset(now, lonW, latN, false);

		// max
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

		//adjust to timezone + dst when active
		var offset=new Time.Duration(utcOffset).value()/3600;
		for (var i = 0; i < SUNRISET_NBR; i++){
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
		}

		/*var sunriseInfoStr = new [SUNRISET_NBR]; var sunsetInfoStr = new [SUNRISET_NBR]; for (var i = 0; i < SUNRISET_NBR; i++){sunriseInfoStr[i] = Lang.format("$1$:$2$", [sunrise[i].toNumber() % 24, ((sunrise[i] - sunrise[i].toNumber()) * 60).format("%.2d")]); sunsetInfoStr[i] = Lang.format("$1$:$2$", [sunset[i].toNumber() % 24, ((sunset[i] - sunset[i].toNumber()) * 60).format("%.2d")]); //var str = i+":"+ "sunrise:" + sunriseInfoStr[i] + " | sunset:" + sunsetInfoStr[i]; /////Sys.println(str);}*/
		return;
	}
}