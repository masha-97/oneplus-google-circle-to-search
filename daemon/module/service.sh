#!/system/bin/sh

MODDIR=${0%/*}
LOG_FILE="$MODDIR/daemon.log"

chmod 0755 "$MODDIR/bin/contextual-sidekey"
"$MODDIR/bin/contextual-sidekey" >> "$LOG_FILE" 2>&1 &
