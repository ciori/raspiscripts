#!/bin/bash

# Telegram bot variables
BOT_PATH=$(echo $0 | sed 's|/.[^/]*.sh$||;s|\./||')
. $BOT_PATH/telegram.bot.conf

# current timestamp
curr_timestamp=$(date +%s)
# seconds to look back in time to check the timestamp of completed tasks of backups (currently 1 hour since the script is scheduled each hour)
lookback_seconds=$((1*60*60))

backup_tasks_out=$(cat /var/log/pve/tasks/index | grep vzdump)
# format of each line is:
# UPID:$node:$pid:$pstart:$starttime:$dtype:$id:$user

while IFS= read -r line
  do
  # extracts start and end timestamps of task (start is used as ID by proxmox, end is used to check if the task finished in the last lookback_seconds)
  hextimestamp_start=$(echo $line | sed 's|[^:]*:[^:]*:[^:]*:[^:]*:||;s|:.*||')
  hextimestamp_end=$(echo $line | sed 's|.*: ||;s| .*||')
  utc_timestamp_end=$(echo "ibase=16; $hextimestamp_end" | bc)

  # check if backup task ended in the last lookback_seconds since current timestamp
  if [[ $(($utc_timestamp_end+$lookback_seconds)) > $curr_timestamp ]]
  then
    # get task log using start timestamp
    task_log=$(cat $(find /var/log/pve/tasks -name *$hextimestamp_start*))

    # parse the log and send notification for each backup
    # track current line and start/end indexes of each backup in the task log
    curr_line=0
    backup_start=0
    backup_end=0
    while IFS= read -r line
      do
      if [[ $line == *"starting new backup job"*"--storage"* ]]
      then
        datastore=$(echo $line | sed 's|.*--storage ||;s| .*||')
      fi
      # get vm id and starting index
      if [[ $line == *"Starting Backup of VM"* ]]
      then
        backup_start=$curr_line
        vm=$(echo $line | sed 's|.*Starting Backup of VM||;s| (qemu)||;s|(|\\(|;s|)|\\)|')
      # send ok notification (end index is not necessary because log is not sent on successfull backup)
      elif [[ $line == *"Backup finished at "* ]]
      then
        $BOT_PATH/telegram.bot --bottoken $BOT_TOKEN --chatid $CHAT_ID --title "✅ vm$vm \\[ $datastore \\]:" --text "backup task finished at $(echo $line | sed 's|.*Backup finished at ||')"
      # get end index and send error notification
      elif [[ $line == *"Failed at "* ]]
      then
        backup_end=$curr_line
        curr_line2=0
	task_err_log=""
        # extract log for backup task from backup job log using start/end indexes
        while IFS= read -r line2
        do
          if (( $curr_line2 >= $backup_start )) && (( $curr_line2 <= $backup_end ))
          then
            task_err_log="$task_err_log"$(echo '\n'"$line2" | sed 's|(|\\(|;s|)|\\)|')
          fi
          curr_line2=$(($curr_line2 + 1))
        done <<< $task_log
	$BOT_PATH/telegram.bot --bottoken $BOT_TOKEN --chatid $CHAT_ID --title "🚨 vm$vm \\[ $datastore \\]:" --text "backup task failed at $(echo $line | sed 's|.*Failed at ||')\n*Error Log:*_$task_err_log _"
      fi
      curr_line=$(($curr_line + 1))
    done <<< $task_log
  fi
done <<< $backup_tasks_out
