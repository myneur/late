DEVICE=descentmk351mm
# JSON resources for testing in test.monkey are supported only by some devices. 
/usr/bin/automator KillDevice.workflow 	
/usr/bin/automator QuitApp.workflow 	
sleep 2
#kill `ps aux | grep ConnectIQ.app | grep simulator | awk {'print $2'}` 2>/dev/null
connectiq 
echo "monkeyc"
monkeyc -l 0 -o late.prg -y ../../developer_key.der -f ../test.jungle -d $DEVICE 
#monkeyc -r -o late.prg --typecheck 0 -y ../../developer_key.der -f ../monkey.jungle -d $DEVICE 
# --Eno-invalid-symbol # turns missing annotation error into warning # https://forums.garmin.com/developer/connect-iq/i/bug-reports/excludeannotations-stopped-in-new-sdks?service=https:%2f%2fforums.garmin.com%2fdeveloper%2fconnect-iq%2fi%2fbug-reports%2fexcludeannotations-stopped-in-new-sdks
# -r --optimization 2z
# p = performance, z= codespace, 2= fast 3= slow optimizations https://developer.garmin.com/connect-iq/monkey-c/compiler-options/
monkeydo late.prg $DEVICE