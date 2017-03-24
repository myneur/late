using Toybox.WatchUi as Ui;
using Toybox.Graphics as Gfx;
using Toybox.System as Sys;
using Toybox.Lang as Lang;
using Toybox.Time as Time;
using Toybox.Time.Gregorian as Calendar;
using Toybox.Activity as Activity;

enum
{       
    SUNRISET_NOW=0,
    SUNRISET_MAX,
    SUNRISET_NBR
}

class slowView extends Ui.WatchFace
{
    var debugHour = 0;
    var SinCosTableX = new [24];
    var SinCosTableY = new [24];
    var centerX;
    var centerY;
    // logs
    var _initCount = 0;
    var _refreshCount = 0;

    var clockTime;

    // sunrise/sunset
	var utcOffset;
    var lonW;
	var latN;
    var sunrise = new [SUNRISET_NBR];
    var sunset = new [SUNRISET_NBR];
    var dayColor;

    // resources
    var moon = null;   
    var sun = null;   
    var fontGeneva10 = null; // geneva10
    var fontGeneva15 = null; // geneva15
    var fontGeneva22 = null; // geneva22
    var fontGeneva72 = null; // geneva72
    
    // redraw full watchface
    var redrawAll=2; // 2: 2 clearDC() because of lag of refresh of the screen ?
    var lastRedrawMin=-1;
    
    var batBlinkCritical = true;
    var itemsBackGroundcolor = 0x00;
    
    function initialize ()
    {
        Sys.println("slow watch started...");
        var time=Sys.getTimer();
        _initCount++;
        WatchFace.initialize();
        var size=SinCosTableX.size();
        var val=36.0; // move '0 hour' at top of screen
        for (var i=0; i<size; ++i)
        {
            var a = val * Math.PI * (1.0 / size);
            val+=2.0;
            
            SinCosTableX[i] = Math.cos(a);
            SinCosTableY[i] = Math.sin(a);
        }
        var set=Sys.getDeviceSettings();
        centerX = set.screenWidth >> 1;
        centerY = set.screenHeight >> 1;
        
        // dayColor = new [7];
        // dayColor[0] = 0x0000ff;
        // dayColor[1] = 0x00aaff;
        // dayColor[2] = 0x00aa00;
        // dayColor[3] = 0x00ff00;
        // dayColor[4] = 0xffaa00;
        // dayColor[5] = 0xff5500;
        // dayColor[6] = 0x0000ff;
        
        //sunrise/sunset stuff
        clockTime = Sys.getClockTime();
    	utcOffset = new Time.Duration(clockTime.timeZoneOffset);
        Sys.println("utc offset: "+ (utcOffset.value()/3600).format("%d") + "h");
        computeSun();

        var dt=Sys.getTimer()-time;
        var str=dt.format("%d");
        Sys.println("initialize:"+str+"ms");
    }

    //! Load your resources here
    function onLayout (dc) 
    {
        //setLayout(Rez.Layouts.WatchFace(dc));
        moon = Ui.loadResource(Rez.Drawables.Moon);
        sun = Ui.loadResource(Rez.Drawables.Sun);
        fontGeneva72 = Ui.loadResource(Rez.Fonts.Geneva72);        
        fontGeneva22 = Ui.loadResource(Rez.Fonts.Geneva22);
        fontGeneva15 = Ui.loadResource(Rez.Fonts.Geneva15);
        fontGeneva10 = Ui.loadResource(Rez.Fonts.Geneva10);
    }

    //! Called when this View is brought to the foreground. Restore
    //! the state of this View and prepare it to be shown. This includes
    //! loading resources into memory.
    function onShow() 
    {
        redrawAll = 2;
    }
    
    //! Called when this View is removed from the screen. Save the
    //! state of this View here. This includes freeing resources from
    //! memory.
    function onHide() 
    {
        redrawAll =0;
    }
    
    //! The user has just looked at their watch. Timers and animations may be started here.
    function onExitSleep()
    {
        redrawAll = 2;
    }

    //! Terminate any active timers and prepare for slow updates.
    function onEnterSleep()
    {
        redrawAll =0;
    }

    //! Draw the watch hand
    //! @param dc Device Context to Draw
    //! @param angle Angle to draw the watch hand
    //! @param length Length of the watch hand
    //! @param width Width of the watch hand

