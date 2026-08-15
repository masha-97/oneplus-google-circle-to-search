#!/system/bin/sh

MODEL=$(getprop ro.product.model)
DEVICE=$(getprop ro.product.device)
SDK=$(getprop ro.build.version.sdk)
ABI=$(getprop ro.product.cpu.abi)
BUILD=$(getprop ro.build.display.id)

[ "$MODEL" = "PLK110" ] || abort "Unsupported model: $MODEL"
[ "$DEVICE" = "OP60FFL1" ] || abort "Unsupported device: $DEVICE"
[ "$SDK" = "36" ] || abort "Unsupported SDK: $SDK"
[ "$ABI" = "arm64-v8a" ] || abort "Unsupported ABI: $ABI"
[ "$BUILD" = "PLK110_16.0.9.400(CN01)" ] || abort "Unsupported build: $BUILD"

ui_print "- PLK110 Contextual Search Side Key"
ui_print "- Non-exclusive /dev/input/event0 listener"
