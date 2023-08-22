#! /bin/bash

# Find current relative path of script
rel_path=$(echo $0 | sed 's|/.[^/]*.sh$||;s|\./||')

# Import helping functions
. $rel_path/functions.sh

# Activate cleanup function
trap cleanup EXIT ERR SIGINT

# Parameters Definition
user=$(whoami)
service_user=lnd
software="Lightning Network Daemon"
service=lnd
sig_min=1
sys_arc=amd64
backup_list=$(ls -p /tmplnd-linux-$sys_arc-v$latest_v/ | grep -v /) #necessary to get latest version first
backup_path=/usr/local/bin
update_attempt=false
perform_restore=false
update_succesfull=false
# Check if optional arguments are valid
parse_args $@

# Create log directory if not exists and new log file
init_log

echo $(info)"Checking $software" >> $log

# Get current version and latest release
current_v=$(lnd --version | grep version | sed 's|.*v||')
latest_v=$(curl -sL https://api.github.com/repos/lightningnetwork/lnd/releases/latest | grep tag_name | sed 's|.*: "v||;s|",||')
backup_list=$(ls -p lnd-linux-$sys_arc-v$latest_v/ | grep -v /)

echo $(info)"$software current version:" $current_v >> $log
echo $(info)"$software latest available release:" $latest_v >> $log

get_common_prefix $current_v $latest_v

# Compare versions
if [[ $current_v == $common_prefix ]] || [[ $latest_v == $common_prefix ]]; then
  echo $(info)"Version matching, nothing to do" >> $log
  exit 0
else
  echo $(info)"Version mismatch, starting update process" >> $log
  update_attempt=true
  cd /tmp

  # Stopping service
  stop_service $service

  # Clean any previously downloaded files and extracted folders
  echo $(info)"Cleanup of previously downloaded files and extracted folders" >> $log

  delete lnd-linux-$sys_arc-v$latest_v.tar.gz
  delete manifest-v$latest_v.txt
  delete manifest-roasbeef-v$latest_v.sig
  delete lnd-linux-$sys_arc-v$latest_v/

  echo $(info)"Cleanup succesfull" >> $log
  
  # File download
  echo $(info)"Starting files download" >> $log

  download_file https://github.com/lightningnetwork/lnd/releases/download/v$latest_v/lnd-linux-$sys_arc-v$latest_v.tar.gz
  download_file https://github.com/lightningnetwork/lnd/releases/download/v$latest_v/manifest-v$latest_v.txt
  download_file https://github.com/lightningnetwork/lnd/releases/download/v$latest_v/manifest-roasbeef-v$latest_v.sig

  echo $(info)"Files download succesfull" >> $log

  # Checksum verification
  verify_checksum manifest-v$latest_v.txt

  # Signature verification
  echo $(info)"Starting signature verification" >> $log
  verify_sig_min "$({ sig_ver_stdout=$(gpg --verify manifest-roasbeef-v$latest_v.sig manifest-v$latest_v.txt); } 2>&1)"

  # Extraction of tar file
  echo $(info)"Starting extraction of tar file" >> $log
  tar -xf lnd-linux-$sys_arc-v$latest_v.tar.gz
  if [[ $? != 0 ]]; then echo $(error)"Tar extraction failure" >> $log; exit 1; fi
  echo $(info)"Tar extraction succesfull" >> $log

  # Backup of current version
  create_backup $backup_path $backup_list
  perform_restore=true

  # Installation of new version
  echo $(info)"Starting installation of new $software version" >> $log
  sudo install -m 0755 -o root -g root -t /usr/local/bin lnd-linux-$sys_arc-v$latest_v/*
  
  # Installation check
  current_v=$(lnd --version | grep version | sed 's|.*v||')
  check_installation $current_v
  if [[ $? == 0 ]]; then update_succesfull=1; else exit 1; fi

  # Backup deletion
  perform_restore=false
  delete_backup $backup_path $backup_list
fi
