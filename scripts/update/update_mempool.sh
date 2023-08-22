#! /bin/bash

# Find current relative path of script
rel_path=$(echo $0 | sed 's|/.[^/]*.sh$||;s|\./||')

# Import helping functions
. $rel_path/functions.sh

# Activate cleanup function
trap cleanup EXIT ERR SIGINT

# Parameters Definition
user=$(whoami)
service_user=mempool
software="Mempool Explorer"
service=mempool
sig_min=1
backup_list=mempool
backup_path=/var/www
update_attempt=false
perform_restore=false
update_succesfull=false
# Check if optional arguments are valid
parse_args $@

# Create log directory if not exists and new log file
init_log

echo $(info)"Checking $software" >> $log

# Get current version and latest release
current_v=$(cat /var/www/mempool/browser/resources/config.js | grep PACKAGE_JSON_VERSION | sed 's|.* = .||;s|.\;||')
latest_v=$(curl -sL https://api.github.com/repos/mempool/mempool/releases/latest | grep tag_name | sed 's|.*: "v||;s|",||')

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

  # Stopping service
  stop_service $service

  # Backup of current version
  create_backup $backup_path $backup_list
  perform_restore=true

  # Clean and update local source code to get latest release
  echo $(info)"Updating local repository" >> $log

  sudo su - $service_user -c "cd mempool && git fetch --quiet"
  if [[ $? != 0 ]]; then echo $(errl)"Error on git fetch command" >> $log; exit 1; fi
  echo $(info)"git fetch succesfull" >> $log;

  sudo su - $service_user -c "cd mempool && git reset --hard HEAD --quiet"
  if [[ $? != 0 ]]; then echo $(errl)"Error on git reset command" >> $log; exit 1; fi
  echo $(info)"git reset succesfull" >> $log;

  mempool_git_latest=$(sudo su - $service_user -c "cd mempool && git tag | sort --version-sort | tail -n 1")
  if [[ $? != 0 ]]; then echo $(errl)"Error on git tag command" >> $log; exit 1; fi
  echo $(info)"git tag succesfull" >> $log;

  # Checkout of Git Version
  sudo su - $service_user -c "cd mempool && git checkout $mempool_git_latest --quiet"
  if [[ $? != 0 ]]; then echo $(errl)"git checkout failure" >> $log; exit 1; fi
  echo $(info)"git checkout succesfull" >> $log

  echo $(info)"Local repository updated" >> $log

  # Building backend
  echo $(info)"Building Backend" >> $log
  sudo su - $service_user -c "cd mempool/backend && npm install --silent --prod"
  if [[ $? != 0 ]]; then echo $(error)"backend npm installation failure" >> $log; exit 1; fi
  sudo su - $service_user -c "cd mempool/backend && npm run --silent build"
  if [[ $? != 0 ]]; then echo $(error)"backend npm build failure" >> $log; exit 1; fi
  echo $(info)"Backend builded" >> $log

  # Building frontend
  echo $(info)"Building Frontend" >> $log
  sudo su - $service_user -c "cd mempool/frontend && npm install --silent --prod"
  if [[ $? != 0 ]]; then echo $(error)"backend npm installation failure" >> $log; exit 1; fi
  sudo su - $service_user -c "cd mempool/frontend && npm run --silent build"
  if [[ $? != 0 ]]; then echo $(error)"backend npm build failure" >> $log; exit 1; fi
  echo $(info)"Frontend builded" >> $log

  # Installation of new version
  echo $(info)"Starting installation of new Mempool version" >> $log
  sudo rsync -av --delete /home/$service_user/mempool/frontend/dist/mempool/ /var/www/mempool/

  # Installation check
  current_v=$(cat /var/www/mempool/browser/resources/config.js | grep PACKAGE_JSON_VERSION | sed 's|.* = .||;s|.\;||')
  check_installation $current_v
  if [[ $? == 0 ]]; then update_succesfull=1; else exit 1; fi

  # Backup deletion
  perform_restore=false
  delete_backup $backup_path $backup_list
fi
