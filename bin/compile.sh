monkeyc -l 0 -r -o late.prg -y ../../developer_key.der -f ../monkey.jungle -d fenix6xpro
# --Eno-invalid-symbol # turns missing annotation error into warning # https://forums.garmin.com/developer/connect-iq/i/bug-reports/excludeannotations-stopped-in-new-sdks?service=https:%2f%2fforums.garmin.com%2fdeveloper%2fconnect-iq%2fi%2fbug-reports%2fexcludeannotations-stopped-in-new-sdks
#monkeyc -r -o bin/late.prg -y ../developer_key.der -f monkey.jungle --unit-test -d d2bravo
sleep 2
#connectiq 
#monkeydo bin/late.prg fenix6 -t
