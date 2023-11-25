#!/bin/bash

# Telegram bot variables
BOT_PATH=$(echo $0 | sed 's|/.[^/]*.sh$||;s|\./||')
. $BOT_PATH/telegram.bot.conf

DISK_WARN_THREESHOLD="80.00"
DISK_CRIT_THREESHOLD="90.00"

#get disks
disks_list=$(df | tail -n +2)

# get status of mountpoints
#pve-backups=$(mountpoint /mnt/datastore/pve-backups)
#pve-encrypted-backups=$(mountpoint /mnt/datastore/pve-encrypted-backups)

while IFS= read -r line
do
  #vm_info=$(echo $line | tr " " "\n")
  #id=$(echo $vm_info | sed 's| .*||')
  #name=$(echo $vm_info | sed 's|[^ ]* ||;s| .*||')
  #status=$(echo $vm_info | sed 's|[^ ]* [^ ]* ||')

  disk=$(echo $line | awk '{print $1}')
  disk_usage=$(echo $line | awk '{print $5}' | sed 's|%||')
  mountpoint=$(echo $line | awk '{print $6}')
  mount_name=$(echo $mountpoint | sed 's|.*/||')

  if [[ $(echo "$disk_usage > $DISK_WARN_THREESHOLD" | bc) -eq 1 ]]; then
    if [[ $(echo "$disk_usage > $DISK_CRIT_THREESHOLD" | bc) -eq 1 ]]; then
      $BOT_PATH/telegram.bot --bottoken $BOT_TOKEN --chatid $CHAT_ID --title "🚨 $mount_name:" --text "$disk_usage% disk usage for $mountpoint"
    else
      $BOT_PATH/telegram.bot --bottoken $BOT_TOKEN --chatid $CHAT_ID --title "⚠️ $mount_name:" --text "$disk_usage% disk usage for $mountpoint"
    fi
  fi

done <<< $disks_list
