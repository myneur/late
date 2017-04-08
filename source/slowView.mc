using Toybox.WatchUi as Ui;
using Toybox.Graphics as Gfx;
using Toybox.System as Sys;
using Toybox.Lang as Lang;
using Toybox.Time as Time;
using Toybox.Time.Gregorian as Calendar;
using Toybox.Activity as Activity;

enum {       
    SUNRISET_NOW=0,
    SUNRISET_MAX,
    SUNRISET_NBR
}

class slowView extends Ui.WatchFace {
    var SinCosTableX = new [24];
    var SinCosTableY = new [24];
    var centerX;
    var centerY;

    var clockTime;

    // sunrise/sunset
	var utcOffset;
    var lonW;
	var latN;
    var sunrise = new [SUNRISET_NBR];
    var sunset = new [SUNRISET_NBR];

    // resources
    var moon = null;   
    var sun = null;   
    var fontSmall = null; 
    var fontHours = null; 
    
    // redraw full watchface
    var redrawAll=2; // 2: 2 clearDC() because of lag of refresh of the screen ?
    var lastRedrawMin=-1;
    
    var itemsBackGroundcolor = 0x00;
    
    function initialize (){
        var time=Sys.getTimer();
        WatchFace.initialize();
        var size=SinCosTableX.size();
        var val=36.0; // move '0 hour' at top of screen
        for (var i=0; i<size; ++i){
            var a = val * Math.PI * (1.0 / size) + 2.0;
            
            SinCosTableX[i] = Math.cos(a);
            SinCosTableY[i] = Math.sin(a);
        }
        var set=Sys.getDeviceSettings();
        centerX = set.screenWidth >> 1;
        centerY = set.screenHeight >> 1;
        
        //sunrise/sunset stuff
        clockTime = Sys.getClockTime();
    	utcOffset = new Time.Duration(clockTime.timeZoneOffset);
        computeSun();

        var dt=Sys.getTimer()-time;
        var str=dt.format("%d");
    }

    //! Load your resources here
    function onLayout (dc) {
        //setLayout(Rez.Layouts.WatchFace(dc));
        moon = Ui.loadResource(Rez.Drawables.Moon);
        sun = Ui.loadResource(Rez.Drawables.Sun);
        fontHours = Ui.loadResource(Rez.Fonts.Hours);        
        fontSmall = Ui.loadResource(Rez.Fonts.Small);
    }

    //! Called when this View is brought to the foreground. Restore
    //! the state of this View and prepare it to be shown. This includes
    //! loading resources into memory.
    function onShow() {
        redrawAll = 2;
    }
    
    //! Called when this View is removed from the screen. Save the
    //! state of this View here. This includes freeing resources from
    //! memory.
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

        var time = Sys.getTimer();
        clockTime = Sys.getClockTime();

        if (lastRedrawMin != clockTime.min) { redrawAll = 1; }

        if (0!=redrawAll)
        {
            dc.setColor(0x00, 0x00);
            dc.clear();
            lastRedrawMin=clockTime.min;
            drawSunBitmaps(dc);
           
            var now = Time.now();
            var info = Calendar.info(now, Time.FORMAT_MEDIUM);

            // draw hour
            var h=clockTime.hour;
            if (false==Sys.getDeviceSettings().is24Hour && h>11){
                h-=12;
                if (0==h) { h=12; }
            }
            dc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_BLACK);
            dc.drawText(centerX, centerY-(dc.getFontHeight(fontHours)>>1), fontHours, h.format("%0.1d"), Gfx.TEXT_JUSTIFY_CENTER);    

            drawMinuteArc(dc);        