    function drawMinuteArc (dc){
        var minutes = clockTime.min;
        var angle =  minutes/60.0*2*Math.PI;
        var cos = Math.cos(angle);
        var sin = Math.sin(angle);

        /*var wRoundRect = dc.getTextWidthInPixels(clockTime.hour.format("%0.1d")+":", fontGeneva22);
        var hRoundRect = dc.getFontHeight(fontGeneva22)-3;
        dc.setColor(itemsBackGroundcolor, 0);
        dc.fillCircle(centerX + (yPos * sin), centerY - (yPos * cos), (wRoundRect>>1)+2);*/

        if(minutes>0){
            dc.setColor(0xff5500, 0);
            dc.setPenWidth(3);
            dc.drawArc(centerX, centerY, 50, Gfx.ARC_CLOCKWISE, 90, 90-minutes*6);
        }
        var fontHeight = (dc.getFontHeight(fontGeneva10) >> 1)+1;
        dc.setColor(Gfx.COLOR_WHITE, 0);
        dc.drawText(centerX + (50 * sin), centerY - (50 * cos) - fontHeight, fontGeneva10, clockTime.min.format("%0.1d"), Gfx.TEXT_JUSTIFY_CENTER);
        
        /*dc.setColor(0xaaFF00, -1);
        //Draw hour on hand with background        
        dc.setColor(itemsBackGroundcolor, 0);
        dc.fillRoundedRectangle(centerX + (yPos * sin)-(wRoundRect>>1)-1, centerY - (yPos * cos)-hRoundRect>>1, wRoundRect, hRoundRect, 4);
        dc.setColor(0xaaFF00, -1);
        var posX = centerX + (yPos * sin)-wRoundRect>>1;
        dc.drawText(posX+1, posY-5, fontGeneva22, clockTime.hour.format("%0.1d")+":", Gfx.TEXT_JUSTIFY_LEFT);*/
    }

    // draw alarm, width=10px
    function drawAlarm (dc)
    {
        var alarmCnt = Sys.getDeviceSettings().alarmCount;
        if (0==alarmCnt) { return; }
        Sys.println("active alarms...");

        var xPos = centerX-27;
        var yPos = centerY-49;
                
        dc.setColor(0x555555, 0);
        dc.fillRectangle(xPos, yPos, 10, 10);

        // draw the round
        dc.setColor(0x00, 0);
        dc.drawPoint(xPos, yPos);
        dc.drawPoint(xPos+9, yPos);
        dc.drawPoint(xPos, yPos+9);
        dc.drawPoint(xPos+9, yPos+9);

        dc.drawLine(xPos, yPos + 1, xPos + 2, yPos - 1);
        dc.drawLine(xPos+9, yPos+1, xPos+7, yPos-1);
        dc.drawLine(xPos, yPos+8, xPos+2, yPos+9);
        dc.drawLine(xPos+8, yPos+9, xPos+9, yPos+7);

        // draw the hands
        dc.drawLine(xPos+3, yPos+5, xPos+6, yPos+5);
        dc.drawLine(xPos+5, yPos+2, xPos+5, yPos+5);

        // draw the AA
        dc.setColor(0x444444, 0);
        dc.drawLine(xPos, yPos+2, xPos+3, yPos-1);
        dc.drawLine(xPos+9, yPos+2, xPos+6, yPos-1);
        dc.drawLine(xPos, yPos+7, xPos+3, yPos+10);
        dc.drawLine(xPos+7, yPos+9, xPos+10, yPos+6);
    }

    // draw battery level w/ text
    function drawBatteryLevel (dc)
    {
        var bat = Sys.getSystemStats().battery;

        var xPos = centerX;
        var yPos = centerY - 62;

        // print the remaining %
        var str = bat.format("%d") + "%";
        var fontHeight = dc.getFontHeight(fontGeneva10)>>2;

        if (2.0 >= bat)
        {
            dc.setColor(0xffffff, 0);
            dc.drawText(xPos, yPos, fontGeneva10, str, Gfx.TEXT_JUSTIFY_CENTER);
            dc.setColor(0xaa0000, 0);
        }
        else if (5.0 >= bat)
        {
            dc.setColor(0xffffff, 0);
            dc.drawText(xPos, yPos, fontGeneva10, str, Gfx.TEXT_JUSTIFY_CENTER);
            dc.setColor(0xff0000, 0);
        }
        else if (10.0 >= bat)
        {
            dc.setColor(0xff5500, 0);
            dc.drawText(xPos, yPos, fontGeneva10, str, Gfx.TEXT_JUSTIFY_CENTER);
        }
        /*else if (50.0 >= bat)
        {
            dc.setColor(0x555555, 0);
            dc.drawText(xPos, yPos, fontGeneva10, str, Gfx.TEXT_JUSTIFY_CENTER);            
        }*/
        if(bat <= 10.0){
            xPos -= 10;
            yPos = centerY - 49;

            if (5 >= bat)
            {
                batBlinkCritical = !batBlinkCritical;
            }
                    
            dc.setColor(itemsBackGroundcolor, 0);
            dc.fillRectangle(xPos,yPos,24, 10);
            if (true==batBlinkCritical)
            {
                // draw the battery
                dc.setColor(0x555555, 0);
                dc.drawRectangle(xPos, yPos, 19, 10);
                dc.fillRectangle(xPos + 19, yPos + 3, 1, 4);            

                var lvl = floor((15.0 * (bat / 99.0)));
                if (1.0 <= lvl) { dc.fillRectangle(xPos + 2, yPos + 2, lvl, 6); }
                else
                {
                    dc.setColor(0xff5500, 0);
                    dc.fillRectangle(xPos + 1, yPos + 1, 1, 8);
                }

                // add the antialiasing :)

                // dc.setColor(0x00, 0);
                // dc.drawPoint(xPos, yPos);
                // dc.drawPoint(xPos, yPos+9);
                // dc.drawPoint(xPos+18, yPos);
                // dc.drawPoint(xPos+18, yPos+9);
                // dc.drawPoint(xPos+20, yPos+2);
                // dc.drawPoint(xPos+20, yPos+7);
            }
        }
    }

