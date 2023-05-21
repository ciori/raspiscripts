#!/bin/bash
# compute path and import send message function
path=$(echo $0 | sed 's|/.[^/]*.sh$||;s|\./||')
. $path/send_message.sh

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

if [[ $status == "online" ]]
then
  send "zfs status check: ONLINE"
else
  send $'zfs status check: ERROR\n'"$zpool_out"
fi
