using Toybox.Background;
using Toybox.System as Sys;
using Toybox.Communications;
using Toybox.Application as App;
using Toybox.Time;
using Toybox.Time.Gregorian;

const ServerToken = "https://oauth2.googleapis.com/token";
const ApiUrl = "https://www.googleapis.com/calendar/v3/calendars/";
const ApiCalendarUrl = "https://www.googleapis.com/calendar/v3/users/me/calendarList";

(:background)
class lateBackground extends Toybox.System.ServiceDelegate {

  var code;
  var calendar_indexes;

  function initialize() {
    Sys.println(Sys.getSystemStats().freeMemory + " on init");
    Sys.ServiceDelegate.initialize();
    Communications.registerForOAuthMessages(method(:onOauthMessage));
  }
  
  function onTemporalEvent() {
    Sys.println(Sys.getSystemStats().freeMemory + " on onTemporalEvent");
    var app = App.getApp();
    if (code == null){
      Sys.println("get code");
      code = app.getProperty("code");
      Sys.println(code);
    }
    if (code == null) {  // show login 
      Sys.println("code null");
      Communications.makeOAuthRequest(
        "https://myneur.github.io/late/docs/auth",
        {"client_secret"=>app.getProperty("client_secret")}, // TODO will fail if the client_secret is missing
        "https://localhost",
        Communications.OAUTH_RESULT_TYPE_URL,
        {"refresh_token"=>"refresh_token", "calendar_indexes"=>"calendar_indexes"}
      );
      Background.exit({"errorCode"=>511});
    } else {
      getAccessTokenFromRefresh();
    }
  }

  function onOauthMessage(data) {
    Sys.println("onOauthMessage " +data.data["refresh_token"]);
    code = {"refresh_token"=>data.data["refresh_token"]};
    calendar_indexes = data.data["calendar_indexes"];
    getAccessTokenFromRefresh();
  }
  
  function onAccessResponseRefresh(responseCode, data) {
    Sys.println("auth response " + responseCode);
    Sys.println(data);
    if (responseCode == 200) {
      data.put("refresh_token", code.get("refresh_token"));
      code = data;
      getCalendarData();
    } else {
      code = null;
      Background.exit({"errorCode"=>responseCode});
    }
  }
  
  function getCalendarData() {
    Communications.makeWebRequest(
         $.ApiCalendarUrl,
         {
          "maxResults"=>"20",
          "fields"=>"items(id)"
         },
         {
             :method=>Communications.HTTP_REQUEST_METHOD_GET,
             :headers=>{ "Authorization"=>"Bearer " + code.get("access_token") }
         },
         method(:onCalendarData)
     );
  }
  
  var calendar_size = 0;
  var current_index = 0;
  var id_list = [];
  function onCalendarData(responseCode, data) {
    Sys.println(Sys.getSystemStats().freeMemory + " on onCalendarData");
    var result_size = data.get("items").size();
    if (responseCode == 200) {
      var indexes;
      if (App.getApp().getProperty("calendar_indexes")) {
        indexes = App.getApp().getProperty("calendar_indexes");
      } else {
        indexes = calendar_indexes;
      }
      indexes = indexes.toCharArray();
      Sys.println("indexes "+indexes);
      var index_list = [];
      var cn = "";
      for (var i = 0; i < indexes.size(); i++) {
        var c = indexes[i];
        if (c == ',') {
          if (cn.toNumber() <= result_size) {index_list.add(cn.toNumber());}
          cn = "";
        } else {
          cn += c;
        }
      }
      if (cn.toNumber() <= result_size) {index_list.add(cn.toNumber());}
      calendar_size = index_list.size();
      
      for (var d = 0; d < index_list.size(); d++) {
        id_list.add(data.get("items")[index_list[d]].get("id"));
      }
       repeater();
      } else {
        Background.exit(code);
      }
      data = null;
    }
    
    var in_progress = -1;
    function repeater() {
    if (in_progress < current_index) {
      in_progress++;
      getCalendarEventData(id_list[current_index]);
    }
  }
  
