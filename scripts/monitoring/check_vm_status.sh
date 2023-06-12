#!/bin/bash

# Telegram bot variables
BOT_PATH=$(echo $0 | sed 's|/.[^/]*.sh$||;s|\./||')
. $BOT_PATH/telegram.bot.conf

# get status of all vm
vm_status=$(qm list | grep -v VMID | sed 's| [ ]*| |g;s| ||;s| [^ ]* [^ ]* [^ ]* *$||')

while IFS= read -r line
do
  vm_info=$(echo $line | tr " " "\n")
  id=$(echo $vm_info | sed 's| .*||')
  name=$(echo $vm_info | sed 's|[^ ]* ||;s| .*||')
  status=$(echo $vm_info | sed 's|[^ ]* [^ ]* ||')

  if [ $status != "running" ]
  then
    $BOT_PATH/telegram.bot --bottoken $BOT_TOKEN --chatid $CHAT_ID --title "vm $name \\($id\\) status 🚨:" --text $status
  fi
done <<< $vm_status