            // draw Day info
            dc.setColor(0x555555, Gfx.COLOR_BLACK);
            dc.drawText(centerX, centerY-80-(dc.getFontHeight(fontSmall)>>1), fontSmall, Lang.format("$1$", [info.month]) + " " + info.day.format("%0.1d"), Gfx.TEXT_JUSTIFY_CENTER);
                         
        }
        /*// redrawAll
            dc.setColor(itemsBackGroundcolor, 0);
            dc.fillRoundedRectangle(centerX - 25, centerY - 49, 50, 16, 4);*/
        
        if (0>redrawAll) { redrawAll--; }
    }

    function drawMinuteArc (dc){
        var minutes = clockTime.min;
        var angle =  minutes/60.0*2*Math.PI;
        var cos = Math.cos(angle);
        var sin = Math.sin(angle);

        if(minutes>0){
            dc.setColor(0xff5500, 0);
            dc.setPenWidth(3);
            dc.drawArc(centerX, centerY, 55, Gfx.ARC_CLOCKWISE, 90, 90-minutes*6);
        }
        var fontHeight = (dc.getFontHeight(fontSmall) >> 1)+1;
        dc.setColor(Gfx.COLOR_WHITE, 0);
        dc.drawText(centerX + (50 * sin), centerY - (50 * cos) - fontHeight, fontSmall, clockTime.min.format("%0.1d"), Gfx.TEXT_JUSTIFY_CENTER);
    }


    function drawSunBitmaps (dc) {
        // SUNRISE (sun)
        var a = ((sunrise[SUNRISET_NOW].toNumber() % 24) * 60) + ((sunrise[SUNRISET_NOW] - sunrise[SUNRISET_NOW].toNumber()) * 60);
        a /= 12 * 60.0;
        a *= Math.PI;
        var r = centerX - 11;

        var cos = Math.cos(a);
        var sin = Math.sin(a);
        dc.drawBitmap(centerX + (r * sin)-6, centerY - (r * cos)-6, sun);

        // SUNSET (moon)
        a = ((sunset[SUNRISET_NOW].toNumber() % 24) * 60) + ((sunset[SUNRISET_NOW] - sunset[SUNRISET_NOW].toNumber()) * 60); 
        a /= 12 * 60.0;
        a *= Math.PI;
        cos = Math.cos(a);
        sin = Math.sin(a);
        dc.drawBitmap(centerX + (r * sin)-5, centerY - (r * cos)-6, moon);
    }

    function computeSun() {
        var pos = Activity.getActivityInfo().currentLocation;
        if (null == pos)
        {
            //Sys.println("Using Prague location as fallback:)");

            lonW = 14.4468582;
            latN = 50.1021213;
        }
        else
        {
            // use absolute to get west as positive
            lonW = pos.toDegrees()[1].toFloat();
            latN = pos.toDegrees()[0].toFloat();
        }

        // compute current date as day number from beg of year
        var timeInfo = Calendar.info(Time.now().add(utcOffset), Calendar.FORMAT_SHORT);

        var now = dayOfYear(timeInfo.day, timeInfo.month, timeInfo.year);
        //Sys.println("dayOfYear: " + now.format("%d"));
        sunrise[SUNRISET_NOW] = computeSunriset(now, lonW, latN, true);
        sunset[SUNRISET_NOW] = computeSunriset(now, lonW, latN, false);

        // max
        var max;
        if (latN >= 0)
        {
            max = dayOfYear(21, 6, timeInfo.year);
            //Sys.println("We are in NORTH hemisphere");
        } 
        else
        {
            max = dayOfYear(21,12,timeInfo.year);            
            //Sys.println("We are in SOUTH hemisphere");
        }
        sunrise[SUNRISET_MAX] = computeSunriset(max, lonW, latN, true);
        sunset[SUNRISET_MAX] = computeSunriset(max, lonW, latN, false);

        // adjust to daylight saving time if necessary
        if (null!=clockTime.dst)
        {
            var dst = clockTime.dst;
            Sys.println("DST: "+ dst.format("%d")+"s");        
            for (var i = 0; i < SUNRISET_NBR; i++)
            {
                sunrise[i] += dst/3600;
                sunset[i] += dst/3600;
                // hack because dst does not seem to work = is 0
                sunrise[i] += 1;
                sunset[i] += 1;
                
            }
        }

        for (var i = 0; i < SUNRISET_NBR-1 && SUNRISET_NBR>1; i++)
        {
            if (sunrise[i]<sunrise[i+1])
            {
                sunrise[i+1]=sunrise[i];
            }
            if (sunset[i]>sunset[i+1])
            {
                sunset[i+1]=sunset[i];
            }
        }

        var sunriseInfoStr = new [SUNRISET_NBR];
        var sunsetInfoStr = new [SUNRISET_NBR];
        for (var i = 0; i < SUNRISET_NBR; i++)
        {
            sunriseInfoStr[i] = Lang.format("$1$:$2$", [sunrise[i].toNumber() % 24, ((sunrise[i] - sunrise[i].toNumber()) * 60).format("%.2d")]);
            sunsetInfoStr[i] = Lang.format("$1$:$2$", [sunset[i].toNumber() % 24, ((sunset[i] - sunset[i].toNumber()) * 60).format("%.2d")]);
            var str = i+":"+ "sunrise:" + sunriseInfoStr[i] + " | sunset:" + sunsetInfoStr[i];
            Sys.println(str);
        }
   }
}