#! /bin/bash

# Find current relative path of script
rel_path=$(echo $0 | sed 's|/.[^/]*.sh$||;s|\./||')

# Import functions
. $rel_path/utils.sh
. $rel_path/utils_update.sh

# Cleanup function activation
trap cleanup EXIT ERR SIGINT

# Parameters Definition
user=$(whoami)
service_user=bitcoind
software="Bitcoin Core"
service=bitcoind
sig_min=5
sys_arc=x86_64
backup_list=$(ls -p /tmp/bitcoin-$latest_v/bin/ | grep -v /)
backup_path=/usr/local/bin
update_attempt=false
perform_restore=false
update_succesfull=false
# Check if optional arguments are valid
parse_args $@

# Create log directory if not exists and new log file
init_log bitcoin_core

echo $(info)"Checking $software" >> $log

# Get current version and latest release
current_v=$(bitcoind --version | grep version | sed 's|.*v||')
latest_v=$(curl -sL https://api.github.com/repos/bitcoin/bitcoin/releases/latest | grep tag_name | sed 's|.*: "v||;s|",||')

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

  # Clean any previously downloaded files and extracted folders
  echo $(info)"Cleanup of previously downloaded files and extracted folders" >> $log

  delete bitcoin-$latest_v-$sys_arc-linux-gnu.tar.gz
  delete SHA256SUMS
  delete SHA256SUMS.asc
  delete bitcoin-$latest_v/

  echo $(info)"Cleanup succesfull" >> $log

  # File download
  echo $(info)"Starting files download" >> $log

  download_file https://bitcoincore.org/bin/bitcoin-core-$latest_v/bitcoin-$latest_v-$sys_arc-linux-gnu.tar.gz
  download_file https://bitcoincore.org/bin/bitcoin-core-$latest_v/SHA256SUMS
  download_file https://bitcoincore.org/bin/bitcoin-core-$latest_v/SHA256SUMS.asc

  echo $(info)"Files download succesfull" >> $log

  # Checksum verification
  verify_checksum SHA256SUMS

  # Signature verification
  echo $(info)"Starting signature verification" >> $log
  verify_sig_min "$({ sig_ver_stdout=$(gpg --verify SHA256SUMS.asc); } 2>&1)"

  # Extraction of tar file
  echo $(info)"Starting extraction of tar file" >> $log
  tar -xf bitcoin-$latest_v-$sys_arc-linux-gnu.tar.gz
  if [[ $? != 0 ]]; then echo $(error)"Tar extraction failure" >> $log; exit 1; fi
  echo $(info)"Tar extraction succesfull" >> $log

  # Backup of current version
  create_backup $backup_path $backup_list
  perform_restore=true

  # Installation of new version
  echo $(info)"Starting installation of new $software version" >> $log
  sudo install -m 0755 -o root -g root -t /usr/local/bin bitcoin-$latest_v/bin/*
  
  # Installation check
  current_v=$(bitcoind --version | grep version | sed 's|.*v||')
  check_installation $current_v
  if [[ $? == 0 ]]; then update_succesfull=true; else exit 1; fi
  
  # Backup deletion
  perform_restore=false
  delete_backup $backup_path $backup_list
fi