    function drawSunBitmaps (dc)
    {
        // SUNRISE (sun)
        var a = ((sunrise[SUNRISET_NOW].toNumber() % 24) * 60) + ((sunrise[SUNRISET_NOW] - sunrise[SUNRISET_NOW].toNumber()) * 60);
        a /= 12 * 60.0;
        a *= Math.PI;

        var cos = Math.cos(a);
        var sin = Math.sin(a);
        dc.drawBitmap(centerX + (98 * sin)-6, centerY - (98 * cos)-6, sun);

        // SUNSET (moon)
        a = ((sunset[SUNRISET_NOW].toNumber() % 24) * 60) + ((sunset[SUNRISET_NOW] - sunset[SUNRISET_NOW].toNumber()) * 60);
        a /= 12 * 60.0;
        a *= Math.PI;
        cos = Math.cos(a);
        sin = Math.sin(a);
        dc.drawBitmap(centerX + (98 * sin)-2, centerY - (98 * cos)-4, moon);
    }

    //! Update the view
    function onUpdate (dc)
    {

        var time = Sys.getTimer();
        clockTime = Sys.getClockTime();

        // debugHour+=1;
        // if (debugHour >= 86400)
        // {
        //     debugHour = 0;
        // }
        
        // clockTime.hour = debugHour / 60;
        // clockTime.min =(debugHour-clockTime.hour*60);

        if (lastRedrawMin != clockTime.min) { redrawAll = 1; }
        
        _refreshCount++;

        // hours
        // 2.0=24h
        // 1.0=12h
        // 0.5=6h
        // 0.25=3h
        // 0.125=1.5h
        // 1/12=60min

        if (0!=redrawAll)
        {
            dc.setColor(0x00, 0x00);
            dc.clear();
            lastRedrawMin=clockTime.min;
            drawSunBitmaps(dc);
           
            var now = Time.now();
            var info = Calendar.info(now, Time.FORMAT_MEDIUM);
            var dateStr = Lang.format("$1$", [info.month]).toLower();
            var dateStr2 = info.day.format("%0.1d");
            var txtWidth = dc.getTextWidthInPixels(dateStr, fontGeneva15);
            var txtWidth2 = dc.getTextWidthInPixels(dateStr+info.day.format("%0.1d"), fontGeneva15) >> 1;
            var txtWidthFull = (dc.getTextWidthInPixels(dateStr, fontGeneva15) >> 1) + txtWidth2;

            var txtWidthMin = (txtWidthFull < 31) ? 31 : txtWidthFull; // min size when beginning of month

            // ****************** draw how much of actual day has passed ******************
            // var hh = -((clockTime.hour)-6) * (1.0 / 12.0);
            // hh -= (clockTime.min) * (1.0 / 12.0) * (1.0 / 60.0);
            // hh *= Math.PI;
            // hh *= 57.295779513082320876798154814105;
            // dc.setColor(0xff0000, 0x00);
            // for (var i = 0; i < 8; i++)
            // {
            //     dc.drawArc(centerX, centerY, 81 + i, Gfx.ARC_CLOCKWISE, 90, hh);
            // }

            drawMinuteArc(dc);
            
            // Clear for middle info
            // dc.setColor(0xFF0000, 0);
            // dc.fillEllipse(centerX, centerY, 42, 79);
            // dc.fillCircle(centerX, centerY, 69);

            var fontHeight = dc.getFontHeight(fontGeneva72) >> 1;

            // draw hour
            var h=clockTime.hour;
            if (false==Sys.getDeviceSettings().is24Hour && h>11)
            {
                h-=12;
                if (0==h) { h=12; }
            }
            var hour = h.format("%0.1d");
            // var txtWidthHour = dc.getTextWidthInPixels(hour, fontGeneva22)>>1;
            //        var posX = centerX + (yPos * sin)-wRoundRect>>1;
            // dc.drawText(centerX-txtWidthHour, centerY-(fontHeight<<1), fontGeneva22, hour + ":", Gfx.TEXT_JUSTIFY_LEFT);

            // draw big hours font
            txtWidthFull = dc.getTextWidthInPixels(hour, fontGeneva72)>>1;
            dc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_BLACK);
            dc.drawText(centerX, centerY-fontHeight, fontGeneva72, hour, Gfx.TEXT_JUSTIFY_CENTER);            
            var fontHeightS = dc.getFontHeight(fontGeneva15) >> 1;

            // draw Day info
            var offsetY = centerY-80;
            //dc.setColor(itemsBackGroundcolor, 0);
            //dc.fillRoundedRectangle(centerX - txtWidthFull, offsetY - (fontHeightS), txtWidthFull, fontHeightS, 4);
            dc.setColor(0x555555, Gfx.COLOR_BLACK);
            dc.drawText(centerX-txtWidth2, offsetY - (fontHeightS), fontGeneva15, dateStr, Gfx.TEXT_JUSTIFY_LEFT);
            dc.drawText(centerX-txtWidth2+txtWidth, offsetY - (fontHeightS), fontGeneva15, dateStr2, Gfx.TEXT_JUSTIFY_LEFT);
                         
        }// redrawAll
        
//        dc.setColor(itemsBackGroundcolor, 0);
//        dc.fillRoundedRectangle(centerX - 25, centerY - 49, 50, 16, 4);