  function getCalendarEventData(calendar_id) {
    Sys.println(Sys.getSystemStats().freeMemory + " on getCalendarData");
    var today = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
    var sys_time = System.getClockTime();
    var UTCdelta = sys_time.timeZoneOffset < 0 ? sys_time.timeZoneOffset * -1 : sys_time.timeZoneOffset;
    var to = (UTCdelta/3600).format("%02d") + ":00";
    var sign = sys_time.timeZoneOffset < 0 ? "-" : "+";
    var dateStart = Lang.format(
        "$1$-$2$-$3$T$4$:$5$:00",
        [
            today.year,
            today.month,
            today.day,
            today.hour,
            today.min
        ]
    );
    dateStart += sign + to;
      today = Gregorian.info(Time.now().add(new Time.Duration(3600*24)), Time.FORMAT_SHORT); 
      var dateEnd = Lang.format(
        "$1$-$2$-$3$T$4$:$5$:00",
        [
            today.year,
            today.month,
            today.day,
            today.hour,
            today.min
        ]
    );
    dateEnd += sign + to;
    Communications.makeWebRequest(
         $.ApiUrl + calendar_id + "/events",
         {
          "maxResults"=>"8",
          "orderBy"=>"startTime",
          "singleEvents"=>"true",
          "timeMin"=>dateStart,
          "timeMax"=>dateEnd,
          "fields"=>"items(summary,location,start/dateTime,end/dateTime)"
         },
         {
             :method=>Communications.HTTP_REQUEST_METHOD_GET,
             :headers=>{ "Authorization"=>"Bearer " + code.get("access_token") }
         },
         method(:onCalendarEventData)
     );
    Sys.println(Sys.getSystemStats().freeMemory + " after loading " + calendar_id );
  }
  var events_list_size = 0;  
  var events_list = [];

  function onCalendarEventData(responseCode, data) {
    Sys.println(Sys.getSystemStats().freeMemory +" on onCalendarEventData");
    if(responseCode == 200) {
      data = data.get("items");
      for (var i = 0; i < data.size() && events_list.size()<9; i++) { // 10 events not to get out of memory
        var event = data[i];
        data[i] = null;
        //if(events_list_size>500){break;}
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
            events_list.add(eventTrim);
            events_list_size += eventTrim.toString().length();
            eventTrim = null;
            } catch(ex) {
              Sys.println("ex: " + ex.getErrorMessage()); Sys.println( ex.printStackTrace());
            }
          }
        }

        if (current_index == calendar_size-1) { // done
          var code_events;
          if (calendar_indexes != null) {
            code_events = {
              "code"=>code,
              "events"=>events_list,
              "calendar_indexes"=>calendar_indexes
            };
          } else {
            code_events = {
              "code"=>code,
              "events"=>events_list
            };
          }
          //for(var j=events_list.size()-1; j>=0 ;j--){
            try{  
                Sys.println(Sys.getSystemStats().freeMemory +" before exit with "+ events_list.size() +" events taking "+events_list_size);
                data = null; // to free memory, because it is shared with the limit of the data that can be ppassed
                id_list = null;
                
                Background.exit(code_events);
            }catch(ex){
              Sys.println(Sys.getSystemStats().freeMemory +" on exception with "+ events_list.size() +" events taking " + events_list_size);
              Sys.println("bg ex: " + ex.getErrorMessage()); 
              Sys.println(ex.printStackTrace());
              /*if(j>0 && j<events_list.size()){
                events_list[j][3]=null;
                events_list[j][2]=null;
              } else {*/
                code_events["events"] = code_events["events"].size() ? [code_events["events"][0]] : null;
                Background.exit(code_events);
              //}
            }
          //}
        } else {
          current_index++;
        }
        data = null;
        repeater();

      } else { // no data
        var code_events;
        if (calendar_indexes != null) {
          code_events = {
            "code"=>code,
            "events"=>events_list,
            "calendar_indexes"=>calendar_indexes
          };
        } else {
          code_events = {
            "code"=>code,
            "events"=>events_list
          };
        }
        try{
          Background.exit(code_events);
        }catch(ex){
          Background.exit(null);
        }
      }
    }
  
  function getAccessTokenFromRefresh() {
     Communications.makeWebRequest(
         $.ServerToken,
         {
             "client_secret"=>App.getApp().getProperty("client_secret"),
             "client_id"=>App.getApp().getProperty("client_id"),
             "refresh_token"=>code.get("refresh_token"),
             "grant_type"=>"refresh_token"
         },
         {
             :method => Communications.HTTP_REQUEST_METHOD_POST
         },
         method(:onAccessResponseRefresh)
     );
  }
}