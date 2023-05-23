#!/bin/bash
# compute path and import send message function
path=$(echo $0 | sed 's|/.[^/]*.sh$||;s|\./||')
. $path/send_message.sh

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
    send "vm $name ($id) status: "$status
  fi
done <<< $vm_status
