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