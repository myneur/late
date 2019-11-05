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

enum {       
    SUNRISET_NOW=0,
    SUNRISET_MAX,
    SUNRISET_NBR
}

class lateView extends Ui.WatchFace {
    hidden const CENTER = Gfx.TEXT_JUSTIFY_CENTER | Gfx.TEXT_JUSTIFY_VCENTER;
    hidden var centerX;
    hidden var centerY;
    hidden var height;
    hidden var color = Gfx.COLOR_YELLOW;
    hidden var dateColor = 0x555555;
    hidden var activityColor = 0x555555;
    hidden var activity = 0;
    hidden var dateForm;
    hidden var showSunrise = false;
    hidden var calendarColors = [0x00AAFF, 0x00AA00, 0x0055FF];

    hidden var utcOffset;
    hidden var clockTime;
    hidden var day = -1;
    // sunrise/sunset
    hidden var lonW;
	hidden var latN;
    hidden var sunrise = new [SUNRISET_NBR];
    hidden var sunset = new [SUNRISET_NBR];

    // resources
    hidden var moon = null;   
    hidden var sun = null; 
    hidden var sunrs = null;   
    hidden var sunst = null;   
    hidden var icon = null;

    hidden var fontSmall = null; 
    hidden var fontMinutes = null;
    hidden var fontHours = null; 
    hidden var fontCondensed = null;
    
    hidden var dateY = null;
    hidden var radius;
    hidden var circleWidth = 3; 
    hidden var dialSize = 0;
    hidden var batteryY;

    hidden var activityY;
    hidden var batThreshold = 5;

    hidden var event = {"name"=>"", "prefix"=>"in ", "start"=>0, "location"=>"", "mid"=>0, "height"=>25};
    hidden var events_list = [];
    
    // redraw full watchface
    hidden var redrawAll=2; // 2: 2 clearDC() because of lag of refresh of the screen ?
    hidden var lastRedrawMin=-1;
    
    function initialize (){
        var time=Sys.getTimer();
        WatchFace.initialize();
        var set=Sys.getDeviceSettings();
        height = set.screenHeight;
        centerX = set.screenWidth >> 1;
        centerY = height >> 1;
        //sunrise/sunset stuff
        clockTime = Sys.getClockTime();
        if(events_list.size()==0){
            var events = App.getApp().getProperty("events");
            if(events instanceof Toybox.Lang.Array){
                events_list = events;
            }
        }
    }

    //! Load your resources here
    // F5: 240px > F3: 218px > Epix: 148px 
    function onLayout (dc) {
        //setLayout(Rez.Layouts.WatchFace(dc));
        loadSettings();
    }

