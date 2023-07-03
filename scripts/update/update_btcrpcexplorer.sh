#! /bin/bash

function show_usage() {
  printf "Usage: $0 [optional parameter(s)]\n"
  printf "\n"
  printf "Options:\n"
  printf " -u | --service-user\tuser of btcrpcexplorer service [btcrpcexplorer]\n"
  printf " -d | --log-dir\t\tpath to save logs [/home/$(whoami)/]\n"
  printf " -h | --help\t\tshow usage\n"

  return 0
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
    if [[ -z $service_user ]]
    then
      echo "No values provided for $1"
      exit 1
    fi
    id $service_user > /dev/null 2>&1
    if [[ $? == 1 ]]
    then
      echo "User $service_user does not exists"
      exit 1
    fi
    shift
  elif [[ "$1" == "-d" ]] || [[ "$1" == "--log-dir" ]]; then
    log_dir=$2
    if [[ -z $log_dir ]]
    then
      echo "No values provided for $1"
      exit 1
    fi
    shift
  else
    echo "Invalid argument $1"
    show_usage
    exit 1
  fi
  shift
done

sudo mkdir -p $log_dir
if [[ $? == 1 ]]; then echo "Cannot create log directory $log_dir" >> $log; exit 1; fi

log=$log_dir/update_electrum_$(date +"%Y%m%d_T_%H%M%S").log

echo $(outl)"Checking BTC RPC Explorer" >> $log

# Checking version and latest release
explorer_v=$(sudo su - btcrpcexplorer -c "btc-rpc-explorer/bin/cli.js --version" | sed 's|.*v||;s|[\.00*]*$||')
echo $(outl)"BTC RPC Explorer current version:" $electrum_v >> $log
explorer_latest=$(curl -sL https://api.github.com/repos/janoside/btc-rpc-explorer/releases/latest | grep tag_name | sed 's|.*: "v||;s|",||;s|[\.00*]*$||')
echo $(outl)"BTC RPC Explorer latest available release:" $electrum_latest >> $log
# Compare versions
if [[ "$explorer_v" > "$explorer_latest" ]] || [[ "$explorer_v" < "$explorer_latest" ]]
then
  echo $(outl)"Version mismatch, starting update process" >> $log

  echo $(outl)"Stopping btcrpcexplorer service" >> $log
  sudo systemctl stop btcrpcexplorer
  explorer_status=$(sudo systemctl status btcrpcexplorer.service | grep Active | sed 's|.*Active:.*(||;s|).*||')
  if [ $explorer_status == "dead" ]
  then
    echo $(outl)"Service btcrpcexplorer stopped correctly" >> $log
  else
    echo $(errl)"Impossible to stop btcrpcexplorer service" >> $log
  fi

  # Clean and update local source code to get latest release
  echo $(outl)"Updating local repository" >> $log
  sudo su - $service_user -c "cd btc-rpc-explorer && git fetch --quiet"
  if [[ $? == 1 ]]; then echo $(errl)"Error on git fetch command" >> $log; exit 1; fi
  sudo su - $service_user -c "cd btc-rpc-explorer && git reset --hard HEAD --quiet"
  if [[ $? == 1 ]]; then echo $(errl)"Error on git reset command" >> $log; exit 1; fi
  explorer_git_latest=$(sudo su - $service_user -c "cd btc-rpc-explorer && git tag | sort --version-sort | tail -n 1")
  if [[ $? == 1 ]]; then echo $(errl)"Error on git tag command" >> $log; exit 1; fi
  git_checkout_out=$(sudo su - $service_user -c "cd btc-rpc-explorer && git checkout $explorer_git_latest --quiet")
  if [[ $? == 1 ]]
  then
    echo $(errl)"Error during git checkout, update aborted" >> $log
    exit 1
  else
    echo $(outl)"Git checkout completed" >> $log
  fi
  sudo su - $service_user -c "cd btc-rpc-explorer && npm install --quiet"
  echo $?
  sudo systemctl start btcrpcexplorer
else
  echo $(outl)"Version matching, nothing to do" >> $log
fi
