#! /bin/bash

# Find current relative path of script
rel_path=$(echo $0 | sed 's|/.[^/]*.sh$||;s|\./||')

# Import helping functions
. $rel_path/functions.sh

# Cleanup function activation
trap cleanup EXIT ERR SIGINT

# Parameters Definition
user=$(whoami)
service_user=electrs
software="Electrum Server"
service=electrs
sig_min=1
backup_list=$(ls -p /home/$user/rust/electrs/target/release/ | grep -v /)
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
current_v=$(electrs --version | sed 's|.*v||')
latest_v=$(curl -sL https://api.github.com/repos/romanz/electrs/releases/latest | grep tag_name | sed 's|.*: "v||;s|",||')

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
  cd /home/$user/rust/electrs

  # Clean and update local source code to get latest release
  echo $(info)"Updating local repository" >> $log

  git clean -xfd --quiet
  if [[ $? != 0 ]]; then echo $(error)"git clean failure" >> $log; exit 1; fi
  echo $(info)"git clean succesfull" >> $log;

  git fetch --quiet
  if [[ $? != 0 ]]; then echo $(error)"git fetch failure" >> $log; exit 1; fi
  echo $(info)"git fetch succesfull" >> $log;

  electrs_git_latest=$(git tag | sort --version-sort | tail -n 1)
  if [[ $? != 0 ]]; then echo $(error)"git tag failure" >> $log; exit 1; fi
  echo $(info)"git tag succesfull" >> $log;

  # Signature verification
  echo $(info)"Starting signature verification" >> $log
  verify_sig_min "$({ $(git verify-tag $electrs_git_latest); } 2>&1)"

  # Checkout of Git Version
  git checkout $electrs_git_latest --quiet
  if [[ $? != 0 ]]; then echo $(error)"git checkout failure" >> $log; exit 1; fi
  echo $(info)"git checkout successfull" >> $log

  echo $(info)"Local repository updated" >> $log

  # Compile source code
  echo $(info)"Compiling source code" >> $log
  cargo clean -q
  build_out=$(cargo build -q --locked --release)
  if [[ $? != 0 ]]; then echo $(error)"Error building $software" >> $log; exit 1; fi
  echo $(info)"$software builded correctly" >> $log

  # Backup of current version
  create_backup $backup_path $backup_list
  perform_restore=true

  # Installation of new version
  echo $(info)"Starting installation of new $software version" >> $log
  sudo install -m 0755 -o root -g root -t /usr/local/bin ./target/release/electrs

  # Installation check
  current_v=$(electrs --version | sed 's|.*v||')
  check_installation $current_v
  if [[ $? == 0 ]]; then update_succesfull=1; else exit 1; fi

  # Backup deletion
  perform_restore=false
  delete_backup $backup_path $backup_list
fi
