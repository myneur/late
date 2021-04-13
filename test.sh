DEVICE="fenix6"
connectiq 
#monkeyc -o bin/late.prg -y ../developer_key.der -f monkey.jungle -d $DEVICE
#monkeydo.bat bin/late.prg /t
#java -classpath ~/Library/Application\ Support/Garmin/ConnectIQ/Sdks/connectiq-sdk/bin/monkeybrains.jar com.garmin.monkeybrains.monkeydodeux.MonkeyDoDeux -f bin/late.prg -d $DEVICE -s "%home%shell.exe" %test_flag% %test_names%
java -classpath ~/Library/Application\ Support/Garmin/ConnectIQ/Sdks/connectiq-sdk/bin/monkeybrains.jar com.garmin.monkeybrains.monkeydodeux.MonkeyDoDeux -f bin/late.prg -d $DEVICE -s ~/Library/Application\ Support/Garmin/ConnectIQ/Sdks/connectiq-sdk/bin/shell -t 


#monkeydo bin/late.prg $DEVICE