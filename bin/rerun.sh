DEVICE="epix2"
/usr/bin/automator KillDevice.workflow 	
#/usr/bin/automator QuitApp.workflow 	
#kill `ps aux | grep ConnectIQ.app | grep simulator | awk {'print $2'}` 2>/dev/null
sleep 2s
connectiq 
sleep 5s
monkeydo late.prg $DEVICE