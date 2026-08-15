#!/system/bin/sh

PID_FILE=/data/local/tmp/contextual-sidekey.pid
LOCK_FILE=/data/local/tmp/contextual-sidekey.lock

if [ -f "$PID_FILE" ]; then
    PID=$(cat "$PID_FILE" 2>/dev/null)
    case "$PID" in
        ''|*[!0-9]*) ;;
        *) kill "$PID" 2>/dev/null ;;
    esac
fi

toybox rm -f "$PID_FILE" "$LOCK_FILE"
