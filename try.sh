DEVICE="fenix6xpro"
monkeyc -r -o bin/late.prg -y ../developer_key.der -f monkey.jungle -d $DEVICE 
# monkeyc -r -o bin/late.prg -y ../developer_key.der -f monkey.jungle -d $DEVICE
monkeydo bin/late.prg $DEVICE