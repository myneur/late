DEVICE="fenix6xpro"
monkeyc -o bin/late.prg -y ../developer_key.der -f monkey.jungle -d $DEVICE 
# monkeyc -r -o bin/late.prg -y ../developer_key.der -f monkey.jungle -d $DEVICE
kill `ps aux | grep ConnectIQ.app | grep simulator | awk {'print $2'}` 2>/dev/null
connectiq 
sleep 30s
monkeydo bin/late.prg $DEVICE