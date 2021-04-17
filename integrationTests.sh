





# intentionally left blank, so you'll READ the TODO!!!



# TODO!!! FINALIZE testing weather together with calendar: now only the calendar loads, because of Fucking Garmin simulator is crashing ! 
# TODO: 1. implement (:debug) option to load weather before calendar 3. refactor DONTSAVEPROPERTIES 

function simulate(){
	echo $DEVICES
	for DEVICE in "${DEVICES[@]}"
	do
		##/usr/bin/automator QuitApp.workflow 
		if [[ $DONTSAVEPROPERTIES -eq 1 ]] ;then
			echo " !!! previous session won't be saved !!! KILLing simulator !!!"
		else 
			echo "quit, wait 5s, kill"
			/usr/bin/automator KillDevice.workflow 	
			/usr/bin/automator QuitApp.workflow 	
			sleep 5
		fi
		kill `ps aux | grep ConnectIQ.app | grep simulator | awk {'print $2'}` 2>/dev/null 
		echo "run simulator"
		connectiq
		if [[ $RECOMPILE -eq 1 ]] ;then
			if [[ $RELEASE -eq 1 ]] ;then
				FLAGS="-r"
				JUNGLE=monkey.jungle
				echo "compile :release"
			else
				FLAGS=""
				JUNGLE=test.jungle
				echo "compile :debug"
			fi
			monkeyc -o bin/late.prg -y ../developer_key.der -f $JUNGLE -d $DEVICE $FLAGS
		else 
			echo "sleep 5s"
			sleep 5
		fi
		# echo "sleep 5s"; sleep 5
		echo "simulate "$DEVICE 
		monkeydo bin/late.prg $DEVICE &
		if [[ $BACKGROUND -eq 1 ]] ;then
			echo "sleep 5s"
			sleep 5
			/usr/bin/automator ConnectIQbackgroundEvents.workflow 
		fi
		
		echo "sleep 5s"
		sleep 5
		echo "screenshot"
		screencapture  ~/Downloads/$DEVICE$RUN 
	done
}

function setVariables(){
	echo "setVariables"
	DEVICES=(fenix6)
	RUN="_init"
	BACKGROUND=0
	RECOMPILE=1
	RELEASE=0
	simulate	
}

function testLogin(){
	VARS="test-variables-login.xml"
	cp resources-tests-templates/$VARS resources-tests/test-variables.xml
	echo $VARS
	setVariables
	DEVICES=(fenix6)
	RUN="_login1"
	BACKGROUND=1
	RECOMPILE=1
	RELEASE=1
	simulate	
	echo "login to google.com/device and press ENTER to continue"
	read 
	#echo "login to google.com/device"
	#echo "sleep 10s"
	RUN="_login2"
	RECOMPILE=0
	simulate	
}

function testCalendarWithWeatherShown(){
	VARS="test-variables-calendar-with-weather-shown.xml"
	cp resources-tests-templates/$VARS resources-tests/test-variables.xml
	echo $VARS
	setVariables
	DEVICES=(fenix6xpro venusq fr245 fr945 fenix5s) # data 280 240 218 OLED rectangle nofloors weakest-with-data no-storage-from-background
	DEVICES=(fenix6xpro ) 
	RUN="_calendar_weather"
	BACKGROUND=1
	RECOMPILE=1
	RELEASE=1
	DONTSAVEPROPERTIES=0	# after the first run, the calendar is actually always loaded, so we don't need it
	simulate
}

function testCalendar(){
	VARS="test-variables-calendar.xml"
	cp resources-tests-templates/$VARS resources-tests/test-variables.xml
	echo $VARS
	setVariables
	DEVICES=(fenix6xpro venusq fr245 fr945 fenix5s) # data 280 240 218 OLED rectangle nofloors weakest-with-data no-storage-from-background
	RUN="_calendar"
	BACKGROUND=1
	RECOMPILE=1
	RELEASE=1
	DONTSAVEPROPERTIES=0	# after the first run, the calendar is actually always loaded, so we don't need it
	simulate
}

function testWeather(){
	VARS="test-variables-weather-with-calendar-shown.xml"
	cp resources-tests-templates/$VARS resources-tests/test-variables.xml
	echo $VARS
	setVariables
	DEVICES=(fenix6xpro) 
	RUN="_weather"
	BACKGROUND=0
	RECOMPILE=1
	RELEASE=1
	DONTSAVEPROPERTIES=0
	echo "at fist calendar is loaded"
	simulate 
	echo "sleep 5s"
	sleep 5
	echo "loading weather despite crashed simulator"
	/usr/bin/automator ConnectIQbackgroundEvents.workflow 
	echo "sleep 5s"
	sleep 5
	echo "screenshot"
	screencapture  ~/Downloads/$DEVICE$RUN$RUN 
echo "TODO!!! don't work yet, because the second load is not done due to crashed simulator !!! "

}

# missing resolutions 
function testMissingResolutions(){
	VARS="test-variables-calendar-with-weather-shown.xml"
	cp resources-tests-templates/$VARS resources-tests/test-variables.xml
	echo $VARS
	DEVICES=(wearable2021 venu smallwearable2021 vivoactive4) # 416 390 360 260 
	RUN="_resolution"
	BACKGROUND=0
	RECOMPILE=1
	RELEASE=1
	DONTSAVEPROPERTIES=0
	simulate
}

# no data devices
function testNoData(){
	VARS="test-variables-no-data.xml"
	cp resources-tests-templates/$VARS resources-tests/test-variables.xml
	echo $VARS
	DEVICES=(fenix3 fr230 fr45 vivoactive_hr fr735xt) # no-data 218 65k 3CIQ1 180 semi-round weakest old disabled-data
	RUN="_no-data"
	BACKGROUND=0
	RECOMPILE=1
	RELEASE=1
	DONTSAVEPROPERTIES=0
	simulate
}


function testFloorsAndMinutes(){
	VARS="test-variables-floors-and-minutes.xml"
	cp resources-tests-templates/$VARS resources-tests/test-variables.xml
	echo $VARS
	
	DEVICES=(fenix3) # no-data 218 65k 3CIQ1 180 semi-round weakest old disabled-data
	RUN="_minuteFloors"
	BACKGROUND=0
	RECOMPILE=1
	RELEASE=1
	DONTSAVEPROPERTIES=0
	simulate
}

# all resolutions with strong flavor
function strongInAllReslutions(){
	VARS="test-variables-full-strong.xml"
	cp resources-tests-templates/$VARS resources-tests/test-variables.xml
	echo $VARS
	
	DEVICES=(wearable2021 venu smallwearable2021 fenix6xpro venusq fr945 vivoactive4 fr745 fr735xt garminswim2 vivoactive_hr) # 416 390 360 280 260 240 rectangle 218 16c 180 semiround 208 CIQ1   rectangle
	RUN="_strong"
	BACKGROUND=0
	RECOMPILE=1
	RELEASE=1
	DONTSAVEPROPERTIES=0
	simulate
}

#testLogin
#setVariables # just demo of what can be done
testCalendarWithWeatherShown
#testMissingResolutions
#strongInAllReslutions

#testNoData
#testFloorsAndMinutes
# TODO testWeather