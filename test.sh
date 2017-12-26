monkeyc -o bin/late.prg -y ../developer_key.der -z resources/drawables/drawables.xml:resources/fonts/fonts.xml:resources/strings/strings.xml:resources-spa/strings/strings.xml:resources/settings/settings.xml:resources/settings/properties.xml -m manifest.xml source/*.mc -d fenix3_hr
connectiq
monkeydo bin/late.prg fenix3_hr
