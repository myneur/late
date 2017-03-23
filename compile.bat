@echo off
echo -- cleaning %1 project --
del C:\Users\clive\AppData\Local\Temp\Garmin\Apps\%1*.prg
del C:\Users\clive\AppData\Local\Temp\Garmin\Apps\%1PR~1.prg
echo -- building %1.prg --
"C:\Program Files (x86)\Java\jre1.8.0_121\bin\java" -Dfile.encoding=UTF-8 -Dapple.awt.UIElement=true -jar D:\sdk\connectIQsdk\bin\monkeybrains.jar -o bin\%1.prg -w -y D:\sdk\connectIQsdk\developer_key -z resources\drawables\drawables.xml;resources\fonts\fonts.xml;resources\strings\strings.xml -m manifest.xml source\*.mc -d round_watch_sim -r
echo -- running %1.prg --
monkeydo bin\%1.prg fenix3