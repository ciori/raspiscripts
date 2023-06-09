#!/bin/bash

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
    telegram_bot --text "vm $name \\($id\\) status 🚨: "$status
  fi
done <<< $vm_status
