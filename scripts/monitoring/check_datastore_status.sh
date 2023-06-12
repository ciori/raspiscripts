#!/bin/bash

# Telegram bot variables
BOT_PATH=$(echo $0 | sed 's|/.[^/]*.sh$||;s|\./||')
. $BOT_PATH/telegram.bot.conf

#get datastores
datastore_list=$(proxmox-backup-manager datastore list --output-format json-pretty)

# get status of mountpoints
#pve-backups=$(mountpoint /mnt/datastore/pve-backups)
#pve-encrypted-backups=$(mountpoint /mnt/datastore/pve-encrypted-backups)

while IFS= read -r line
do
  #vm_info=$(echo $line | tr " " "\n")
  #id=$(echo $vm_info | sed 's| .*||')
  #name=$(echo $vm_info | sed 's|[^ ]* ||;s| .*||')
  #status=$(echo $vm_info | sed 's|[^ ]* [^ ]* ||')

  if [[ $line == *"name"* ]]
  then
    datastore=$(echo $line | sed 's|.*"name": "||;s|",||')
  elif [[ $line == *"path"* ]]
  then
    if [[ $datastore != "" ]]
    then
      path=$(echo $line | sed 's|.*"path": "||;s|",||')
      is_mountpoint=$(mountpoint $path)
      if [[ $is_mountpoint != *"is a mountpoint"* ]]
      then
        $BOT_PATH/telegram.bot --bottoken $BOT_TOKEN --chatid $CHAT_ID --title "🚨 datastore $datastore status:" --text "not available, backups will fail"
      fi
    fi
  fi

done <<< $datastore_list
