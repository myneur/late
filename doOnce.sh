# data devices: 
DEVICES=(fenix6xpro) # data 280 240 218 OLED rectangle nofloors weakest-with-data no-storage-from-background
RUN="_data"
echo $DEVICES

function test(){
	for DEVICE in "${DEVICES[@]}"
	do
		connectiq
		monkeydo bin/late.prg $DEVICE &
		sleep 5
		/usr/bin/automator ConnectIQbackgroundEvents.workflow 

		sleep 5
		screencapture  ~/Downloads/$DEVICE$RUN 
		/usr/bin/automator QuitApp.workflow 
	done
}
test