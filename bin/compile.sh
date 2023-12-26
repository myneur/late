monkeyc -l 0 -r -o late.prg -y ../../developer_key.der -f ../monkey.jungle -d fenix6xpro
#monkeyc -r -o bin/late.prg -y ../developer_key.der -f monkey.jungle --unit-test -d d2bravo
sleep 2
#connectiq 
#monkeydo bin/late.prg fenix6 -t
