#!/bin/bash

# Telegram bot variables
BOT_PATH=$(echo $0 | sed 's|/.[^/]*.sh$||;s|\./||')
. $BOT_PATH/telegram.bot.conf

# get status of all containers
ct_status=$(/usr/sbin/pct list | grep -v VMID | sed 's| [ ]*| |g')

while IFS= read -r line
do
  id=$(echo $line | sed 's| .*||')
  name=$(echo $line | sed 's|[^ ]* [^ ]* ||')
  status=$(echo $line | sed 's|[^ ]* ||;s| .*||')
  if [[ $status != "running" ]]; then
    $BOT_PATH/telegram.bot --bottoken $BOT_TOKEN --chatid $CHAT_ID --title "container $name \\($id\\) status 🚨:" --text $status
  fi
done <<< $ct_status
