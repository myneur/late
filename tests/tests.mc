using Toybox.Test as test;
using Toybox.System as Sys;
using Toybox.WatchUi as Ui;

(:test)
class testApp extends lateApp {
	function initialize() {
        lateApp.initialize();
    }

    function getInitialView() {
		watch = new testView();
		return [watch];
	}

	function getServiceDelegate() {
		return [new mockBackground()];
	}
}

(:test)
class testView extends lateView {
	function initialize() {
        lateView.initialize();
    }
    function getActivity(){
    	return activity;
    }
    function setActivity(v){
    	testApp.setProperty("activity", v);
    }

    function setupCalendar(){
    	var activities = [null, :steps, :calories, :activeMinutesDay, :activeMinutesWeek, :floorsClimbed, :calendar];
		app.setProperty("activity", 6); activity = activities[app.getProperty("activity")]; app.setProperty("calendar_ids", ["myneur@gmail.com","petr.meissner@gmail.com"]);
    }
    function onBackgroundData(data) {	
		lateView.onBackgroundData(data);
		return data;
	}
}

(:test)
class mockBackground extends lateBackground {

	function initialize() {
		lateBackground.initialize();
	}

	function onOAuthUserCode(responseCode, data){
		lateBackground.onOAuthUserCode(responseCode, data);
		logger.debug([responseCode, data]);
		return [responseCode, data];
	}
}

(:test)
function test(logger){
	var mockApp = new testApp();

	//logger.debug(testApp.getProperty("activity"));	//different than in watch
	mockApp.getInitialView();
	test.assert(mockApp.watch);

	// configure 
	mockApp.watch.setupCalendar();

	// layout 
	mockApp.watch.onLayout(null); // runs layout of bouth: mock and late
	
	// test 
	test.assertMessage(mockApp.watch.activity==:calendar, 
		"expecting active calendar");
	var bg = mockApp.getServiceDelegate()[0];
	var data = mockApp.scheduleDataLoading();
	logger.debug(data);
	test.assertMessage(data["error_code"]==511 && data["userPrompt"].find(Ui.loadResource(Rez.Strings.Wait4login))!=null, 
		"no prompt to log in");
	test.assertMessage(data["wait"]>=0, 
		"time to login must be now or in future");
	
	// test data from calendar
	bg.onTemporalEvent();
	// TODO test returned data.hasKey("user_code") that is string longer that 6

	/*
	assertEqual(value1, value2);
	assertEqualMessage(value1, value2, message);
	assertMessage(test, message);
	assertNotEqual(value1, value2);
	assertNotEqualMessage(value1, value2, message);*/

	//var bg = new lateBackground();
	//logger.debug(bg.onTemporalEvent());
	return true;
}

/* TODO 

state tests:

!refresh_token:
	!user_code
		start=> durationToNextEvent()
	!bt
		userPrompt=> NotConnected
		return
	404
		userPrompt=> NoInternet
		return
	userPrompt=> Wait4login || is_url

	onTemporalEvent: 
		userPrompt=> no change
	after 30 mins: 
		userPrompt=> is_url, user_context=> changed
	
google.com/device [Enter code: user_code][NEXT][Cancel]: onTemporalEvent: 
	userPrompt=> is_url, user_context=> changed

google.com/device [Enter code: user_code][NEXT][Click: mail][ALLOW]: 
	onTemporalEvent: onBackgroundData:
		data.hasKey("events")


https://myaccount.google.com/permissions [Simply late!][REMOVE ACCESS][OK]: 
	onTemporalEvent: 
		userPrompt=> changed && is_url
		
refresh_token: 
	events instanceof Array
	calendar_ids.size()>0

	onTemporalEvent: onBackgroundData:
		data.hasKey("events")


stress tests: 

calendar_ids.size()>20
events.size()>20


device tests: 
no device has compilation error
FR45 do not run out of memory
fenix3 has no active minutes setting
fr735xt has no calendar activity setting
	
*/



/*class lateAppMock extends lateApp{
	function initialize(){
		lateApp.initialize();
	}
}*/