    function setLayoutVars(){
        try{
            if(height>218){
                if(dialSize>0){
                    radius = 89;
                    circleWidth=circleWidth*3+1;
                    batteryY=height-15 ;
                    fontHours = Ui.loadResource(Rez.Fonts.HoursBig240px);
                    fontMinutes = Ui.loadResource(Rez.Fonts.MinuteBig240);
                    fontSmall = Ui.loadResource(Rez.Fonts.SmallBig240);
                    dateY = centerY-Gfx.getFontHeight(fontHours)>>1-Gfx.getFontHeight(fontMinutes)-7;
                } else {
                    radius = 63;    
                    batteryY = centerY+38;
                    fontHours = Ui.loadResource(Rez.Fonts.Hours240px);
                    fontMinutes = Ui.loadResource(Rez.Fonts.Minute240);
                    fontSmall = Ui.loadResource(Rez.Fonts.Small240);
                    dateY = centerY-90-(Gfx.getFontHeight(fontSmall)>>1);
                }
            } else {
                if(dialSize>0){
                    radius = 81;
                    batteryY=height-15;
                    circleWidth=circleWidth*3;
                    fontHours = Ui.loadResource(Rez.Fonts.HoursBig);        
                    fontMinutes = Ui.loadResource(Rez.Fonts.MinuteBig);
                    fontSmall = Ui.loadResource(Rez.Fonts.SmallBig);
                    dateY = centerY-Gfx.getFontHeight(fontHours)>>1-Gfx.getFontHeight(fontMinutes)-6;
                } else {
                    radius = 55;
                    batteryY = centerY+33;
                    fontHours = Ui.loadResource(Rez.Fonts.Hours);     
                    fontMinutes = Ui.loadResource(Rez.Fonts.Minute);
                    fontSmall = Ui.loadResource(Rez.Fonts.Small);   
                    dateY = centerY-80-(Gfx.getFontHeight(fontSmall)>>1);
                }
            }
            if(activity>0){
                fontCondensed = Ui.loadResource(height>218 ?Rez.Fonts.Condensed240 : Rez.Fonts.Condensed);
                if(dialSize==0){
                    activityY = (height>180) ? height-Gfx.getFontHeight(fontCondensed)-10 : centerY+80-Gfx.getFontHeight(fontCondensed)>>1 ;
                    if(activity == 6){
                        if(Toybox.System has :ServiceDelegate){
                            event["height"] = Gfx.getFontHeight(fontCondensed)-1;
                            activityY = (centerY-radius+10)>>2 - event["height"] + centerY+radius+10;
                        } else { 
                            activity = 0;
                        }
                    }
                } else {
                    activityY= centerY+Gfx.getFontHeight(fontHours)>>1+5;
                }
            }
        } catch(ex){
            activity = 0;
            if(fontSmall == null ){ fontSmall = fontMinutes;}
        }


        var langTest = Calendar.info(Time.now(), Time.FORMAT_MEDIUM).day_of_week.toCharArray()[0]; // test if the name of week is in latin. Name of week because name of month contains mix of latin and non-latin characters for some languages. 
        if(langTest.toNumber()>382){ // fallback for not-supported latin fonts 
            fontSmall = Gfx.FONT_SMALL;
        }
        dateColor = 0xaaaaaa;
    }

    function loadSettings(){
        color = App.getApp().getProperty("color");
        dateForm = App.getApp().getProperty("dateForm");
        activity = App.getApp().getProperty("activity");
        showSunrise = App.getApp().getProperty("sunriset");
        batThreshold = App.getApp().getProperty("bat");
        circleWidth = App.getApp().getProperty("boldness");
        dialSize = App.getApp().getProperty("dialSize");

//color = 0x00AAFF;
activity = 6;
//showSunrise = true;
//batThreshold = 100;
//dialSize = 1;
//circleWidth = 3;

        // when running for the first time: load resources and compute sun positions
        if(showSunrise ){ // TODO recalculate when day or position changes
            moon = Ui.loadResource(Rez.Drawables.Moon);
            sun = Ui.loadResource(Rez.Drawables.Sun);
            sunrs = Ui.loadResource(Rez.Drawables.Sunrise);
            sunst = Ui.loadResource(Rez.Drawables.Sunset);
            clockTime = Sys.getClockTime();
            utcOffset = clockTime.timeZoneOffset;
            computeSun();
        }
        if(activity>0){ 
            dateColor = 0xaaaaaa;
            if(activity == 1) { icon = Ui.loadResource(Rez.Drawables.Steps); }
            else if(activity == 2) { icon = Ui.loadResource(Rez.Drawables.Cal); }
            else if(activity >= 3 && !(ActivityMonitor.getInfo() has :activeMinutesDay)){ 
                activity = 0;   // reset not supported activities
            } else if(activity <= 4) { icon = Ui.loadResource(Rez.Drawables.Minutes); }
            else if(activity == 5) { icon = Ui.loadResource(Rez.Drawables.Floors); }

        } else {
            dateColor = 0x555555;
        }
        redrawAll = 2;
        setLayoutVars();
    }

