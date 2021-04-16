using Toybox.Test as test;
using Toybox.System as Sys;
using Toybox.WatchUi as Ui;
using Toybox.Graphics as Gfx;
using Toybox.Lang;


//(:test)class mockDc extends Toybox.Graphics.Dc{}

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

    function setup(acitvity, activityL, activityR){
    	app.setProperty("activity", acitvity); 
		app.setProperty("activityL", activityL); 
		app.setProperty("activityR", activityR); 
	}

    function setupCalendar(){
    	setup(6, 0, 0);
		app.setProperty("calendar_ids", ["myneur@gmail.com","petr.meissner@gmail.com"]);
    }
    function setupNoData(){
    	setup(1, 4, 5);
    }
    function setupNoFloors(){
    	setup(1, 4, 3);
    }
    function setupNoActivityMinutes(){
    	setup(1, 1, 0);
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
	 function onTemporalEvent(){
	 	lateBackground.onTemporalEvent();
	 }
}

(:test)	// TODO not detecting missing Floors or Activities
function testViewDisplay(logger){
	var mockApp = new testApp();
	var dc = new Gfx.BufferedBitmap({:width=>416, :height=>416/*, :palette=>[0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15]*/}).getDc();
	mockApp.getInitialView();
	test.assert(mockApp.watch);
	mockApp.watch.setupNoData();
	mockApp.watch.onLayout(dc); // runs layout of bouth: mock and late
	mockApp.watch.onUpdate(dc);
	return true;
}

(:test)	// TODO stopped to return scheduleDataLoading Dictionary
function testCalendar(logger){
	var mockApp = new testApp();
	mockApp.getInitialView();
	test.assert(mockApp.watch);
	mockApp.watch.setupCalendar(); // configure 
	mockApp.watch.onLayout(null); // runs layout of bouth: mock and late
	
	// tests
	test.assertMessage(mockApp.watch.activity==:calendar, 
		"expecting active calendar");
	var bg = mockApp.getServiceDelegate()[0];
	var data = mockApp.scheduleDataLoading();
	logger.debug("schedule "+data);

	test.assertMessage(data instanceof Lang.Dictionary, 
		"no Dictionary from scheduleDataLoading");
	test.assertMessage(data["error_code"]==511 && data["userPrompt"].find(Ui.loadResource(Rez.Strings.Wait4login))!=null, 
		"no prompt to log-in");
	test.assertMessage(data["wait"]>=0, 
		"time to login must be now or in future");
	bg.onTemporalEvent();
	// test data from calendar
	
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