DEVICE="fenix6xpro"
monkeyc -o late.prg -y ../../developer_key.der -f ../test.jungle -d $DEVICE 
# monkeyc -r -o bin/late.prg -y ../developer_key.der -f monkey.jungle -d $DEVICE
monkeydo late.prg $DEVICE