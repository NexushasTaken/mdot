#!/usr/bin/bash

dunstctl reload
dunstctl history-clear
notify-send "Title" "Hello, World"
notify-send "Reverse" "World, Hello"
notify-send -u low "Low" "Urgency Level"
notify-send -u normal "Normal" "Urgency Level"
notify-send -u critical "Critical" "Urgency Level"
notify-send -h "BOOLEAN:Here:true" "Critical" "Urgency Level"
notify-send "Downloading..." "Hello" -h int:value:40

