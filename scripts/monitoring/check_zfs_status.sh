#!/bin/bash

zpool_out=$(zpool status)

# boolean flag to check errors
status=error
while IFS= read -r line
  do
  if [[ $line == *"state:"*"ONLINE"* ]]
  then
    status=online
  fi
done <<< $zpool_out

if [[ $status != "online" ]]
then
  telegram_bot --title "✅ zfs status check:" --text "ONLINE"
else
  telegram_bot --title "🚨 zfs status check:" --text "ERROR\n_$zpool_out _"
fi
