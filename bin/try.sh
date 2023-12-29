DEVICE="venusq2m"
monkeyc -o late.prg --typecheck 0 -y ../../developer_key.der -f ../test.jungle -d $DEVICE 
# monkeyc -r -o bin/late.prg -y ../developer_key.der -f monkey.jungle -d $DEVICE
monkeydo late.prg $DEVICE