    //! Called when this View is brought to the foreground. Restore the state of this View and prepare it to be shown. This includes loading resources into memory.
    function onShow() {
        redrawAll = 2;
    }
    
    //! Called when this View is removed from the screen. Save the state of this View here. This includes freeing resources from memory.
    function onHide(){
        redrawAll =0;
    }
    
    //! The user has just looked at their watch. Timers and animations may be started here.
    function onExitSleep(){
        redrawAll = 2;
    }

    //! Terminate any active timers and prepare for slow updates.
    function onEnterSleep(){
        redrawAll =0;
    }

    /*function openTheMenu(){
        menu = new MainMenu(self);
        Ui.pushView(new Rez.Menus.MainMenu(), new MyMenuDelegate(), Ui.SLIDE_UP);
    }*/

    //! Update the view
    function onUpdate (dc) {
        clockTime = Sys.getClockTime();

        if (lastRedrawMin != clockTime.min) { redrawAll = 1; }

        if (redrawAll!=0){
            dc.setColor(0x00, 0x00);
            dc.clear();
            lastRedrawMin=clockTime.min;
            var info = Calendar.info(Time.now(), Time.FORMAT_MEDIUM);
            var h=clockTime.hour;
            if(showSunrise){
                if(day != info.day || utcOffset != clockTime.timeZoneOffset ){ // TODO should be recalculated rather when passing sunrise/sunset
                    computeSun();
                }
                drawSunBitmaps(dc);
            }
            // TODO recalculate sunrise and sunset every day or when position changes (timezone is probably too rough for traveling)

            // draw hour
            if(Sys.getDeviceSettings().is24Hour == false){
                if(h>11){ h-=12;}
                if(0==h){ h=12;}
            }
            dc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_BLACK);
            dc.drawText(centerX, centerY-(dc.getFontHeight(fontHours)>>1), fontHours, h.format("%0.1d"), Gfx.TEXT_JUSTIFY_CENTER);    
            if(centerY>89){
                // draw Day info
                dc.setColor(dateColor, Gfx.COLOR_BLACK);
                var text = "";
                if(dateForm != null){
                    text = Lang.format("$1$ ", ((dateForm == 0) ? [info.month] : [info.day_of_week]) );
                }
                text += info.day.format("%0.1d");
                dc.drawText(centerX, dateY, fontSmall, text, Gfx.TEXT_JUSTIFY_CENTER);

                /*dc.drawText(centerX, height-20, fontSmall, ActivityMonitor.getInfo().moveBarLevel, CENTER);
                dc.setPenWidth(2);
                dc.drawArc(centerX, height-20, 12, Gfx.ARC_CLOCKWISE, 90, 90-(ActivityMonitor.getInfo().moveBarLevel.toFloat()/(ActivityMonitor.MOVE_BAR_LEVEL_MAX-ActivityMonitor.MOVE_BAR_LEVEL_MIN)*ActivityMonitor.MOVE_BAR_LEVEL_MAX)*360);
                */
                //System.println(method(:humanizeNumber).invoke(100000)); // TODO this is how to save and invoke method callback to get rid of ugly ifelse like below
                // The best circle for activity percentages: dc.setPenWidth(2);dc.setColor(Gfx.COLOR_DK_GRAY, 0); dc.drawArc(centerX, 190, 10, Gfx.ARC_CLOCKWISE, 90, 90-49*6);

                if(activity > 0){
                    text = ActivityMonitor.getInfo();
                    if(activity == 1){ text = humanizeNumber(text.steps); }
                    else if(activity == 2){ text = humanizeNumber(text.calories); }
                    else if(activity == 3){ text = (text.activeMinutesDay.total.toString());} // moderate + vigorous
                    else if(activity == 4){ text = humanizeNumber(text.activeMinutesWeek.total); }
                    else if(activity == 5){ text = (text.floorsClimbed.toString()); }
                    else {text = "";}

                    dc.setColor(activityColor, Gfx.COLOR_BLACK);
                    if(activity < 6){
                        dc.drawText(centerX + icon.getWidth()>>1, activityY, fontCondensed, text, Gfx.TEXT_JUSTIFY_CENTER); 
                        dc.drawBitmap(centerX - dc.getTextWidthInPixels(text, fontCondensed)>>1 - icon.getWidth()>>1-2, activityY+5, icon);
                    } else { 
                        drawEvent(dc);
                        drawEvents(dc);
					}
                }
            }
            drawBatteryLevel(dc);
            drawMinuteArc(dc);
            if(activity == 6 || showSunrise){
                drawNowCircle(dc, h);
            }
        }
        
