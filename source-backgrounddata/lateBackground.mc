using Toybox.Background;
using Toybox.System as Sys;
using Toybox.Communications;
using Toybox.Application as App;
using Toybox.Time;
using Toybox.Time.Gregorian;

const GoogleDeviceCodeUrl = "https://accounts.google.com/o/oauth2/device/code";
const GoogleTokenUrl = "https://oauth2.googleapis.com/token";
const GoogleCalendarEventsUrl = "https://www.googleapis.com/calendar/v3/calendars/";
const GoogleCalendarListUrl = "https://www.googleapis.com/calendar/v3/users/me/calendarList";
const GoogleScopes = "https://www.googleapis.com/auth/calendar.readonly";

(:background)
class lateBackground extends Toybox.System.ServiceDelegate {

  var access_token;
  var refresh_token;
  var current_index = -1;
  var calendar_ids;
  var events_list = [];
  var primary_calendar = false;
  var app;

  function initialize() {
    ///Sys.println(Sys.getSystemStats().freeMemory + " on init");
    Sys.ServiceDelegate.initialize();
    app = App.getApp();
    //Communications.registerForOAuthMessages(method(:onOauthMessage));
  }
  
  function onTemporalEvent() {
    ///Sys.println(Sys.getSystemStats().freeMemory + " on onTemporalEvent");
    ///Sys.println([app, App.getApp()]);
    app = App.getApp();
    var connected = Sys.getDeviceSettings().phoneConnected;
    
    if (app.getProperty("refresh_token") != null) { 
      ///Sys.println("has refresh_token");
      refresh_token = app.getProperty("refresh_token");
      if(connected){
        refreshTokenAndGetData();
      }
    } else {
      if(connected){
        if (app.getProperty("user_code") == null){ // && new Moment(app.getProperty("code_valid_till").compare(Time.now()) < -10))
          ///Sys.println("no code");
          getOAuthUserCode();
        } else {
          ///Sys.println("got code");
          getTokensAndData();
        }
      } else {
        Background.exit({"error_code"=>404}); // no response
      }
    }
  }

  function getOAuthUserCode(){
    ///Sys.println(Sys.getSystemStats().freeMemory + " on getOAuthUserCode");
    ///Sys.println([App.getApp().getProperty("client_id"), $.GoogleDeviceCodeUrl, $.GoogleScopes]);
    ///Sys.println(app.getProperty("client_id"));
    ///Sys.println([app, App.getApp()]);
    Communications.makeWebRequest($.GoogleDeviceCodeUrl, 
      {"client_id"=>app.getProperty("client_id"), "scope"=>$.GoogleScopes}, {:method => Communications.HTTP_REQUEST_METHOD_POST}, 
      method(:onOAuthUserCode)); 
  }

  function onOAuthUserCode(responseCode, data){ // {device_code, user_code, verification_url}
    ///Sys.println(Sys.getSystemStats().freeMemory + " onOAuthUserCode: "+responseCode); Sys.println(data);
    ///Sys.println([app, App.getApp()]);
    if(responseCode != 200){
      if(data == null) { // no data connection 
        data = {"error_code"=>responseCode};
      } else {
        data.put("error_code", responseCode);
      }
    } /*else {
      showInstructionOnMobile(data);
    }*/
    Background.exit(data);  // prompt to login or show the error
  }

  function getTokensAndData(){ // device_code can tell if the user granted access
    ///Sys.println(Sys.getSystemStats().freeMemory + " on getTokensAndData"); Sys.println(app.getProperty("user_code"));
    ///Sys.println([$.GoogleTokenUrl,app.getProperty("device_code"),app.getProperty("client_id"),app.getProperty("client_secret"),"http://oauth.net/grant_type/device/1.0"]);
    ///Sys.println([app, App.getApp()]);
    Communications.makeWebRequest($.GoogleTokenUrl, {"client_id"=>app.getProperty("client_id"), "client_secret"=>app.getProperty("client_secret"),
      "code"=>app.getProperty("device_code"), "grant_type"=>"http://oauth.net/grant_type/device/1.0"}, {:method => Communications.HTTP_REQUEST_METHOD_POST}, 
      method(:onTokenRefresh2GetData));
  }

