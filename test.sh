DEVICE="vivoactive3m"
monkeyc -r -o bin/late.prg -y ../developer_key.der -f monkey.jungle -d $DEVICE
connectiq 
monkeydo bin/late.prg $DEVICE