# TODO grep devices parameters

ls ~/Library/Application\ Support/Garmin/ConnectIQ/Devices | cat | 

s/"resolution": [^:]+: (\d+)[^:]+: (\d+)
s/"memoryLimit":\s*(\d+)[^""]+"type":\s*"background"