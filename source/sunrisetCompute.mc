using Toybox.Math as Math;
using Toybox.Time as Time;
using Toybox.Time.Gregorian as Calendar;

/*
code by https://gist.github.com/Tafkas
Derived from its javascript implementation

Sunrise/Sunset Algorithm taken from
    http://williams.best.vwh.net/sunrise_sunset_algorithm.htm
    inputs:
        day = day of the year
        sunrise = true for sunrise, false for sunset
    output:
        time of sunrise/sunset in hours

	zenith:        Sun's zenith for sunrise/sunset
	  offical      = 90 degrees 50'
	  civil        = 96 degrees
	  nautical     = 102 degrees
	  astronomical = 108 degrees

Check current sunrise/sunset time on : http://www.timeanddate.com/sun/

code for computeDatNumber from https://alcor.concordia.ca/~gpkatch/gdate-algorithm.html

*/

function computeDayNumber (d, m, y)
{
    //Sys.println("calc:"+d+"/"+m+"/"+y);
    m = (m + 9) % 12;
    y = y - m / 10;
    return (365 * y + y / 4 - y / 100 + y / 400 + (m * 306 + 5) / 10 + (d - 1));
}

// returns the number of the day from 0 to 365
function dayOfYear (day, month, year)
{
    var now = computeDayNumber(day, month, year);
    var begOfYear = computeDayNumber(1, 1, year);
    return (now - begOfYear);
    //Sys.println("dayOfYear: " + dayOfYear.format("%d"));
}

function computeSunriset (day, longitude, latitude, sunrise)
{
    var zenith = 90.83333333333333; // official
    var D2R = 0.01745329251994329576923690768489;
    var R2D = 57.295779513082320876798154814105;

    // convert the longitude to hour value and calculate an approximate time
    var lnHour = longitude / 15;
    var t;
    if (sunrise)
    {
        t = day + ((6 - lnHour) / 24);
    }
    else
    {
        t = day + ((18 - lnHour) / 24);
    }

    //calculate the Sun's mean anomaly
    var M = (0.9856 * t) - 3.289;

    //calculate the Sun's true longitude
    var L = M + (1.916 * Math.sin(M * D2R)) + (0.020 * Math.sin(2 * M * D2R)) + 282.634;
    if (L > 360)
    {
        L = L - 360;
    }
    else if (L < 0)
    {
        L = L + 360;
    }

    //calculate the Sun's right ascension
    var RA = R2D * Math.atan(0.91764 * Math.tan(L * D2R));
    if (RA > 360)
    {
        RA = RA - 360;
    }
    else if (RA < 0)
    {
        RA = RA + 360;
    }

    //right ascension value needs to be in the same qua
    var Lquadrant = (floor(L / (90))) * 90;
    var RAquadrant = (floor(RA / 90)) * 90;
    RA = RA + (Lquadrant - RAquadrant);

    //right ascension value needs to be converted into hours
    RA = RA / 15;

    //calculate the Sun's declination
    var sinDec = 0.39782 * Math.sin(L * D2R);
    var cosDec = Math.cos(Math.asin(sinDec));

    //calculate the Sun's local hour angle
    var cosH = (Math.cos(zenith * D2R) - (sinDec * Math.sin(latitude * D2R))) / (cosDec * Math.cos(latitude * D2R));
    var H;
    if (sunrise)
    {
        H = 360 - R2D * Math.acos(cosH);
    }
    else
    {
        H = R2D * Math.acos(cosH);
    }
    H = H / 15;

    //calculate local mean time of rising/setting
    var T = H + RA - (0.06571 * t) - 6.622;

    //adjust back to UTC
    var UT = T - lnHour;
    if (UT > 24)
    {
        UT = UT - 24;
    }
    else if (UT < 0)
    {
        UT = UT + 24;
    }

    return UT;
}