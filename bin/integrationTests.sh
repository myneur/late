# Tests uncommented scenarios at the bottom on defined devices on MacOS and screenshots results into ~/Downloads

echo ""

function simulate(){
	echo $DEVICES
	for DEVICE in "${DEVICES[@]}"
	do
		##/usr/bin/automator QuitApp.workflow 
		if [[ $DONTSAVEPROPERTIES -eq 1 ]] ;then
			echo "!!! previous session won't be saved !!! KILLing simulator !!!"
			kill `ps aux | grep ConnectIQ.app | grep simulator | awk {'print $2'}` 2>/dev/null 
		else 
			#echo "quit, wait 5s, kill"
			/usr/bin/automator KillDevice.workflow 	
			/usr/bin/automator QuitApp.workflow 	
			
		fi
		echo " > run simulator"
		sleep 2
		connectiq
		if [[ $RECOMPILE -eq 1 ]] ;then
			if [[ $RELEASE -eq 1 ]] ;then
				FLAGS="-r"
				JUNGLE=../monkey.jungle
				echo " > compile :release"
			else
				FLAGS=""
				JUNGLE=../test.jungle
				echo " > compile :debug"
			fi
			monkeyc -l 0 -o late.prg -y ../../developer_key.der -f $JUNGLE -d $DEVICE $FLAGS
			echo " > sleep 4s"
			sleep 4
		else 
			echo " > sleep 5s"
			sleep 5
		fi
		# echo " > sleep 5s"; sleep 5
		echo " > simulate "$DEVICE 
		monkeydo late.prg $DEVICE &
		echo " > sleep 5s"
		sleep 5
		if [[ $BACKGROUND -eq 1 ]] ;then
			/usr/bin/automator ConnectIQbackgroundEvents.workflow 
			echo " > sleep 5s"
			echo " > sim will crash:"
			sleep 5
		fi
		echo " > screenshot "$DEVICE$RUN 
		screencapture  ~/Downloads/$TEST$DEVICE$RUN".png"
	done
}

function setVariables(){
	echo " > setVariables"
	TEST="setup-"
	DEVICES=(fenix6)
	RUN="_init"
	RECOMPILE=1
	RELEASE=0
	simulate	
}

# new resolutions 
function testNewResolutions(){
	VARS="calendar-with-weather-shown.vars.xml"
	cp ../resources-tests-templates/$VARS ../resources-tests/test-variables.xml
	echo " < "$VARS
	BACKGROUND=1
	setVariables
	TEST="new_res-"
	DEVICES=(fr965 fr45) # 454
	RUN="_resolution"
	BACKGROUND=0
	RECOMPILE=1
	RELEASE=1
	DONTSAVEPROPERTIES=0
	simulate
}
function testNewResolutionsInStrong(){
	VARS="full-strong.vars.xml"
	cp ../resources-tests-templates/$VARS ../resources-tests/test-variables.xml
	echo " < "$VARS
	BACKGROUND=1
	setVariables
	TEST="strong-"
	DEVICES=(fr965 fr45) # 454
	RUN="_strong"
	BACKGROUND=0
	RECOMPILE=1
	RELEASE=1
	DONTSAVEPROPERTIES=0
	simulate
}

# expects the watch is logged out
function testLogin(){
	VARS="login.vars.xml"
	cp ../resources-tests-templates/$VARS ../resources-tests/test-variables.xml
	echo " < "$VARS
	BACKGROUND=0
	setVariables
	TEST="login-"
	DEVICES=(fenix6)
	RUN="_login1"
	BACKGROUND=1
	RECOMPILE=1
	RELEASE=1
	simulate	
	echo "login to google.com/device and press ENTER to continue"
	read 
	#echo " > login to google.com/device"
	#echo " > sleep 10s"
	RUN="_login2"
	RECOMPILE=0
	simulate	
}

function testCalendarWithWeatherShown(){
	VARS="calendar-with-weather-shown.vars.xml"
	cp ../resources-tests-templates/$VARS ../resources-tests/test-variables.xml
	echo " < "$VARS
	BACKGROUND=1
	setVariables
	TEST="cal-weather-"
	DEVICES=(fenix6xpro venusq fr245 fr945 fenix5s) # data 280 240 218 OLED rectangle nofloors weakest-with-data no-storage-from-background 
	RUN="_calendar_weather"
	BACKGROUND=1
	RECOMPILE=1
	RELEASE=1
	DONTSAVEPROPERTIES=0	# after the first run, the calendar is actually always loaded, so we don't need it
	simulate
}

function testCalendarOnly(){
	VARS="calendar.vars.xml"
	cp ../resources-tests-templates/$VARS ../resources-tests/test-variables.xml
	echo " < "$VARS
	BACKGROUND=1
	setVariables
	TEST="cal-"
	DEVICES=(fenix6xpro venusq fr245 fr945 fenix5s) # data 280 240 218 OLED rectangle nofloors weakest-with-data no-storage-from-background
	RUN="_calendar"
	BACKGROUND=1
	RECOMPILE=1
	RELEASE=1
	DONTSAVEPROPERTIES=0	# after the first run, the calendar is actually always loaded, so we don't need it
	simulate
}