  function onTokenRefresh2GetData(responseCode, data){
    ///Sys.println(Sys.getSystemStats().freeMemory + " on onTokenRefresh2GetData: "+responseCode); Sys.println(data);
    ///Sys.println([app, App.getApp()]);
    if (responseCode == 200) {
      access_token = data.get("access_token");
      if(data.get("refresh_token")){
        refresh_token = data.get("refresh_token");
      }

      calendar_ids = app.getProperty("calendar_ids");
      ///Sys.println(calendar_ids);
      if(calendar_ids == null || !(calendar_ids instanceof Toybox.Lang.Array) || calendar_ids.size()==0){ // because of [] and white-spaces
        getPrimaryCalendar();
      } 
      else {
        getNextCalendarEvents();
      }
    } 
    else {
      if(responseCode==428 || (responseCode == 400 && keyContains(data, "error", "authorization_pending"))){ 
        // polling for auth device user_code 428:{error=>authorization_pending, error_description=>Precondition Failed} || 400: {"error" : "authorization_pending","error_description": "Bad Request"}
        Background.exit({"user_code"=>app.getProperty("user_code"), "device_code"=>app.getProperty("device_code"), "verification_url"=>app.getProperty("verification_url")});
      } 
      else if(responseCode==403 || (responseCode == 400 && (keyContains(data, "error", "invalid_grant") || keyContains(data, "error", "expired_token")))){ 
        // 400: {error=> invalid_grant, error_description=> Token has been expired or revoked.} 
        //      {error=> expired_token, error_description=> Expired user code}
        // 403: {error=> access_denied, error_description=> Forbidden}
        getOAuthUserCode();
      } 
      else { 
        // 400: invalid_request || unsupported_grant_type
        // 401: invalid_client
        // 429: {error=> slow_down, error_description=>Rate Limit Exceeded}
        if(data==null){
          data = {"error_code"=>responseCode};
        } else {
          data.put("error_code", responseCode);
        }
        Background.exit(data);
      }
    }
  }

  function keyContains(dictionary, key, value){
    if(dictionary != null && dictionary instanceof Toybox.Lang.Dictionary){
      var val = dictionary.get(key);
      if(val != null){
        if(val.toString().find(value) != null){
          return true;
        }
      }
    }
    return false;
  }

  function getPrimaryCalendar(){
    ///Sys.println(Sys.getSystemStats().freeMemory + " on getPrimaryCalendar");
    Communications.makeWebRequest($.GoogleCalendarListUrl,
      {"maxResults"=>"15", "fields"=>"items(id,primary)", "minAccessRole"=>"owner", "showDeleted"=>false}, {:method=>Communications.HTTP_REQUEST_METHOD_GET, 
      :headers=>{ "Authorization"=>"Bearer " + access_token}},
      method(:onPrimaryCalendarCandidates));
  }

  function onPrimaryCalendarCandidates(responseCode, data) {  // expects calendar list already parsed to array
    ///Sys.println(Sys.getSystemStats().freeMemory + " on onPrimaryCalendarCandidates");
    ///Sys.println(data);
    if (responseCode == 200) {
      data = data.get("items");
      for(var i=0; i < data.size(); i++){
        if(data[i].get("primary") != null){
          primary_calendar = data[i].get("id");
          calendar_ids = [primary_calendar];
        }     
      }
      getNextCalendarEvents();
    } else {
      Background.exit({"error_code"=>responseCode});
    }
  }
    
  function getNextCalendarEvents() {
    current_index++;
    if (current_index<calendar_ids.size()) {
      ///Sys.println(calendar_ids[current_index]);
      getEvents(calendar_ids[current_index]);
      return true;
    } else {
      return false;
    }
  }
  
  function getEvents(calendar_id) {
    ///Sys.println(Sys.getSystemStats().freeMemory + " on getCalendarData");
    var today = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
    var sys_time = System.getClockTime();
    var UTCdelta = sys_time.timeZoneOffset < 0 ? sys_time.timeZoneOffset * -1 : sys_time.timeZoneOffset;
    var to = (UTCdelta/3600).format("%02d") + ":00";
    var sign = sys_time.timeZoneOffset < 0 ? "-" : "+";

    var dateStart = Lang.format("$1$-$2$-$3$T$4$:$5$:00", [today.year, today.month, today.day, today.hour, today.min]);
    dateStart += sign + to;
    today = Gregorian.info(Time.now().add(new Time.Duration(3600*24)), Time.FORMAT_SHORT); 
    var dateEnd = Lang.format("$1$-$2$-$3$T$4$:$5$:00", [today.year, today.month, today.day, today.hour, today.min]);
    dateEnd += sign + to;
    
    Communications.makeWebRequest($.GoogleCalendarEventsUrl + calendar_id + "/events", {
      "maxResults"=>"8", "orderBy"=>"startTime", "singleEvents"=>"true", "timeMin"=>dateStart, "timeMax"=>dateEnd, "fields"=>"items(summary,location,start/dateTime,end/dateTime)"}, {:method=>Communications.HTTP_REQUEST_METHOD_GET, 
        :headers=>{ "Authorization"=>"Bearer " + access_token }},
      method(:onEvents));
    ///Sys.println(Sys.getSystemStats().freeMemory + " after loading " + calendar_id );
  }
  
