/*
    since no support for Floor and Ceil functions in Math lib, make them
*/

function floor (f)
{
    if (f instanceof Toybox.Lang.Float)
    {
         return f.toNumber();   
    }
    return -1;
} 
 
function ceil (f)
{
    var f2=-f;
    if (f2 instanceof Toybox.Lang.Float)
    {
        return f2.toNumber();   
    }
    return -1;
}

// Author: Patrik Svensson (patrik.svensson@home.se)  
function getWeekNbr (nYear, nMonth, nDay)
{
    var nNumDaysOfYear=0,nYY=0,nC=0,nG=0,nJan1Weekday=0;
    var nH=0,nWeekday=0,nYearNumber=0,nWeekNumber=0,nI=0,nJ=0;
    var bIsLeapYear=false,bIsPrevYear=false;
    var nMonthArray = [ 0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334 ];

    // Lite initering
    nYearNumber = nYear;

    // Kolla om det är skottår
    if ((nYear%4)==0) { bIsLeapYear = true; }
    else { bIsLeapYear = false; }

    // Kolla om det föregående året är skottår
    if(((nYear-1)%4)==0) { bIsPrevYear = true; }
    else { bIsPrevYear = false; }

    // Kolla hur många dagar på året som har gått
    nNumDaysOfYear = nDay + nMonthArray[nMonth-1];

    // Om det är skottår och månaden > 2 så öka antalet dagar med 1
    if (bIsLeapYear && nMonth>2) { nNumDaysOfYear++; }

    // Ta reda på vilken veckodag 1 Januari var.
    nYY = (nYear-1) % 100;
    nC = (nYear-1) - nYY;
    nG = nYY + nYY/4;
    nJan1Weekday = 1 + (((((nC/100)%4)*5)+nG)%7);

    // Ta reda på veckodagen
    nH = nNumDaysOfYear + (nJan1Weekday - 1);
    nWeekday = 1+((nH-1)%7);

    // Kolla om Y-M-D infaller i nYear-1, Veckonummer 52 eller 53
    if (nNumDaysOfYear<=(8-nJan1Weekday) && nJan1Weekday>4)
    {
        nYearNumber = nYear - 1;

        if (nJan1Weekday==5 || (nJan1Weekday==6 && bIsPrevYear)) { nWeekNumber = 53; }
        else { nWeekNumber = 52; }
    }

    // Kolla om Y-M-D infaller i nYear+1, Veckonummer 1
    if (nYearNumber==nYear)
    {
        if (bIsLeapYear) { nI = 366; }
        else { nI = 365; }

        if ((nI - nNumDaysOfYear) < (4-nWeekday))
        {
            nYearNumber = nYear + 1;
            nWeekNumber = 1;
        }
    }

    // Kolla om Y-M-D infaller i nYearNumber, Veckonummer 1 till 53
    if (nYearNumber==nYear)
    {
        nJ = nNumDaysOfYear + (7-nWeekday)+(nJan1Weekday-1);
        nWeekNumber = nJ/7;

        if (nJan1Weekday>4) { nWeekNumber--; }
    }

    return nWeekNumber;
}