function testWeatherInDebug(){ # TODO !!! now it only loads weather because of the Ficking Garmin Simulaotr is crashing
	TEST="weather-debug-"
	VARS="start-weather.vars.xml"
	cp ../resources-tests-templates/$VARS ../resources-tests/test-variables.xml
	echo " < "$VARS
	BACKGROUND=1
	RECOMPILE=1
	RELEASE=0
	RUN="_weather1"
	DEVICES=(fenix6xpro) 
	simulate
	RUN="_weather2"
	simulate	

}

function testSubscriptionInDebug(){ # TODO !!! now it only loads weather because of the Ficking Garmin Simulaotr is crashing
	TEST="subs-"
	VARS="start-weather.vars.xml"
	cp ../resources-tests-templates/$VARS ../resources-tests/test-variables.xml
	echo " < "$VARS
	BACKGROUND=1
	RECOMPILE=1
	RELEASE=0
	RUN="_weather1"
	DEVICES=(fenix6xpro) 
	simulate
	RUN="_weather1"
	echo "press any key to subscribe or continue"
	read
	simulate	
}

# all resolutions permutations with or without calendar and weather
function testResolutionsPermutations(){
	CONFS=("calendar-with-weather-shown.vars.xml" "calendar.vars.xml" "start-weather.vars.xml" "no-data.vars.xml")
	echo $CONFS
	I=1
	for CONF in "${CONFS[@]}"
	do
		VARS=$CONF
		cp ../resources-tests-templates/$VARS ../resources-tests/test-variables.xml
		echo " < "$VARS
		BACKGROUND=1
		setVariables
		TEST="allres-"
		DEVICES=(fr965 venu2 venu venu2s fenix6xpro vivoactive4 fenix5 fenix5s fr735xt fr45 vivoactive_hr) # 416 390 360 280 260 240 218 208
		BACKGROUND=0
		RECOMPILE=1
		RELEASE=1
		DONTSAVEPROPERTIES=0
		RUN="_"$I
		simulate
		I=$((I+1))
	done
}

# all resolutions with strong flavor
function testStrongInAllReslutions(){
	VARS="full-strong.vars.xml"
	cp ../resources-tests-templates/$VARS ../resources-tests/test-variables.xml
	echo " < "$VARS
	BACKGROUND=1
	setVariables
	TEST="strong-"
	DEVICES=(fr965 venu2 venu venu2s fenix6xpro venusq fr945 vivoactive4 fenix5 fenix5s fr735xt fr45 vivoactive_hr) # 416 390 360 280 260 240 rectangle 218 16c 180 semiround 208 CIQ1   rectangle
	RUN="_strong"
	BACKGROUND=0
	RECOMPILE=1
	RELEASE=1
	DONTSAVEPROPERTIES=0
	simulate
}

# no data devices
function testNoData(){
	VARS="no-data.vars.xml"
	cp ../resources-tests-templates/$VARS ../resources-tests/test-variables.xml
	echo " < "$VARS
	BACKGROUND=0
	setVariables
	TEST="nodata-"
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
	cp ../resources-tests-templates/$VARS ../resources-tests/test-variables.xml
	echo " < "$VARS
	BACKGROUND=0
	setVariables
	TEST="floors-and-mins-"
	DEVICES=(fenix3) # no-data 218 65k 3CIQ1 180 semi-round weakest old disabled-data
	RUN="_minuteFloors"
	BACKGROUND=0
	RECOMPILE=1
	RELEASE=1
	DONTSAVEPROPERTIES=0
	simulate
}

function testMonkeyJungleVariations(){
	VARS="full-strong.vars.xml"
	cp ../resources-tests-templates/$VARS ../resources-tests/test-variables.xml
	echo " < "$VARS
	BACKGROUND=0
	setVariables
	TEST="monkeys-"
	DEVICES=(venu2 venu venu2s fenix6xpro venusq venusqm approachs62 approachs60 fr245 fr245m fr945 vivoactive4 fr745 enduro fr735xt vivoactive_hr fenix3 fenix3_hr d2bravo d2bravo_titanium fr45)
	RUN="_jungle"
	BACKGROUND=0
	RECOMPILE=1
	RELEASE=1
	DONTSAVEPROPERTIES=0
	simulate
}

# custom variables echoed to the test varaibles
function testAdHocDebug(){
	TEST="current-"
	RELEASE=0
	RECOMPILE=1
	RUN="_debug"
	VARS="calendar-with-weather-shown.vars.xml"
	echo '<resources><jsonData id="testData">{"Message":"Custom debug!","Reinitialize": true,"Properties": {"weather": true,"activity": 6,"dialSize":0,"location": [50.1,14.4],"calendar_ids": ["simply@myneur.eu","join@myneur.eu"]},"AfterLayoutCharProperties":{"lastLoad": "c"}}</jsonData></resources>' > ../resources-tests/test-variables.xml
	DEVICES=(fr965) 	
	BACKGROUND=0
	simulate
}


# EVERY RELEASE to check that it does not get out of memory by loadinc many calendar events

#testCalendarWithWeatherShown

# WEATHER UPDATES

#testWeatherInDebug

# MAJOR UPDATES 

#testLogin
#testSubscriptionInDebug

# SUPPORT FOR NEW DEVICES

#testNewResolutions
#testNewResolutionsInStrong
#testResolutionsPermutations
#testStrongInAllReslutions

# OLD OR WEAK DEVICES 

#testNoData
#testFloorsAndMinutes
#testMonkeyJungleVariations

# USED BY ALL ABOVE
#setVariables # used to init variables

# AD HOC
testAdHocDebug