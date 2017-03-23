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

    // draw hours marks and numbers
//     function drawBackground (dc)
//     {
//         var hours = 0;
//         for (var i=0; i<SinCosTableX.size(); i++)
//         {
//             var hourAngle = i * 60;
// //            hourAngle += 12 * 60;
//             hourAngle /= (12 * 60.0);
//             hourAngle *= Math.PI;
            
//             var color = 0xffffff;
//             if (i < clockTime.hour) { color = 0xff5500; }
//             else if (i>clockTime.hour) { color=0xffaa00; }

//             if (i == clockTime.hour)
//             {
//                 drawHand4px(dc, hourAngle, 81, 94, color);                
//             }
//             else if (i >= clockTime.hour) { drawHand2px(dc, hourAngle, 81, 90, color); }
//             else if (0==i) { drawHand1px(dc, hourAngle, 81, 90, 0xffaa00); }

//             if (0<hours)
//             {
//                 hours = (hours + 1) % 2;
//                 continue;                
//             }

//             dc.setColor(color, Gfx.COLOR_TRANSPARENT);
//             var str=i.format("%d");
//             var x = (SinCosTableX[i] * 101);
//             var y = (SinCosTableY[i] * 101);
//             var fontHeight = (dc.getFontHeight(Gfx.FONT_TINY) >> 1)+1;
//             dc.drawText(x+centerX,y+centerY-fontHeight,Gfx.FONT_TINY,str,Gfx.TEXT_JUSTIFY_CENTER);
//             hours= (hours+1)%2;
//         }
//     }

    //! Draw the watch hand
    //! @param dc Device Context to Draw
    //! @param angle Angle to draw the watch hand
    //! @param length Length of the watch hand
    //! @param width Width of the watch hand
    function drawHand1px (dc, angle, start, end, color)
    {
        var cos = Math.cos(angle);
        var sin = Math.sin(angle);

        // Transform the coordinates and draw
        dc.setColor(color, 0x00);
        dc.drawLine(centerX + (start * sin),
                    centerY - (start * cos),
                    centerX + (end * sin),
                    centerY - (end * cos));    
    }

    function drawHand2px (dc, angle, start, end, color)
    {
        var cos = Math.cos(angle);
        var sin = Math.sin(angle);
        
        dc.setPenWidth(2);

        // Transform the coordinates and draw
        if (0!=color)
        {
            var c2 = ((color>>16 & 0xff)>>1)<<16 | ((color>>8 & 0xff)>>1)<<8 | (color & 0xff)>>1;
            dc.setColor(c2, 0x00);
            dc.drawLine(centerX + (start * sin),
                        centerY+1 - (start * cos),
                        centerX + (end * sin),
                        centerY+1 - (end * cos));    
            dc.setColor(color, 0x00);
            dc.drawLine(centerX + (start * sin),
                        centerY-1 - (start * cos),
                        centerX + (end * sin),
                        centerY-1 - (end * cos));
        }
        dc.setColor(color, 0x00);
        dc.drawLine(centerX + (start * sin),
                    centerY - (start * cos),
                    centerX + (end * sin),
                    centerY - (end * cos));    
        dc.setPenWidth(1);
    }

    function drawHand4px (dc, angle, start, end, color)
    {
        var cos = Math.cos(angle);
        var sin = Math.sin(angle);

        dc.setPenWidth(3);
        dc.setColor(0x555555, 0x00);
        dc.drawLine(centerX + (start * sin),
                    centerY - (start * cos),
                    centerX + (end * sin),
                    centerY - (end * cos));    
        
        
        // Transform the coordinates and draw
        if (0!=color)
        {
            dc.setPenWidth(1);
            var c2 = ((color>>16 & 0xff)>>1)<<16 | ((color>>8 & 0xff)>>1)<<8 | (color & 0xff)>>1;
            dc.setColor(c2, 0x00);
            dc.drawLine(centerX + (start * sin),
                        centerY+1 - (start * cos),
                        centerX + (end * sin),
                        centerY+1 - (end * cos));    
        }
        dc.setColor(color, 0x00);
        dc.setPenWidth(1);
        dc.drawLine(centerX + (start * sin),
                    centerY - (start * cos),
                    centerX + (end * sin),
                    centerY - (end * cos));    

        // var yPos = start+((end - start) * 0.72);

        // var wRoundRect = dc.getTextWidthInPixels(clockTime.hour.format("%0.1d")+":", fontGeneva22);
        // var hRoundRect = dc.getFontHeight(fontGeneva22)-3;

        // var posY = centerY - (yPos * cos)-hRoundRect>>1;
        //dc.setColor(itemsBackGroundcolor, 0);
        //dc.fillCircle(centerX + (yPos * sin), centerY - (yPos * cos), (wRoundRect>>1)+2);
        //dc.setColor(0xaaFF00, -1);

//      Draw hour on hand with background        
//        dc.setColor(itemsBackGroundcolor, 0);
//        dc.fillRoundedRectangle(centerX + (yPos * sin)-(wRoundRect>>1)-1, centerY - (yPos * cos)-hRoundRect>>1, wRoundRect, hRoundRect, 4);
//        dc.setColor(0xaaFF00, -1);
//        var posX = centerX + (yPos * sin)-wRoundRect>>1;
//        dc.drawText(posX+1, posY-5, fontGeneva22, clockTime.hour.format("%0.1d")+":", Gfx.TEXT_JUSTIFY_LEFT);
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

    // draw BlueTooth icon, width=15px
    function drawBT (dc)
    {
        var btOn = Sys.getDeviceSettings().phoneConnected;
        if (0 == btOn) { return; }
        
        dc.setColor(0x555555, 0);
        
        Sys.println("phoneConnected...");

        var xPos = centerX + 20;
        var yPos = centerY - 52;
        
        // draw the BT sign
        dc.drawLine(xPos, yPos+1, xPos, yPos+14);
        dc.drawLine(xPos, yPos+1, xPos+4, yPos+5);
        dc.drawLine(xPos+1, yPos+1, xPos+5, yPos+5);
        dc.drawLine(xPos+2, yPos+5, xPos-4, yPos+11);
        dc.drawLine(xPos+3, yPos+5, xPos, yPos+8);
        dc.drawLine(xPos-3, yPos+4, xPos+4, yPos+11);
        dc.drawLine(xPos+2, yPos+8, xPos+5, yPos+11);
        dc.drawLine(xPos+3, yPos+11, xPos, yPos+14);
        dc.drawLine(xPos+2, yPos+11, xPos, yPos+12);

        // draw the AA BT sign
        dc.setColor(0x00, 0);
        dc.drawPoint(xPos, yPos);
        dc.drawPoint(xPos, yPos+14);

        dc.drawLine(xPos+1, yPos+3, xPos+1, yPos+6);
        dc.drawPoint(xPos + 4, yPos + 3);
        dc.drawPoint(xPos + 4, yPos + 5);

        dc.drawLine(xPos+1, yPos+9, xPos+1, yPos+12);
        dc.drawPoint(xPos + 4, yPos + 9);
        dc.drawPoint(xPos + 4, yPos + 11);

        dc.drawPoint(xPos-4, yPos+3);
        dc.drawLine(xPos - 2, yPos + 4, xPos, yPos + 5);
        dc.drawLine(xPos-4, yPos+4, xPos, yPos+8);
        dc.drawLine(xPos-2, yPos+8, xPos-5, yPos+11);
        dc.drawPoint(xPos-4, yPos+11);
        dc.drawLine(xPos-2, yPos+10, xPos, yPos+8);
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

    function drawHourHandle (dc, color, hour, bText)
    {
        var sunriseStr;
        if (false==Sys.getDeviceSettings().is24Hour && hour>11)
        { 
            var h=hour-12;
            if (0==h) { h=12; }
            sunriseStr=h.toString()+"p";
        }
        else
        {
            sunriseStr=hour.toString();
            if (false==Sys.getDeviceSettings().is24Hour && 0!=hour) { sunriseStr+="a"; }
        }

        if (false==bText) { return; }

        var fontHeight = (dc.getFontHeight(fontGeneva10) >> 1)+1;
        dc.setColor(0x555555, Gfx.COLOR_TRANSPARENT);
        dc.drawText((SinCosTableX[hour] * 94)+centerX,(SinCosTableY[hour] * 95)+centerY-fontHeight,fontGeneva10,sunriseStr,Gfx.TEXT_JUSTIFY_CENTER);
    }

    // draw  sunrise/sunset hours
    function drawSunHours (dc, sunR)
    {
        // draw tiny hands for sunrise/set times)
        var hh=0;
        /*drawHourHandle(dc, 0x555555, hh, true);
        hh=12;*/
        var hh2=hh%24;
        /*drawHourHandle(dc, 0x555555, hh, true);
        hh2*=60;
        hh2 /= 12 * 60.0;
        hh2 *= Math.PI;
        drawHand2px(dc, hh2, 104, 109, 0xCCCCCC);*/

        hh = sunR[SUNRISET_NOW].toNumber();
        hh2=hh%24;

        //drawHourHandle(dc, 0x555555, hh, true);

        hh2*=60;
        hh2 /= 12 * 60.0;
        hh2 *= Math.PI;
        drawHand2px(dc, hh2, 104, 109, sunR==sunset?0xCCCCCC:0xFF5500);

        hh+=1; // next hour
        hh%=24;

        //drawHourHandle(dc, 0x555555, hh, false);

        hh*=60;
        hh /= 12 * 60.0;
        hh *= Math.PI;
        drawHand2px(dc, hh, 104, 109, sunR==sunset?0xFF5500:0xCCCCCC);
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

    // draw monochrome sunrise/sunset
    function drawSun (dc)
    {
        var sunriseAngle = -((sunrise[SUNRISET_MAX].toNumber() % 24) -6) * (1.0 / 12.0);
        sunriseAngle -= ((sunrise[SUNRISET_MAX] - sunrise[SUNRISET_MAX].toNumber()) * 60)*(1.0 / 12.0)*(1.0/60.0);
        sunriseAngle *= Math.PI;

        var sunsetAngle = -((sunrise[SUNRISET_NOW].toNumber() % 24) -6) * (1.0 / 12.0);
        sunsetAngle -= ((sunrise[SUNRISET_NOW] - sunrise[SUNRISET_NOW].toNumber()) * 60)*(1.0 / 12.0)*(1.0/60.0);
        sunsetAngle *= Math.PI;
        
        var Deg2Rad = 57.295779513082320876798154814105;
        var srA = sunriseAngle * Deg2Rad;
        var ssA = sunsetAngle * Deg2Rad;

        // hour = ( ( ( clockTime.hour % 12 ) * 60 ) + clockTime.min );
        // hour = hour / (12 * 60.0);
        // hour = hour * Math.PI * 2;

        dc.setColor(0xff5500, 0);
//        if (srA < ssA)
//        {
             dc.drawArc(centerX, centerY, 107, Gfx.ARC_CLOCKWISE, srA, ssA); // bug in drawArc: around 3o'clock, only one pixel thin result after 2 calls @r=108 & r=109 
             dc.drawArc(centerX, centerY, 108, Gfx.ARC_CLOCKWISE, srA, ssA);
            // dc.drawArc(centerX, centerY, 109, Gfx.ARC_CLOCKWISE, srA, ssA);
//        }

        sunsetAngle = -((sunset[SUNRISET_NOW].toNumber() % 24) -6) * (1.0 / 12.0);
        sunsetAngle -= ((sunset[SUNRISET_NOW] - sunset[SUNRISET_NOW].toNumber()) * 60)*(1.0 / 12.0)*(1.0/60.0);
        sunsetAngle *= Math.PI;

        srA = ssA;
        ssA = sunsetAngle * Deg2Rad;
        
        dc.setColor(0xaaaaaa, 0x00);
        dc.drawArc(centerX, centerY, 107, Gfx.ARC_CLOCKWISE, srA, ssA);
        dc.drawArc(centerX, centerY, 108, Gfx.ARC_CLOCKWISE, srA, ssA);

        drawSunHours(dc, sunrise);
        drawSunBitmaps(dc);

        srA = ssA;
        sunsetAngle = -((sunset[SUNRISET_MAX].toNumber() % 24) -6) * (1.0 / 12.0); // have to put +7 instead of -6 else graphic discrepancy on real hardware
        sunsetAngle -= ((sunset[SUNRISET_MAX] - sunset[SUNRISET_MAX].toNumber()) * 60)*(1.0 / 12.0)*(1.0/60.0);
        sunsetAngle *= Math.PI;

        ssA = sunsetAngle * Deg2Rad;
        
//        if (srA < ssA)
//        {
             dc.setColor(0xFF5500, 0x00);
             dc.drawArc(centerX, centerY, 107, Gfx.ARC_CLOCKWISE, srA, ssA);
             dc.drawArc(centerX, centerY, 108, Gfx.ARC_CLOCKWISE, srA, ssA);
//        }        
        drawSunHours(dc, sunset);
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

            //drawSun(dc);
            drawSunBitmaps(dc);
           
            var now = Time.now();
            var info = Calendar.info(now, Time.FORMAT_MEDIUM);
            var dateStr = Lang.format("$1$", [info.day_of_week]).toLower();
            var dateStr2 = info.day.format("%0.1d");//Lang.format("$1$", [info.day]).toLower();
            var txtWidth2 = dc.getTextWidthInPixels(dateStr2, fontGeneva15) >> 1;
            var txtWidth = (dc.getTextWidthInPixels(dateStr, fontGeneva15) >> 1) + txtWidth2;
            var txtWidthMin = (txtWidth < 31) ? 31 : txtWidth; // min size when beginning of month

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

            // *** Draw handle       
            var hh = ( clockTime.min );
            
            var hh2 = hh;
            hh /= 60.0;
            hh *= 2*Math.PI;

            var sriseMax = ((sunrise[SUNRISET_MAX].toNumber() % 24) * 60) + ((sunrise[SUNRISET_MAX] - sunrise[SUNRISET_MAX].toNumber()) * 60);
            var ssetMax = ((sunset[SUNRISET_MAX].toNumber() % 24) * 60) + ((sunset[SUNRISET_MAX] - sunset[SUNRISET_MAX].toNumber()) * 60);
            drawHand4px(dc, hh, 69, 108, 0xAAAAAA);
            
            // Clear for middle info
            //  dc.setColor(0xFF0000, 0);
            // dc.fillEllipse(centerX, centerY, 42, 79);
            //  dc.fillCircle(centerX, centerY, 69);

            var fontHeight = dc.getFontHeight(fontGeneva72) >> 1;
            var minutes = clockTime.min.format("%0.1d");

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
            txtWidth = dc.getTextWidthInPixels(hour, fontGeneva72)>>1;
            dc.setColor(0xffAA00, Gfx.COLOR_BLACK);
            dc.drawText(centerX, centerY-fontHeight, fontGeneva72, hour, Gfx.TEXT_JUSTIFY_CENTER);
            //dc.setColor(0xaaFF00, Gfx.COLOR_BLACK);
            //dc.drawText(centerX-txtWidth, centerY-fontHeight-4, fontGeneva22, minutes, Gfx.TEXT_JUSTIFY_RIGHT);
            
            var fontHeightS = dc.getFontHeight(fontGeneva15) >> 1;

            // draw Day info
            var offsetY = 42 + centerY;

            //dc.setColor(itemsBackGroundcolor, 0);
            //dc.fillRoundedRectangle(centerX - txtWidth, offsetY - (fontHeightS), txtWidth, fontHeightS, 4);

            dc.setColor(0x555555, Gfx.COLOR_BLACK);
            dateStr = Lang.format("$1$", [info.day_of_week]).toLower();
            txtWidth2 = dc.getTextWidthInPixels(dateStr+info.day.format("%0.1d"), fontGeneva15) >> 1;
            dc.drawText(centerX-txtWidth2, offsetY - (fontHeightS), fontGeneva15, dateStr, Gfx.TEXT_JUSTIFY_LEFT);
            
            var txtWidth3 = dc.getTextWidthInPixels(dateStr, fontGeneva15);
            dc.setColor(0xaaaaaa, Gfx.COLOR_BLACK);
            dateStr = info.day.format("%0.1d");
            dc.drawText(centerX-txtWidth2+txtWidth3, offsetY - (fontHeightS), fontGeneva15, dateStr, Gfx.TEXT_JUSTIFY_LEFT);

            /*// draw week info            
            info = Calendar.info(now, Time.FORMAT_SHORT);
            var weekNbr = getWeekNbr(info.year, info.month, info.day);
            dc.setColor(0x555555, Gfx.COLOR_BLACK);
            dateStr = "W.";
            txtWidth2 = dc.getTextWidthInPixels(dateStr+weekNbr.format("%0.1d"), fontGeneva10) >> 1;
            offsetY+=6+fontHeightS;
            dc.drawText(centerX-txtWidth2, offsetY, fontGeneva10, dateStr, Gfx.TEXT_JUSTIFY_LEFT);
            txtWidth3 = dc.getTextWidthInPixels(dateStr, fontGeneva10);
            dc.setColor(0xaaaaaa, Gfx.COLOR_BLACK);
            dc.drawText(centerX-txtWidth2+txtWidth3, offsetY, fontGeneva10, weekNbr.format("%0.1d"), Gfx.TEXT_JUSTIFY_LEFT);*/
                         
        }// redrawAll
        
//        dc.setColor(itemsBackGroundcolor, 0);
//        dc.fillRoundedRectangle(centerX - 25, centerY - 49, 50, 16, 4);

        var bat = Sys.getSystemStats().battery;
        if (5 >= bat || 0!=redrawAll)
        {
            drawBatteryLevel(dc);
        }
        drawAlarm(dc);
        //drawBT(dc);
        
        if (0>redrawAll) { redrawAll--; }

        //dc.setColor(0x00ff00, -1);
        //dc.drawText(centerX-70, centerY - 40, fontGeneva10, lonW.format("%f"), Gfx.TEXT_JUSTIFY_LEFT);        
        //dc.drawText(centerX-70, centerY - 29, fontGeneva10, latN.format("%f"), Gfx.TEXT_JUSTIFY_LEFT);        

        // debug output to understand diffs between emu & watch
        // dc.setColor(0x00ff00, -1);
        // var str = sunrise[SUNRISET_MAX].toNumber().format("%d");
        // dc.drawText(centerX-60, centerY - 20, fontGeneva10, str, Gfx.TEXT_JUSTIFY_LEFT);        
        // str=sunrise[SUNRISET_NOW].toNumber().format("%d");
        // dc.drawText(centerX-60, centerY - 9, fontGeneva10, str, Gfx.TEXT_JUSTIFY_LEFT);
        // str=sunset[SUNRISET_NOW].toNumber().format("%d");
        // dc.drawText(centerX-60, centerY + 2, fontGeneva10, str, Gfx.TEXT_JUSTIFY_LEFT);
        // //str = (utcOffset.value()/3600).format("%d") + "h";
        // str = "no DST";
        // if (null!=clockTime.dst)
        // {
        //     var dst = clockTime.dst/3600;
        //     for (var i = 0; i < SUNRISET_NBR; i++)
        //     {
        //         sunrise[i] += dst;
        //         sunset[i] += dst;
        //     }
        //     str=("DST: "+ dst.format("%d")+"h");        
        // }
        // dc.drawText(centerX-60, centerY + 13, fontGeneva10, str, Gfx.TEXT_JUSTIFY_RIGHT);

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