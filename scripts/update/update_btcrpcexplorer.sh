#! /bin/bash

# Show usage function
function show_usage() {
  printf "Usage: $0 [optional parameter(s)]\n"
  printf "\n"
  printf "Options:\n"
  printf " -u | --service-user\tuser of btcrpcexplorer service [$service_user]\n"
  printf " -d | --log-dir\t\tpath to save logs [$log_dir]\n"
  printf " -h | --help\t\tshow usage\n"

  return 0
}

# Cleanup function
function cleanup {
  echo $(outl)"Update Aborted" >> $log
  echo $(outl)"Restarting btcrpcexplorer service" >> $log
  sudo systemctl start btcrpcexplorer
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
service_user="btcrpcexplorer"
log_dir=$abs_path"/logs"
btcrpcexplorer_update_ok=0

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
    if [[ ! $? == 0 ]]; then echo "User $service_user does not exists"; exit 1; fi
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
log=$log_dir/update_btcrpcexplorer_$(date +"%Y%m%d_T_%H%M%S").log

echo $(outl)"Checking BTC RPC Explorer" >> $log

# Checking version and latest release
explorer_v=$(sudo su - $service_user -c "btc-rpc-explorer/bin/cli.js --version" | sed 's|.*v||;s|[\.00*]*$||')
echo $(outl)"BTC RPC Explorer current version:" $explorer_v >> $log
explorer_latest=$(curl -sL https://api.github.com/repos/janoside/btc-rpc-explorer/releases/latest | grep tag_name | sed 's|.*: "v||;s|",||;s|[\.00*]*$||')
echo $(outl)"BTC RPC Explorer latest available release:" $explorer_latest >> $log

# Compare versions
if [[ "$explorer_v" > "$explorer_latest" ]] || [[ "$explorer_v" < "$explorer_latest" ]]
then
  echo $(outl)"Version mismatch, starting update process" >> $log

  # Stopping service
  echo $(outl)"Stopping btcrpcexplorer service" >> $log
  sudo systemctl stop btcrpcexplorer
  explorer_status=$(systemctl is-active btcrpcexplorer.service)
  if [ "$explorer_status" == "active" ]; then echo $(errl)"Impossible to stop btcrpcexplorer service, service is $explorer_status" >> $log; exit 1; fi
  echo $(outl)"Service btcrpcexplorer stopped, service is $explorer_status" >> $log

  # Clean and update local source code to get latest release
  echo $(outl)"Updating local repository" >> $log
  sudo su - $service_user -c "cd btc-rpc-explorer && git fetch --quiet"
  if [[ $? != 0 ]]; then echo $(errl)"Error on git fetch command" >> $log; exit 1; fi
  sudo su - $service_user -c "cd btc-rpc-explorer && git reset --hard HEAD --quiet"
  if [[ $? != 0 ]]; then echo $(errl)"Error on git reset command" >> $log; exit 1; fi
  explorer_git_latest=$(sudo su - $service_user -c "cd btc-rpc-explorer && git tag | sort --version-sort | tail -n 1")
  if [[ $? != 0 ]]; then echo $(errl)"Error on git tag command" >> $log; exit 1; fi
  git_checkout_out=$(sudo su - $service_user -c "cd btc-rpc-explorer && git checkout $explorer_git_latest --quiet")
  if [[ $? != 0 ]]; then echo $(errl)"Error during git checkout" >> $log; exit 1; fi
  echo $(outl)"Local repository updated" >> $log

  echo $(outl)"Installing BTC RPC Explorer" >> $log
  sudo su - $service_user -c "cd btc-rpc-explorer && npm install --silent"
  if [[ $? != 0 ]]; then echo $(errl)"Error during npm installation" >> $log; exit 1; fi
  explorer_v=$(sudo su - $service_user -c "btc-rpc-explorer/bin/cli.js --version" | sed 's|.*v||')
  echo $(outl)"BTC RPC Explorer installed correctly, current version: $explorer_v" >> $log
  explorer_updated=1

  # Service restart
  echo $(outl)"Starting service btcrpcexplorer" >> $log
  sudo systemctl start btcrpcexplorer
  explorer_status=$(systemctl is-active btcrpcexplorer.service)
  if [ "$explorer_status" == "active" ]
  then
    echo $(outl)"Service btcrpcexplorer restarted correctly, service is now running" >> $log
  else
    echo $(errl)"Service btcrpcexplorer restart failed, service status is $explorer_status" >> $log
  fi

else
  echo $(outl)"Version matching, nothing to do" >> $log
fi
