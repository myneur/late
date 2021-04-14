DEVICE="fenix6"
GarminHOME=~/Library/Application\ Support/Garmin/ConnectIQ/Sdks/connectiq-sdk/bin
connectiq 
monkeyc --unit-test -o bin/test.prg -y ../developer_key.der -f monkey.jungle -d $DEVICE 
java -classpath "$GarminHOME/monkeybrains.jar" com.garmin.monkeybrains.monkeydodeux.MonkeyDoDeux -f bin/test.prg  -s "$GarminHOME/shell" -d $DEVICE -t 
#monkeyc -y ../developer_key.der -f monkey.jungle -d $DEVICE --unit-test -o bin/test.prg