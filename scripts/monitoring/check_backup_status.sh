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
  # extracts timestamp
  hextimestamp=$(echo $line | sed 's|[^:]*:[^:]*:[^:]*:[^:]*:||;s|:.*||')
  utc_timestamp=$(echo "ibase=16; $hextimestamp" | bc)
  timestamp=$(date -d @$utc_timestamp "+%F %T")

  # check if backup ended in the last lookback_seconds since current timestamp
  if [[ $(($utc_timestamp+$lookback_seconds)) > $curr_timestamp ]]
  then
    # get task log
    task_log=$(cat $(find /var/log/pve/tasks -name *$hextimestamp*))

    # parse the log and send notification for each backup
    # track current line and start/end indexes of each backup in the task log
    curr_line=0
    backup_start=0
    backup_end=0
    while IFS= read -r line
      do
      # get vm id and starting index
      if [[ $line == *"Starting Backup of VM"* ]]
      then
        backup_start=$curr_line
        vm=$(echo $line | sed 's|.*Starting Backup of VM||;s| (qemu)||')
      # send ok notification (end index is not necessary because log is not sent on successfull backup)
      elif [[ $line == *"Backup finished at "* ]]
      then
        send "vm$vm : backup task finished at $(echo $line | sed 's|.*Backup finished at ||')"
      # get end index and send error notification
      elif [[ $line == *"Failed at "* ]]
      then
        backup_end=$curr_line
        curr_line2=0
        task_err_log=$'\n'"Error Log:"
        # extract log for backup task from backup job log using start/end indexes
        while IFS= read -r line2
        do
          if (( $curr_line2 >= $backup_start )) && (( $curr_line2 <= $backup_end ))
          then
            task_err_log="$task_err_log"$'\n'"$line2"
          fi
          curr_line2=$(($curr_line2 + 1))
        done <<< $task_log
        send "vm$vm : backup task failed at $(echo $line | sed 's|.*Failed at ||')$task_err_log"
      fi
      curr_line=$(($curr_line + 1))
    done <<< $task_log
  fi
done <<< $backup_tasks_out
