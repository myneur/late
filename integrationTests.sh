





# intentionally left blank, so you'll READ the TODO!!!



# TODO!!! FINALIZE testing weather together with calendar: now only the calendar loads, because of Fucking Garmin simulator is crashing ! 
# TODO: option a) 1. test weather in (:debug), follow with calendar in (:release)
# TODO: option b) 1. implement (:debug) option to load weather before calendar 3. refactor DONTSAVEPROPERTIES 

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
	DEVICES=(fenix6xpro)
	RUN="_init"
	RECOMPILE=1
	RELEASE=0
	simulate	
}

function testLogin(){
	VARS="login.vars.xml"
	cp resources-tests-templates/$VARS resources-tests/test-variables.xml
	echo $VARS
	BACKGROUND=0
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
	VARS="calendar-with-weather-shown.vars.xml"
	cp resources-tests-templates/$VARS resources-tests/test-variables.xml
	echo $VARS
	BACKGROUND=1
	setVariables
	DEVICES=(fenix6xpro venusq fr245 fr945 fenix5s) # data 280 240 218 OLED rectangle nofloors weakest-with-data no-storage-from-background 
	RUN="_calendar_weather"
	BACKGROUND=1
	RECOMPILE=1
	RELEASE=1
	DONTSAVEPROPERTIES=0	# after the first run, the calendar is actually always loaded, so we don't need it
	simulate
}

function testCalendar(){
	VARS="calendar.vars.xml"
	cp resources-tests-templates/$VARS resources-tests/test-variables.xml
	echo $VARS
	BACKGROUND=1
	setVariables
	DEVICES=(fenix6xpro venusq fr245 fr945 fenix5s) # data 280 240 218 OLED rectangle nofloors weakest-with-data no-storage-from-background
	RUN="_calendar"
	BACKGROUND=1
	RECOMPILE=1
	RELEASE=1
	DONTSAVEPROPERTIES=0	# after the first run, the calendar is actually always loaded, so we don't need it
	simulate
}

function testWeatherJustInDebugCalendarFollowsInRelease(){ # TODO !!! now it only loads weather because of the Ficking Garmin Simulaotr is crashing
	VARS="start-weather.vars.xml"
	cp resources-tests-templates/$VARS resources-tests/test-variables.xml
	echo $VARS
	BACKGROUND=1
	setVariables
	DEVICES=(fenix6xpro) 
	RUN="_weather"
	BACKGROUND=1
	RECOMPILE=1
	RELEASE=1
	DONTSAVEPROPERTIES=0
	simulate 
	echo "sleep 5s"
	sleep 5
	echo "screenshot"
	screencapture  ~/Downloads/$DEVICE$RUN$RUN 

}

# missing resolutions 
function testMissingResolutions(){
	VARS="calendar-with-weather-shown.vars.xml"
	cp resources-tests-templates/$VARS resources-tests/test-variables.xml
	echo $VARS
	BACKGROUND=1
	setVariables
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
	VARS="no-data.vars.xml"
	cp resources-tests-templates/$VARS resources-tests/test-variables.xml
	echo $VARS
	BACKGROUND=0
	setVariables
	DEVICES=(fenix3 fr230 fr45 vivoactive_hr fr735xt) # no-data 218 65k 3CIQ1 180 semi-round weakest old disabled-data
	RUN="_no-data"
	BACKGROUND=0
	RECOMPILE=1
	RELEASE=1
	DONTSAVEPROPERTIES=0
	simulate
}


function testFloorsAndMinutes(){
	VARS="floors-and-minutes.vars.xml"
	cp resources-tests-templates/$VARS resources-tests/test-variables.xml
	echo $VARS
	BACKGROUND=0
	setVariables
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
	VARS="full-strong.vars.xml"
	cp resources-tests-templates/$VARS resources-tests/test-variables.xml
	echo $VARS
	BACKGROUND=1
	setVariables
	DEVICES=(wearable2021 venu smallwearable2021 fenix6xpro venusq fr945 vivoactive4 fr745 fr735xt garminswim2 vivoactive_hr) # 416 390 360 280 260 240 rectangle 218 16c 180 semiround 208 CIQ1   rectangle
	RUN="_strong"
	BACKGROUND=0
	RECOMPILE=1
	RELEASE=1
	DONTSAVEPROPERTIES=0
	simulate
}

function testMonkeyJungleVariations(){
	VARS="full-strong.vars.xml"
	cp resources-tests-templates/$VARS resources-tests/test-variables.xml
	echo $VARS
	BACKGROUND=0
	setVariables
	DEVICES=(wearable2021 venu smallwearable2021 fenix6xpro venusq venusqm approachs62 approachs60 fr245 fr245m fr945 vivoactive4 fr745 enduro fr735xt garminswim2 vivoactive_hr fenix3 fenix3_hr d2bravo d2bravo_titanium fr45 garminswim2)
	RUN="_jungle"
	BACKGROUND=0
	RECOMPILE=1
	RELEASE=1
	DONTSAVEPROPERTIES=1
	simulate
}

function toDebug(){
	VARS="full-strong.vars.xml"
	VARS="no-data.vars.xml"
	#cp resources-tests-templates/$VARS resources-tests/test-variables.xml
	#echo $VARS
	#setVariables
	DEVICES=(enduro) 
	RUN="_debug"
	BACKGROUND=0
	RECOMPILE=1
	RELEASE=1
	simulate
}

#toDebug
#testLogin
#setVariables # just demo of what can be done
testCalendarWithWeatherShown
#testMissingResolutions
#strongInAllReslutions

#testNoData
#testFloorsAndMinutes
#testMonkeyJungleVariations