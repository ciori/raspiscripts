#!/bin/bash

# Telegram bot variables
BOT_PATH=$(echo $0 | sed 's|/.[^/]*.sh$||;s|\./||')
. $BOT_PATH/telegram.bot.conf

CPU_THREESHOLD="95.00"
MEM_THREESHOLD="90.00"

# consider as start time current time minus double the sysstat writing frequence to account for worst case
start_time=$(date +%H:%M:%S --date '-20 min')

# check cpu stats
cpu_stats=$(sar -u -s $start_time)

while IFS= read -r line
  do
    if [[ $line == *"Average"* ]]; then
      cpu_idle=$(echo $line | sed 's|.* ||')
      cpu_usage=$(echo "100 - $cpu_idle" | bc)
      if [[ $(echo "$cpu_usage > $CPU_THREESHOLD" | bc) -eq 1 ]]; then
        $BOT_PATH/telegram.bot --bottoken $BOT_TOKEN --chatid $CHAT_ID --title "🚨 $(hostname):" --text "CPU usage at $cpu_usage%"
      fi
    fi
done <<< $cpu_stats

mem_stats=$(sar -r -s $start_time)

while IFS= read -r line
  do
    if [[ $line == *"Average"* ]]; then
      mem_usage=$(echo $line | sed 's|[^ ]* [^ ]* [^ ]* [^ ]* [^ ]* [^ ]* [^ ]* [^ ]* ||;s| .*||')
      if [[ $(echo "$mem_usage > $MEM_THREESHOLD" | bc) -eq 1 ]]; then
        $BOT_PATH/telegram.bot --bottoken $BOT_TOKEN --chatid $CHAT_ID --title "🚨 $(hostname):" --text "Memory usage at $mem_usage%"
      fi
    fi
done <<< $mem_stats
