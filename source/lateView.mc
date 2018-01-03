using Toybox.WatchUi as Ui;
using Toybox.Graphics as Gfx;
using Toybox.System as Sys;
using Toybox.Lang as Lang;
using Toybox.Time as Time;
using Toybox.Time.Gregorian as Calendar;
using Toybox.Activity as Activity;
using Toybox.Math as Math;
using Toybox.Application as App;

enum {
    SUNRISET_NOW=0,
    SUNRISET_MAX,
    SUNRISET_NBR
}

class lateView extends Ui.WatchFace {
    hidden const CENTER = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;
    hidden var centerX;
    hidden var centerY;
    hidden var height;
    hidden var color = Graphics.COLOR_YELLOW;
    hidden var dateColor = 0x555555;
    hidden var activityColor = 0x555555;
    hidden var activity = 0;
    hidden var dateForm;
    hidden var showSunrise = false;
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
    }

    //! Load your resources here
    function onLayout (dc) {
        loadSettings();
    }

    function setLayoutVars(){
        if(height>218) {
            if(activity>0) {
                fontCondensed = Ui.loadResource(Rez.Fonts.Condensed240);
                activityY = (height>180) ? height-Gfx.getFontHeight(fontCondensed)-10 : centerY+80-Gfx.getFontHeight(fontCondensed)>>1 ;
            }
            if(dialSize>0) {
                fontMinutes = Ui.loadResource(Rez.Fonts.MinuteBig240);
                fontHours = Ui.loadResource(Rez.Fonts.HoursBig240px);
                fontSmall = Ui.loadResource(Rez.Fonts.SmallBig240);
                radius = 89;
                dateY = centerY-Gfx.getFontHeight(fontHours)>>1-Gfx.getFontHeight(fontMinutes)-7;
                batteryY=height-15 ;
                circleWidth=circleWidth*3+1;
                activityY= centerY+Gfx.getFontHeight(fontHours)>>1+5;
            } else {
                fontMinutes = Ui.loadResource(Rez.Fonts.Minute240);
                fontHours = Ui.loadResource(Rez.Fonts.Hours240px);
                fontSmall = Ui.loadResource(Rez.Fonts.Small240);
                radius = 63;    
                dateY = centerY-90-(Gfx.getFontHeight(fontSmall)>>1);
                batteryY = centerY+38;
            }
        } else {
            if(activity>0) {
                fontCondensed = Ui.loadResource(Rez.Fonts.Condensed);
                activityY = (height>180) ? height-Gfx.getFontHeight(fontCondensed)-10 : centerY+80-Gfx.getFontHeight(fontCondensed)>>1 ;    
            }
            if(dialSize>0) {
                fontMinutes = Ui.loadResource(Rez.Fonts.MinuteBig);
                fontHours = Ui.loadResource(Rez.Fonts.HoursBig);        
                fontSmall = Ui.loadResource(Rez.Fonts.SmallBig);
                radius = 81;
                dateY = centerY-Gfx.getFontHeight(fontHours)>>1-Gfx.getFontHeight(fontMinutes)-6;
                batteryY=height-15;
                circleWidth=circleWidth*3;
                activityY= centerY+Gfx.getFontHeight(fontHours)>>1+5;
            } else {
                fontMinutes = Ui.loadResource(Rez.Fonts.Minute);
                fontHours = Ui.loadResource(Rez.Fonts.Hours);     
                fontSmall = Ui.loadResource(Rez.Fonts.Small);   
                radius = 55;
                dateY = centerY-80-(Gfx.getFontHeight(fontSmall)>>1);
                batteryY = centerY+33;
                
            }
        }
        var langTest = Calendar.info(Time.now(), Time.FORMAT_MEDIUM).day_of_week.toCharArray()[0]; // test if the name of week is in latin. Name of week because name of month contains mix of latin and non-latin characters for some languages. 
        if(langTest.toNumber()>382) { // fallback for not-supported latin fonts 
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

        // when running for the first time: load resources and compute sun positions
        if (showSunrise) { // TODO recalculate when day or position changes
            moon = Ui.loadResource(Rez.Drawables.Moon);
            sun = Ui.loadResource(Rez.Drawables.Sun);
            sunrs = Ui.loadResource(Rez.Drawables.Sunrise);
            sunst = Ui.loadResource(Rez.Drawables.Sunset);
            clockTime = Sys.getClockTime();
            utcOffset = clockTime.timeZoneOffset;
            computeSun();
        }

        if (activity>0) {
            dateColor = 0xaaaaaa;
            if(activity == 1) {
                icon = Ui.loadResource(Rez.Drawables.Steps);
            } else if (activity == 2) { 
                icon = Ui.loadResource(Rez.Drawables.Cal);
            } else if (activity >= 3 && !(ActivityMonitor.getInfo() has :activeMinutesDay)) {
                activity = 0;   // reset not supported activities
            } else if (activity <= 4) {
                icon = Ui.loadResource(Rez.Drawables.Minutes);
            } else if(activity == 5) {
                icon = Ui.loadResource(Rez.Drawables.Floors);
            }
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

    //! Update the view
    function onUpdate (dc) {
        clockTime = Sys.getClockTime();

        if (lastRedrawMin != clockTime.min) {
            redrawAll = 1;
        }

        if (redrawAll!=0) {
            dc.setColor(0x00, 0x00);
            dc.clear();
            lastRedrawMin=clockTime.min;
            var info = Calendar.info(Time.now(), Time.FORMAT_MEDIUM);
            var h=clockTime.hour;

            if (showSunrise) {
                if (day != info.day || utcOffset != clockTime.timeZoneOffset ) { // TODO should be recalculated rather when passing sunrise/sunset
                    computeSun();
                }
                drawSunBitmaps(dc);
                // show now in a day
                var a = Math.PI/(12*60.0) * (h*60+clockTime.min);
                var r = centerX-5;

                dc.setColor(0x555555, 0);
                dc.setPenWidth(1);
                dc.drawCircle(centerX+((r-5)*Math.sin(a)), centerY-((r-5)*Math.cos(a)),4);

            }
            // TODO recalculate sunrise and sunset every day or when position changes (timezone is probably too rough for traveling)

            // draw hour
            if(Sys.getDeviceSettings().is24Hour == false){
                if (h>11) {
                    h-=12;
                }
                if (0==h) {
                    h=12;
                }
            }
            dc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_BLACK);
            dc.drawText(centerX, centerY-(dc.getFontHeight(fontHours)>>1), fontHours, h.format("%0.1d"), Gfx.TEXT_JUSTIFY_CENTER);    


            if (centerY>89) {

                // draw Day info
                dc.setColor(dateColor, Gfx.COLOR_BLACK);
                var text = "";
                if(dateForm != null){
                    text = Lang.format("$1$ ", ((dateForm == 0) ? [info.month] : [info.day_of_week]) );
                }
                text += info.day.format("%0.1d");
                dc.drawText(centerX, dateY, fontSmall, text, Gfx.TEXT_JUSTIFY_CENTER);

                // activity
                if (activity > 0) {
                    text = ActivityMonitor.getInfo();
                    if(activity == 1){ text = humanizeNumber(text.steps); }
                    else if(activity == 2){ text = humanizeNumber(text.calories); }
                    else if(activity == 3){ text = (text.activeMinutesDay.total.toString());} // moderate + vigorous
                    else if(activity == 4){ text = humanizeNumber(text.activeMinutesWeek.total); }
                    else if(activity == 5){ text = (text.floorsClimbed.toString()); }
                    else {text = "";}
                    dc.setColor(activityColor, Gfx.COLOR_BLACK);
                    dc.drawText(centerX + icon.getWidth()>>1, activityY, fontCondensed, text, Gfx.TEXT_JUSTIFY_CENTER); 
                    dc.drawBitmap(centerX - dc.getTextWidthInPixels(text, fontCondensed)>>1 - icon.getWidth()>>1-2, activityY+5, icon);
                }
            }
            drawBatteryLevel(dc);
            drawMinuteArc(dc);
        }

        if (0>redrawAll) {
            redrawAll--;
        }
    }

    function humanizeNumber(number) {
        if(number>1000) {
            return (number.toFloat()/1000).format("%1.1f")+"k";
        } else {
            return number.toString();
        }
    }

    function drawMinuteArc (dc) {
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
            59:-3
            */

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

        if(bat<=batThreshold){

            var xPos = centerX-10;
            var yPos = batteryY;

            dc.setColor(Gfx.COLOR_BLACK, Gfx.COLOR_BLACK);
            dc.setPenWidth(1);
            dc.fillRectangle(xPos,yPos,20, 10);

            if (bat<=15) {
                dc.setColor(Gfx.COLOR_RED, Gfx.COLOR_BLACK);
            } else {
                dc.setColor(Gfx.COLOR_DK_GRAY, Gfx.COLOR_BLACK);
            }

            // draw the battery

            dc.drawRectangle(xPos, yPos, 19, 10);
            dc.fillRectangle(xPos + 19, yPos + 3, 1, 4);

            var lvl = floor((15.0 * (bat / 99.0)));
            if (1.0 <= lvl) {
                dc.fillRectangle(xPos + 2, yPos + 2, lvl, 6);
            } else {
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
        }
    }

    function computeSun() {
        var pos = Activity.getActivityInfo().currentLocation;
        if (pos == null) {
            pos = App.getApp().getProperty("location"); // load the last location to fix a Fenix 5 bug that is loosing the location often
            if(pos == null) {
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
        sunrise[SUNRISET_NOW] = computeSunriset(now, lonW, latN, true);
        sunset[SUNRISET_NOW] = computeSunriset(now, lonW, latN, false);

        // max
        var max;
        if (latN >= 0) {
            max = dayOfYear(21, 6, timeInfo.year);
        } else{
            max = dayOfYear(21,12,timeInfo.year);
        }
        sunrise[SUNRISET_MAX] = computeSunriset(max, lonW, latN, true);
        sunset[SUNRISET_MAX] = computeSunriset(max, lonW, latN, false);

        //adjust to timezone + dst when active
        var offset=new Time.Duration(utcOffset).value()/3600;
        for (var i = 0; i < SUNRISET_NBR; i++){
            sunrise[i] += offset;
            sunset[i] += offset;
        }


        for (var i = 0; i < SUNRISET_NBR-1 && SUNRISET_NBR>1; i++) {
            if (sunrise[i]<sunrise[i+1]) {
                sunrise[i+1]=sunrise[i];
            }
            if (sunset[i]>sunset[i+1]) {
                sunset[i+1]=sunset[i];
            }
        }
    }
}