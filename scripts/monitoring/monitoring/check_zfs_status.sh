#!/bin/bash

# Telegram bot variables
BOT_PATH=$(echo $0 | sed 's|/.[^/]*.sh$||;s|\./||')
. $BOT_PATH/telegram.bot.conf

zpool_out=$(zpool status)

# boolean flag to check errors
status=error
while IFS= read -r line
  do
  if [[ $line == *"state:"*"ONLINE"* ]]; then
    status=online
  fi
done <<< $zpool_out

if [[ $status == "online" ]]; then
  $BOT_PATH/telegram.bot --bottoken $BOT_TOKEN --chatid $CHAT_ID --title "✅ zfs status check:" --text "ONLINE"
else
  $BOT_PATH/telegram.bot --bottoken $BOT_TOKEN --chatid $CHAT_ID --title "🚨 zfs status check:" --text "ERROR\n_$zpool_out _"
fi
