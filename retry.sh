DEVICE="fenix6xpro"
kill `ps aux | grep ConnectIQ.app | grep simulator | awk {'print $2'}` 2>/dev/null
connectiq 
monkeyc -o bin/late.prg -y ../developer_key.der -f test.jungle -d $DEVICE 
sleep 5s
monkeydo bin/late.prg $DEVICE