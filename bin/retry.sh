DEVICE="epix2"
/usr/bin/automator KillDevice.workflow 	
/usr/bin/automator QuitApp.workflow 	
sleep 2s
#kill `ps aux | grep ConnectIQ.app | grep simulator | awk {'print $2'}` 2>/dev/null
connectiq 
echo "monkeyc"
monkeyc -o late.prg -y ../../developer_key.der -f ../test.jungle -d $DEVICE 
#monkeyc -r -o bin/late.prg -y ../developer_key.der -f monkey.jungle -d $DEVICE 
monkeydo late.prg $DEVICE