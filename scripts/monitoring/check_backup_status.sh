#!/bin/bash
# compute path and import send message function
path=$(echo $0 | sed 's|/.[^/]*.sh$||;s|\./||')
. $path/send_message.sh

# current timestamp
curr_timestamp=$(date +%s)
# seconds to look back in time to check the timestamp of completed tasks of backups (currently 1 hour since the script is scheduled each hour)
lookback_seconds=$((1*60*60))

backup_tasks_out=$(cat /var/log/pve/tasks/index | grep vzdump)
# format of each line is:
# UPID:$node:$pid:$pstart:$starttime:$dtype:$id:$user

while IFS= read -r line
  do
  # extracts timestamp and vm id
  hextimestamp=$(echo $line | sed 's|[^:]*:[^:]*:[^:]*:[^:]*:||;s|:.*||')
  vm=$(echo $line | sed 's|[^:]*:[^:]*:[^:]*:[^:]*:[^:]*:[^:]*:||;s|:.*||')
  utc_timestamp=$(echo "ibase=16; $hextimestamp" | bc)
  timestamp=$(date -d @$utc_timestamp "+%F %T")

  # check if backup ended in the last lookback_seconds since current timestamp
  if [[ $(($utc_timestamp+$lookback_seconds)) > $curr_timestamp ]]
  then
    if [[ $line = *"OK" ]]
    then
      send "vm$vm - $timestamp: backup task completed succesfully"
    else
      send "vm$vm - $timestamp: backup task ended with error: $(echo $line | sed 's|[^:]*:[^:]*:[^:]*:[^:]*:[^:]*:[^:]*:[^:]*:[^:]*: ||;s|[^ ]* ||')"
    fi
  fi
done <<< $backup_tasks_out
