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

(:test)
function test(logger){
	var bg = new lateBackground();
	logger.debug(bg.onTemporalEvent());
	return true;
}