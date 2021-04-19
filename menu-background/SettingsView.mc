using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.System;
using Toybox.Application.Storage as Storage;
using Toybox.Application as App;

class SettingsView extends WatchUi.View {
	var count = 0;
    
    function initialize() {
        View.initialize();
    }

    function onUpdate(dc) {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
		if(count == 0){
			var menu = new WatchUi.Menu2({:title=>"Setting"});
            for(var i=0;i<events_list.size();i++){
                menu.addItem(new WatchUi.MenuItem(events_list[2]+ ": " events_list[3], null, events_list[0], null));
            }
            menu.addItem(new WatchUi.MenuItem("Color", null, :color, null));
        	WatchUi.pushView(menu, new CustomDelegate(), WatchUi.SLIDE_UP );
		}
		else{
			dc.drawText(dc.getWidth() / 2, dc.getHeight() / 2, Graphics.FONT_SMALL, "Press Back", Graphics.TEXT_JUSTIFY_CENTER|Graphics.TEXT_JUSTIFY_VCENTER);
		}
		count = 1;
	}
}

class SettingsDelegate extends WatchUi.BehaviorDelegate {
    function initialize() {
        BehaviorDelegate.initialize();
    }
    //initialize(label, subLabel, identifier, enabled, options)
    function onMenu() {
    }
}

class CustomDelegate extends WatchUi.InputDelegate {
    function initialize() {
        InputDelegate.initialize();
    }

    function onSelect(item) {
        var id = item.getId();
        if(id == :color) {
            pushHourColor();
            System.println("confirmItem 1");
        }  
        //WatchUi.requestUpdate();
        //WatchUi.pushView(WatchUi.SLIDE_DOWN);
    }

    function onBack() {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
    }
}