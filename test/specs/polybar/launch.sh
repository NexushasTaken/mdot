#!/usr/bin/env bash

# Terminate already running bar instances
# If all your bars have ipc enabled, you can use 
polybar-msg cmd quit
# Otherwise you can use the nuclear option:
# killall -q polybar

# Launch bar1 and bar2
POLYBAR_LOG_FILE=/tmp/polybar.log
echo "---" | tee -a $POLYBAR_LOG_FILE $POLYBAR_LOG_FILE
polybar bar 2>&1 | tee -a $POLYBAR_LOG_FILE & disown

echo "Bars launched..."
