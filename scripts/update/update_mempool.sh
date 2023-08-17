#! /bin/bash

# Show usage function
function show_usage() {
  printf "Usage: $0 [optional parameter(s)]\n"
  printf "\n"
  printf "Options:\n"
  printf " -u | --service-user\tuser of mempool service [$service_user]\n"
  printf " -d | --log-dir\t\tpath to save logs [$log_dir]\n"
  printf " -h | --help\t\tshow usage\n"

  return 0
}

# Cleanup function
function cleanup {
  echo $(outl)"Update Aborted" >> $log
  echo $(outl)"Restarting mempool service" >> $log
  sudo systemctl start mempool
}

# Find current location of script file to construct default log folder
rel_path=$(echo $0 | sed 's|/.[^/]*.sh$||;s|\./||')
abs_path=$(pwd)
if [ $abs_path == "/" ]
then
  abs_path="/$rel_path"
else
  abs_path=$(pwd)"/$rel_path"
fi

# Import helping functions
. $abs_path/functions.sh

# Parameters Definition
user=$(whoami)
service_user="mempool"
log_dir=$abs_path"/logs"
mempool_update_ok=0

# Check if optional arguments are valid
while [ ! -z "$1" ];
do
  if [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
    show_usage
    exit 0
  elif [[ "$1" == "-u" ]] || [[ "$1" == "--service-user" ]]; then
    service_user=$2
    if [[ -z $service_user ]]; then echo "No values provided for $1"; exit 1; fi
    id $service_user > /dev/null 2>&1
    if [[ $? != 0 ]]; then echo "User $service_user does not exists"; exit 1; fi
    shift
  elif [[ "$1" == "-d" ]] || [[ "$1" == "--log-dir" ]]; then
    log_dir=$2
    if [[ -z $log_dir ]]; then echo "No values provided for $1"; exit 1; fi
    shift
  else
    echo "Invalid argument $1"
    show_usage
    exit 1
  fi
  shift
done

# Activate cleanup function
trap cleanup ERR

# Create log directory
sudo mkdir -p $log_dir
if [[ $? != 0 ]]; then echo "Cannot create log directory $log_dir" >> $log; exit 1; fi
log=$log_dir/update_mempool_$(date +"%Y%m%d_T_%H%M%S").log

echo $(outl)"Checking Mempool Explorer" >> $log

# Checking version and latest release
mempool_v=$(cat /var/www/mempool/browser/resources/config.js | grep PACKAGE_JSON_VERSION | sed 's|.* = .||;s|.\;||;s|[\.00*]*$||')
echo $(outl)"Mempool Explorer current version:" $electrum_v >> $log
mempool_latest=$(curl -sL https://api.github.com/repos/mempool/mempool/releases/latest | grep tag_name | sed 's|.*: "v||;s|",||;s|[\.00*]*$||')
echo $(outl)"Mempool Explorer latest available release:" $electrum_latest >> $log

# Compare versions
if [[ "$mempool_v" > "$mempool_latest" ]] || [[ "$mempool_v" < "$mempool_latest" ]]
then
  echo $(outl)"Version mismatch, starting update process" >> $log

  # Stopping service
  echo $(outl)"Stopping mempool service" >> $log
  sudo systemctl stop mempool
  mempool_status=$(systemctl is-active mempool.service)
  if [ "$mempool_status" == "active" ]; then echo $(errl)"Impossible to stop mempool service, service is $mempool_status" >> $log; exit 1; fi
  echo $(outl)"Service mempool stopped, service is $mempool_status" >> $log

  # Clean and update local source code to get latest release
  echo $(outl)"Updating local repository" >> $log
  sudo su - $service_user -c "cd mempool && git fetch --quiet"
  if [[ $? != 0 ]]; then echo $(errl)"Error on git fetch command" >> $log; exit 1; fi
  sudo su - $service_user -c "cd mempool && git reset --hard HEAD --quiet"
  if [[ $? != 0 ]]; then echo $(errl)"Error on git reset command" >> $log; exit 1; fi
  mempool_git_latest=$(sudo su - $service_user -c "cd mempool && git tag | sort --version-sort | tail -n 1")
  if [[ $? != 0 ]]; then echo $(errl)"Error on git tag command" >> $log; exit 1; fi
  git_checkout_out=$(sudo su - $service_user -c "cd mempool && git checkout $mempool_git_latest --quiet")
  if [[ $? != 0 ]]; then echo $(errl)"Error during git checkout" >> $log; exit 1; fi
  echo $(outl)"Local repository updated" >> $log

  # Building backend
  echo $(outl)"Building Backend" >> $log
  sudo su - $service_user -c "cd mempool/backend && npm install --silent --prod"
  if [[ $? != 0 ]]; then echo $(errl)"Error during backend npm installation" >> $log; exit 1; fi
  sudo su - $service_user -c "cd mempool/backend && npm run --silent build"
  if [[ $? != 0 ]]; then echo $(errl)"Error during backend npm build" >> $log; exit 1; fi
  echo $(outl)"Backend builded" >> $log

  # Building frontend
  echo $(outl)"Building Frontend" >> $log
  sudo su - $service_user -c "cd mempool/frontend && npm install --silent --prod"
  if [[ $? != 0 ]]; then echo $(errl)"Error during backend npm installation" >> $log; exit 1; fi
  sudo su - $service_user -c "cd mempool/frontend && npm run --silent build"
  if [[ $? != 0 ]]; then echo $(errl)"Error during backend npm build" >> $log; exit 1; fi
  echo $(outl)"Frontend builded" >> $log

  echo $(outl)"Update of Mempool Explorer with new builded version" >> $log
  sudo rsync -av --delete /home/mempool/mempool/frontend/dist/mempool/ /var/www/mempool/
  if [[ $? != 0 ]]; then echo $(errl)"Error during rsync of new version" >> $log; exit 1; fi
  mempool_v=$(cat /var/www/mempool/browser/resources/config.js | grep PACKAGE_JSON_VERSION | sed 's|.* = .||;s|.\;||;s|[\.00*]*$||')
  echo $(outl)"Mempool updated succesfully, current version: $mempool_v" >> $log

  # Service restart
  echo $(outl)"Starting service mempool" >> $log
  sudo systemctl start mempool
  mempool_status=$(systemctl is-active mempool.service)
  if [ "$mempool_status" == "active" ]
  then
    echo $(outl)"Service mempool started correctly, service is now running" >> $log
  else
    echo $(errl)"Service mempool start failed, service status is $mempool_status" >> $log
  fi

  echo $(outl)"Reloading service nginx" >> $log
  sudo systemctl reload nginx
  nginx_status=$(systemctl is-active nginx.service)
  if [ "$nginx_status" == "active" ]
  then
    echo $(outl)"Service nginx restarted correctly, service is now running" >> $log
  else
    echo $(errl)"Service nginx restart failed, service status is $nginx_status" >> $log
  fi

else
  echo $(outl)"Version matching, nothing to do" >> $log
fi