        if (0>redrawAll) { redrawAll--; }
    }

    function onBackgroundData(data) {
        events_list = data;
        redrawAll = 1;
    }

    function updateCurrentEvent(dc){
        for(var i=0; i<events_list.size(); i++){
            event["name"] = events_list[i]["name"]; // optimization move down

            event["start"] = new Time.Moment(events_list[i]["start"]);
            var duration = event["start"].compare(new Time.Moment(Time.now().value()));

            if(duration < -300){
              continue;  
            } else if( duration <0){
                event["start"] = "now!";
                event["prefix"] = "";
            } else {
                event["prefix"] = "in ";
                if (duration < 60*60) {
                    event["start"] = duration/60 + "m";
                } else {
                    event["start"] = duration/3600 + "h" + duration%3600/60 ;
                }
            }
            event["location"]=events_list[i]["location"];
            event["mid"] = (
                dc.getTextWidthInPixels(event["prefix"]+event["start"]+event["location"], fontCondensed)>>1 
                -(dc.getTextWidthInPixels(event["prefix"]+event["start"], fontCondensed))
            );
            break;
        }
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
        var a = Math.PI/(12*60.0) * (hour*60+clockTime.min);
        /*var bitmapNow = sun;
        if(a<sunset[SUNRISET_NOW] || a>sunrise[SUNRISET_NOW]){
            bitmapNow = moon;
        } 
        var r = centerX - 11;
        dc.drawBitmap(centerX + (r * Math.sin(a))-bitmapNow.getWidth()>>1, centerY - (r * Math.cos(a))-bitmapNow.getWidth()>>1, bitmapNow);*/
        
        var r = centerX-9;
        //dc.drawLine(centerX+(r*Math.sin(a)), centerY-(r*Math.cos(a)),centerX+((r-11)*Math.sin(a)), centerY-((r-11)*Math.cos(a)));
        dc.setColor(0, 0);
        dc.fillCircle(centerX+((r)*Math.sin(a)), centerY-((r)*Math.cos(a)),5);
        dc.setColor(dateColor, 0);
        dc.fillCircle(centerX+((r)*Math.sin(a)), centerY-((r)*Math.cos(a)),4);
    }

    function drawEvent(dc){
        updateCurrentEvent(dc);
        if(event["start"]){
            dc.drawText(centerX, activityY, fontCondensed, event["name"], Gfx.TEXT_JUSTIFY_CENTER);
            dc.setColor(dateColor, 0);
            dc.drawText(centerX-event["mid"], activityY+event["height"], fontCondensed, event["prefix"]+event["start"], Gfx.TEXT_JUSTIFY_RIGHT);
            dc.setColor(activityColor, Gfx.COLOR_BLACK);
            dc.drawText(centerX-event["mid"], activityY+event["height"], fontCondensed, event["location"], Gfx.TEXT_JUSTIFY_LEFT);
        }
    }

    function drawEvents(dc){
        dc.setPenWidth(5);
        dc.setColor(activityColor, 0);
        var nowBoundary = ((clockTime.min+clockTime.hour*60.0)/1440)*360-1;
        var tomorrow = Time.today().value()+3600*24;

        for(var i=0; i <events_list.size(); i++){
            dc.setColor(0, 0);
            
            if(events_list[i]["end"]>=tomorrow){
                events_list[i]["degreeStart"]=events_list[i]["degreeStart"].toNumber()%360;
                events_list[i]["degreeEnd"]=nowBoundary;
            }
            dc.drawArc(centerX, centerY, centerY-2, Gfx.ARC_CLOCKWISE, 90-events_list[i]["degreeStart"]+1, 90-events_list[i]["degreeStart"]);
            if(events_list[i]["cal"]!=null){
                dc.setColor(calendarColors[events_list[i]["cal"]%(calendarColors.size())], 0);
            }
            dc.drawArc(centerX, centerY, centerY-2, Gfx.ARC_CLOCKWISE, 90-events_list[i]["degreeStart"], 90-events_list[i]["degreeEnd"]);
        }
    }

    function drawMinuteArc (dc){
        var minutes = clockTime.min; 
        var angle =  minutes/60.0*2*Math.PI;
        var cos = Math.cos(angle);
        var sin = Math.sin(angle);
        var offset=0;
        var gap=0;

        dc.setColor(Gfx.COLOR_WHITE, 0);
        dc.drawText(centerX + (radius * sin), centerY - (radius * cos) , fontMinutes, minutes /*clockTime.min.format("%0.1d")*/, CENTER);

        if(minutes>0){
            dc.setColor(color, 0);
            dc.setPenWidth(circleWidth);
            
            /* kerning values not to have ugly gaps between arc and minutes
            minute:padding px
            1:4 
            2-6:6 
            7-9:8 
            10-11:10 
            12-22:9 
            23-51:10 
            52-59:12
            59:-3*/

            // correct font kerning not to have wild gaps between arc and number
            if(minutes>=10){
                if(minutes>=52){
                    offset=12;
                    if(minutes==59){
                        gap=4;    
                    } 
                } else {
                    if(minutes>=12&&minutes<=22){
                        offset=9;
                    }
                    else {
                        offset=10;
                    }
                }
            } else {
                if(minutes>=7){
                    offset=8;
                } else {
                    if(minutes==1){
                        offset=4;
                    } else {
                        offset=6;
                    }
                }

            }
            dc.drawArc(centerX, centerY, radius, Gfx.ARC_CLOCKWISE, 90-gap, 90-minutes*6+offset);
        }
        
    }

    function drawBatteryLevel (dc){
        var bat = Sys.getSystemStats().battery;
        //batThreshold=100;bat = 10;

        if(bat<=batThreshold){

            var xPos = centerX-10;
            var yPos = batteryY;

            // print the remaining %
            //var str = bat.format("%d") + "%";
            dc.setColor(Gfx.COLOR_BLACK, Gfx.COLOR_BLACK);
            dc.setPenWidth(1);
            dc.fillRectangle(xPos,yPos,20, 10);

            if(bat<=15){
                dc.setColor(Gfx.COLOR_RED, Gfx.COLOR_BLACK);
            } else {
                dc.setColor(Gfx.COLOR_DK_GRAY, Gfx.COLOR_BLACK);
            }
                
            // draw the battery

            dc.drawRectangle(xPos, yPos, 19, 10);
            dc.fillRectangle(xPos + 19, yPos + 3, 1, 4);

            var lvl = floor((15.0 * (bat / 99.0)));
            if (1.0 <= lvl) { dc.fillRectangle(xPos + 2, yPos + 2, lvl, 6); }
            else {
                dc.setColor(Gfx.COLOR_ORANGE, Gfx.COLOR_BLACK);
                dc.fillRectangle(xPos + 1, yPos + 1, 1, 8);
            }
        }
    }


    function drawSunBitmaps (dc) {
        if(sunrise[SUNRISET_NOW] != null) {
            // SUNRISE (sun)
            var a = ((sunrise[SUNRISET_NOW].toNumber() % 24) * 60) + ((sunrise[SUNRISET_NOW] - sunrise[SUNRISET_NOW].toNumber()) * 60);
            a *= Math.PI/(12 * 60.0);
            var r = centerX - 11;
            dc.drawBitmap(centerX + (r * Math.sin(a))-sunrs.getWidth()>>1, centerY - (r * Math.cos(a))-sunrs.getWidth()>>1, sunrs);
            
            // SUNSET (moon)
            a = ((sunset[SUNRISET_NOW].toNumber() % 24) * 60) + ((sunset[SUNRISET_NOW] - sunset[SUNRISET_NOW].toNumber()) * 60); 
            a *= Math.PI/(12 * 60.0);
            dc.drawBitmap(centerX + (r * Math.sin(a))-sunst.getWidth()>>1, centerY - (r * Math.cos(a))-sunst.getWidth()>>1, sunst);
            //System.println(sunset[SUNRISET_NOW].toNumber()+":"+(sunset[SUNRISET_NOW].toFloat()*60-sunset[SUNRISET_NOW].toNumber()*60).format("%1.0d"));

            /*dc.setColor(0x555555, 0);
            dc.drawText(centerX + (r * Math.sin(a))+moon.getWidth()+2, centerY - (r * Math.cos(a))-moon.getWidth()>>1, fontCondensed, sunset[SUNRISET_NOW].toNumber()+":"+(sunset[SUNRISET_NOW].toFloat()*60-sunset[SUNRISET_NOW].toNumber()*60).format("%1.0d"), Gfx.TEXT_JUSTIFY_VCENTER|Gfx.TEXT_JUSTIFY_LEFT);*/

            /*a = (clockTime.hour*60+clockTime.min).toFloat()/1440*360;
            System.println(a + " " + (centerX + (r*Math.sin(a))) + " " +(centerY - (r*Math.cos(a))));
            dc.drawArc(centerX, centerY, 100, Gfx.ARC_CLOCKWISE, 90-a+2, 90-a);*/
        }
    }

    function computeSun() {
        var pos = Activity.getActivityInfo().currentLocation;
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
        // use absolute to get west as positive
        lonW = pos[1].toFloat();
        latN = pos[0].toFloat();


        // compute current date as day number from beg of year
        utcOffset = clockTime.timeZoneOffset;
        var timeInfo = Calendar.info(Time.now().add(new Time.Duration(utcOffset)), Calendar.FORMAT_SHORT);

        day = timeInfo.day;
        var now = dayOfYear(timeInfo.day, timeInfo.month, timeInfo.year);
        //Sys.println("dayOfYear: " + now.format("%d"));
        sunrise[SUNRISET_NOW] = computeSunriset(now, lonW, latN, true);
        sunset[SUNRISET_NOW] = computeSunriset(now, lonW, latN, false);

        // max
        var max;
        if (latN >= 0){
            max = dayOfYear(21, 6, timeInfo.year);
            //Sys.println("We are in NORTH hemisphere");
        } else{
            max = dayOfYear(21,12,timeInfo.year);            
            //Sys.println("We are in SOUTH hemisphere");
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

        /*var sunriseInfoStr = new [SUNRISET_NBR];
        var sunsetInfoStr = new [SUNRISET_NBR];
        for (var i = 0; i < SUNRISET_NBR; i++)
        {
            sunriseInfoStr[i] = Lang.format("$1$:$2$", [sunrise[i].toNumber() % 24, ((sunrise[i] - sunrise[i].toNumber()) * 60).format("%.2d")]);
            sunsetInfoStr[i] = Lang.format("$1$:$2$", [sunset[i].toNumber() % 24, ((sunset[i] - sunset[i].toNumber()) * 60).format("%.2d")]);
            //var str = i+":"+ "sunrise:" + sunriseInfoStr[i] + " | sunset:" + sunsetInfoStr[i];
            //Sys.println(str);
        }*/
        return;
    }
}