        var bat = Sys.getSystemStats().battery;
        if (5 >= bat || 0!=redrawAll){
            drawBatteryLevel(dc);
        }
        //drawAlarm(dc);
        
        if (0>redrawAll) { redrawAll--; }

        getLastActivity(dc);
        //  dc.setColor(0xaaFF00, 0);
        //   dc.drawText(centerX, 33, fontGeneva22, "0123456789:", Gfx.TEXT_JUSTIFY_CENTER);
    }

    function getLastActivity(dc)
    {
        var info = Activity.getActivityInfo();
        if (null == info)
        {
            Sys.println("no activity found...");
            return;
        }
        var startTime = info.startTime;
        if (null == startTime)
        {
            Sys.println("no activity.startTime found...");
            return;
        }

        startTime.add(utcOffset);        
        var nowTime = Time.now().add(utcOffset);
        var detlaTime = nowTime.substract(startTime);
        Sys.println("seconds since last activity:"+deltaTime.value);

        dc.setColor(0x00ff00, -1);
        var str = "la.:" + deltaTime.value.format("%d");
        dc.drawText(centerX-60, centerY - 30, Gfx.FONT_TINY, str, Gfx.TEXT_JUSTIFY_LEFT);        
    }

    function computeSun()
    {
        var pos = Activity.getActivityInfo().currentLocation;
        if (null == pos)
        {
            Sys.println("Using PARIS location...");
            lonW = 2.2667187452316284;
            latN = 48.820977701845756;
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
        Sys.println("dayOfYear: " + now.format("%d"));
        sunrise[SUNRISET_NOW] = computeSunriset(now, lonW, latN, true);
        sunset[SUNRISET_NOW] = computeSunriset(now, lonW, latN, false);

        // max
        var max;
        if (latN >= 0)
        {
            max = dayOfYear(21, 6, timeInfo.year);
            Sys.println("We are in NORTH hemisphere");
        } 
        else
        {
            max = dayOfYear(21,12,timeInfo.year);            
            Sys.println("We are in SOUTH hemisphere");
        }
        sunrise[SUNRISET_MAX] = computeSunriset(max, lonW, latN, true);
        sunset[SUNRISET_MAX] = computeSunriset(max, lonW, latN, false);

        // adjust to daylight saving time if necessary
        if (null!=clockTime.dst)
        {
            var dst = clockTime.dst/3600;
            Sys.println("DST: "+ dst.format("%d")+"h");        
            for (var i = 0; i < SUNRISET_NBR; i++)
            {
                sunrise[i] += dst;
                sunset[i] += dst;
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