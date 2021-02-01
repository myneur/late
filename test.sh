DEVICE="vivoactive4"
monkeyc -o bin/late.prg -y ../developer_key.der -f monkey.jungle -d $DEVICE
# monkeyc -r -o bin/late.prg -y ../developer_key.der -f monkey.jungle -d $DEVICE
connectiq 
monkeydo bin/late.prg $DEVICE