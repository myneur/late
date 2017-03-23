//
// Copyright 2016 by Garmin Ltd. or its subsidiaries.
// Subject to Garmin SDK License Agreement and Wearables
// Application Developer Agreement.
//

using Toybox.Application as App;

class slowApp extends App.AppBase
{
    function initialize()
    {
        AppBase.initialize();
    }

    function onStart(state) { }

    function onStop(state) { }

    function getInitialView()
    {
        return [new slowView()];
    }
}
