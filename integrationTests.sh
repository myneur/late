# data devices: 
DEVICES=(fenix6xpro venusq fr245 fr945 fenix5s) # data 280 240 218 OLED rectangle nofloors weakest-with-data no-storage-from-background
RUN="_data"
echo $DEVICES
for DEVICE in "${DEVICES[@]}"
do
	kill `ps aux | grep ConnectIQ.app | grep simulator | awk {'print $2'}` 2>/dev/null
	echo "connectiq"
	connectiq
	echo "monkeyc"
	monkeyc -o bin/late.prg -y ../developer_key.der -f monkey.jungle -d $DEVICE 
	echo "sleep 30s"
	sleep 30
	echo "monkeydo "$DEVICE 
	monkeydo bin/late.prg $DEVICE &

	#/usr/bin/automator ~/Library/Mobile\ Documents/com\~apple\~Automator/Documents/ConnectIQscreenshot.workflow 
	echo "sleep 6m"
	sleep 360
	echo "screencapture"
	screencapture  /Users/myneur/Downloads/$DEVICE$RUN 

	SIM=`ps aux | grep ConnectIQ.app | grep simulator | awk {'print $2'}`
	echo "kill "$SIM
	kill $SIM
	#kill `ps aux | grep ConnectIQ.app | grep simulator | awk {'print $2'}`
done

# todo (:debug), lastLoad and -r again fr945 to load weather
DEVICES=(fr945)

# no data devices
DEVICES=(fenix3 fr230 fr45 vivoactive_hr fr735xt) # no-data 218 65k 3CIQ1 180 semi-round weakest old disabled-data
RUN="_no-data"
echo $DEVICES
for DEVICE in "${DEVICES[@]}"
do
	kill `ps aux | grep ConnectIQ.app | grep simulator | awk {'print $2'}` 2>/dev/null
	echo "connectiq"
	connectiq
	echo "monkeyc"
	monkeyc -o bin/late.prg -y ../developer_key.der -f monkey.jungle -d $DEVICE 
	echo "sleep 30s"
	sleep 30
	echo "monkeydo "$DEVICE 
	monkeydo bin/late.prg $DEVICE &
	echo "sleep 5s"
	sleep 5
	echo "screencapture"
	screencapture  /Users/myneur/Downloads/$DEVICE$RUN

	SIM=`ps aux | grep ConnectIQ.app | grep simulator | awk {'print $2'}`
	echo "kill "$SIM
	kill $SIM
	#kill `ps aux | grep ConnectIQ.app | grep simulator | awk {'print $2'}`
done

# missing resolutions 
DEVICES=(wearable2021 venu smallwearable2021 vivoactive4) # 416 390 360 260 
RUN="_resolution"
echo $DEVICES
for DEVICE in "${DEVICES[@]}"
do
	kill `ps aux | grep ConnectIQ.app | grep simulator | awk {'print $2'}` 2>/dev/null
	echo "connectiq"
	connectiq
	echo "monkeyc"
	monkeyc -o bin/late.prg -y ../developer_key.der -f monkey.jungle -d $DEVICE 
	echo "sleep 30s"
	sleep 30
	echo "monkeydo "$DEVICE 
	monkeydo bin/late.prg $DEVICE &
	echo "sleep 5s"
	sleep 5
	echo "screencapture"
	screencapture  /Users/myneur/Downloads/$DEVICE$RUN

	SIM=`ps aux | grep ConnectIQ.app | grep simulator | awk {'print $2'}`
	echo "kill "$SIM
	kill $SIM
	#kill `ps aux | grep ConnectIQ.app | grep simulator | awk {'print $2'}`
done
# all resolutions with strong flavor
DEVICES=(wearable2021 venu smallwearable2021 fenix6xpro venusq fr945 vivoactive4 fr745 fr735xt garminswim2 vivoactive_hr) # 416 390 360 280 260 240 rectangle 218 16c 180 semiround 208 CIQ1   rectangle
RUN="_strong"
# need to change properties: intermediate -r compilation or annotation can be used to store different variable prior)