DEVICE="fenix6xpro"
/usr/bin/automator KillDevice.workflow 	
/usr/bin/automator QuitApp.workflow 	
#kill `ps aux | grep ConnectIQ.app | grep simulator | awk {'print $2'}` 2>/dev/null
connectiq 
sleep 5s
monkeydo bin/late.prg $DEVICE