  var events_list_size = 0;
  function onEvents(responseCode, data) {
    ///Sys.println(Sys.getSystemStats().freeMemory +" on onEvents");
    if(responseCode == 200) { // TODO handle non 200 codes
      data = data.get("items");
      var eventsToSafelySend = primary_calendar ? 8 : 9;
      ///Sys.println(Sys.getSystemStats().freeMemory);
      for (var i = 0; i < data.size() && events_list.size() < eventsToSafelySend; i++) { // 10 events not to get out of memory
        var event = data[i];
        data[i] = null;
        //if(events_list_size>500){break;}
        ///Sys.println(Sys.getSystemStats().freeMemory +" "+event);
        if(event["start"]){ // skip day events that have only "summary"
          try {
            var eventTrim = [
              (event.get("start").get("dateTime")),
              (event.get("end").get("dateTime")), 
              i<= 3 ? (event.get("summary") ? event.get("summary").substring(0,25) : "") : "",
              i<= 3 ? event.get("location") : null,
              current_index
            ];
            if(eventTrim[3]){  // trimming and event to fit the screen right 
              eventTrim[3] = eventTrim[3].substring(0,12);
              var split = eventTrim[3].find(",");
              if(split && split>0){
                  eventTrim[3] = eventTrim[3].substring(0,split);
              }
            }
            ///Sys.println(Sys.getSystemStats().freeMemory +" "+eventTrim);
            events_list.add(eventTrim);
            events_list_size += eventTrim.toString().length();
            eventTrim = null;
            /*if(Sys.getSystemStats().freeMemory<4800){
              exitWithData();
            }*/
          } catch(ex) {
            events_list = events_list.size() ? [events_list[0]] : null;
            exitWithData();
            ///Sys.println("ex: " + ex.getErrorMessage()); Sys.println( ex.printStackTrace());
          }
        }
      }
    } 
    if (!getNextCalendarEvents()) { // done
      exitWithData();
    } 
  }

  function exitWithData(){ // TODO don't return events on errors
    Sys.println("exitWithData");
    var code_events = {"refresh_token"=>refresh_token, "events"=>events_list};
    if(primary_calendar){
      code_events["primary_calendar"] = primary_calendar; 
    }
    try{  
        ///Sys.println(Sys.getSystemStats().freeMemory +" before exit with "+ events_list.size() +" events taking "+events_list_size);
        Background.exit(code_events);
    }catch(ex){
        code_events["events"] = code_events["events"].size() ? [code_events["events"][0]] : null;
        Background.exit(code_events);
    }
  }
  
  function refreshTokenAndGetData() {
    Communications.makeWebRequest($.GoogleTokenUrl, {"client_secret"=>app.getProperty("client_secret"), "client_id"=>app.getProperty("client_id"), 
      "refresh_token"=>refresh_token, "grant_type"=>"refresh_token"}, {:method => Communications.HTTP_REQUEST_METHOD_POST},
      method(:onTokenRefresh2GetData));
  }

  function showInstructionOnMobile(data){
    var user_code = data.hasKey("user_code") ? data["user_code"] : app.getProperty("user_code");
    var verification_url = data.hasKey("verification_url") ? data["verification_url"] : app.getProperty("verification_url");

    Communications.makeOAuthRequest("https://sl8.ch/how-to-load-calendar", 
      {"verification_url"=>verification_url, "user_code"=>user_code, "client_secret"=>app.getProperty("client_secret")}, 
      "http://localhost", Communications.OAUTH_RESULT_TYPE_URL, 
      {"refresh_token"=>"refresh_token", "calendar_ids"=>"calendar_ids"});
    //Communications.openWebPage(url, params, options);
  }

  /*
    function requestOAuth(){
    Communications.makeOAuthRequest("https://myneur.github.io/late/docs/auth", 
      {"client_secret"=>app.getProperty("client_secret")}, 
      "https://localhost", Communications.OAUTH_RESULT_TYPE_URL, 
      {"refresh_token"=>"refresh_token", "calendar_indexes"=>"calendar_indexes"});
  }
  function onOauthMessage(data) {
    Sys.println("onOauthMessage " +data.data["refresh_token"]);
    code = {"refresh_token"=>data.data["refresh_token"]};
    calendar_indexes = data.data["calendar_indexes"];
    refreshTokenAndGetData();
  }*/
}