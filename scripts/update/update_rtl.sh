#! /bin/bash

# Find current relative path of script
rel_path=$(echo $0 | sed 's|/.[^/]*.sh$||;s|\./||')

# Import functions
. $rel_path/utils.sh
. $rel_path/utils_update.sh

# Activate cleanup function
trap cleanup EXIT ERR SIGINT

# Parameters Definition
user=$(whoami)
service_user=rtl
software="Ride the Lightning"
service=rtl
sig_min=1
backup_list=RTL
backup_path=/home/rtl
update_attempt=false
perform_restore=false
update_succesfull=false
# Check if optional arguments are valid
parse_args $@

# Create log directory if not exists and new log file
init_log rtl

echo $(info)"Checking $software" >> $log

# Get current version and latest release
current_v=$(sudo su - $service_user -c "cd RTL && npm ls 2>/dev/null | grep rtl" | sed 's|rtl@||;s| /.*||')
latest_v=$(curl -sL https://api.github.com/repos/Ride-The-Lightning/RTL/releases/latest | grep tag_name | sed 's|.*: "v||;s|",||')

echo $(info)"$software current version:" $current_v >> $log
echo $(info)"$software latest available release:" $latest_v >> $log

get_common_prefix $current_v $latest_v

# Compare versions
if [[ $current_v == $common_prefix ]] || [[ $latest_v == $common_prefix ]]; then
  echo $(info)"Version matching, nothing to do" >> $log
  exit 0
else
  echo $(outl)"Version mismatch, starting update process" >> $log
  update_attempt=true

  # Stopping service
  stop_service $service

  # Backup of current version
  create_backup $backup_path $backup_list
  perform_restore=true

  # Clean and update local source code to get latest release
  echo $(info)"Updating local repository" >> $log

  sudo su - $service_user -c "cd RTL && git fetch --quiet"
  if [[ $? != 0 ]]; then echo $(error)"Error on git fetch command" >> $log; exit 1; fi
  echo $(info)"git fetch succesfull" >> $log;

  sudo su - $service_user -c "cd RTL && git reset --hard --quiet"
  if [[ $? != 0 ]]; then echo $(error)"Error on git reset command" >> $log; exit 1; fi
  echo $(info)"git reset succesfull" >> $log;

  latest_v=$(sudo su - $service_user -c "cd RTL && git tag | sort --version-sort | tail -n 1")
  if [[ $? != 0 ]]; then echo $(error)"Error on git tag command" >> $log; exit 1; fi
  echo $(info)"git tag succesfull" >> $log;

  # Checkout of Git Version
  sudo su - $service_user -c "cd btc-rpc-explorer && git checkout v$latest_v --quiet"
  if [[ $? != 0 ]]; then echo $(error)"git checkout failure" >> $log; exit 1; fi
  echo $(info)"git checkout succesfull" >> $log

  echo $(outl)"Local repository updated" >> $log

  # Installation of new version
  echo $(info)"Starting installation of new $software version" >> $log
  sudo su - $service_user -c "cd RTL && npm install --silent --omit=dev --legacy-peer-deps"
  
  # Installation check
  current_v=$(sudo su - $service_user -c "cd RTL && npm ls 2>/dev/null | grep rtl" | sed 's|rtl@||;s| /.*||')
  check_installation $current_v
  if [[ $? == 0 ]]; then update_succesfull=1; else exit 1; fi
  
  # Backup deletion
  perform_restore=false
  delete_backup $backup_path $backup_list
fi
