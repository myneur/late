DEVICE="approachs62"
kill `ps aux | grep ConnectIQ.app | grep simulator | awk {'print $2'}` 2>/dev/null
connectiq 
monkeyc -r -o bin/late.prg -y ../developer_key.der -f monkey.jungle -d $DEVICE 
sleep 5s
monkeydo bin/late.prg $DEVICE