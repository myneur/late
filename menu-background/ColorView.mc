using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.System;
using Toybox.Application.Storage as Storage;
using Toybox.Application as App;



    function pushHourColor() {

        var title = ["red", "yellow", "green", "blue", "violet", "grey"]
        var color = [
            [0xFF0000, 0xFFAA00, 0x00FF00, 0x00AAFF, 0xFF00FF, 0xAAAAAA],
            [0xAA0000, 0xFF5500, 0x00AA00, 0x0000FF, 0xAA00FF, 0x555555], 
            [0xAA0055, 0xFFFF00, 0x55FFAA, 0x00AAAA, 0x5500FF, 0xAAFFFF]
        ][tone<=2 ? tone : 0];

			var colorhour = new WatchUi.Menu2({:title=>"Color"});
            for(var i=0;i<color.size();i++){
                colorhour.addItem(new WatchUi.MenuItem(title[i], null, color[i], null));    
            }
        	WatchUi.pushView(colorhour, new ColorHourDelegate(), WatchUi.SLIDE_UP );
  
	}

class ColorHourDelegate extends WatchUi.InputDelegate {
    
    function initialize() {
        InputDelegate.initialize();
    }

    function onSelect(item) {
        var id = item.getId();
        app.setProperty("color", item);
        //WatchUi.requestUpdate();
        WatchUi.popView(WatchUi.SLIDE_DOWN);
    }

    function onBack() {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        
    }
}