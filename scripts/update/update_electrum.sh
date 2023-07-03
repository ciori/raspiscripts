#! /bin/bash

function show_usage() {
  printf "Usage: $0 [optional parameter(s)]\n"
  printf "\n"
  printf "Options:\n"
  printf " -d | --log_dir\tpath to save logs [/home/$(whoami)/]\n"
  printf " -h | --help\t\\ttshow usage\n"

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
log_dir=$abs_path"/logs"
electrum_update_ok=0

# Check if optional arguments are valid
while [ ! -z "$1" ];
do
  if [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
    show_usage
  elif [[ "$1" == "-d" ]] || [[ "$1" == "--log_dir" ]]; then
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
if [ ! $? ]
then
  echo "Cannot create log directory $log_dir" >> $log
  exit 1
fi

log=$log_dir/update_electrum_$(date +"%Y%m%d_T_%H%M%S").log

echo $(outl)"Checking Electrum Server" >> $log

# Checking version and latest release
electrum_v=$(electrs --version | sed 's|.*v||;s|[\.00*]*$||')
echo $(outl)"Electrum Server current version:" $electrum_v >> $log
electrum_latest=$(curl -sL https://api.github.com/repos/romanz/electrs/releases/latest | grep tag_name | sed 's|.*: "v||;s|",||;s|[\.00*]*$||')
echo $(outl)"Electrum Server latest available release:" $electrum_latest >> $log
# Compare versions
if [[ "$electrum_v" > "$electrum_latest" ]] || [[ "$electrum_v" < "$electrum_latest" ]]
then
  echo $(outl)"Version mismatch, starting update process" >> $log

  # Clean and update local source code to get latest release
  echo $(outl)"Updating local repository" >> $log
  cd /home/$user/rust/electrs
  git clean -xfd
  git fetch
  electrum_git_latest=$(git tag | sort --version-sort | tail -n 1)

  # Signature verification
  echo $(outl)"Starting signature verification" >> $log
  sig_ver_out=$({ $(git verify-tag $electrum_git_latest); } 2>&1)

  # Parsing signature verification output
  parse_sig_log "$sig_ver_out"
  sig_count=$?

  if [ $sig_count == 1 ]
  then
    echo $(outl)$sig_count" signature found" >> $log
  else
    echo $(outl)$sig_count" signatures found" >> $log
  fi

  # Signature number check
  if [[ $sig_count -lt $sig_min ]]
  then
    echo $(errl)"Signature verification failed, update aborted" >> $log
    exit 1
  else
    echo $(outl)"Signature verified" >> $log
  fi

  # Checkout of Git Version
  git_checkout_out=$({ $(git checkout $electrum_git_latest); } 2>&1)

  if [[ $git_checkout_out != *"HEAD is now at "* ]]
  then
    echo $(errl)"Error during git checkout, update aborted" >> $log
    exit 1
  else
    echo $(outl)"Git checkout completed" >> $log
  fi

  # Compile source code
  echo $(outl)"Compiling source code" >> $log
  cargo clean -q

  build_out=$(cargo build -q --locked --release)
  if [ $? ]
  then
    echo $(outl)"Electrum Server builded correctly" >> $log
  else
    echo $(errl)"Error building Electrum Server" >> $log
    exit 1
  fi

  # Installation of binaries
  echo $(outl)"Starting binaries installation" >> $log
  sudo cp /usr/local/bin/electrs /usr/local/bin/electrs-old
  if [ $? ]
  then
    echo $(outl)"Current Electrum Server backup created" >> $log
  else
    echo $(errl)"Error creating current Electrum Server backup" >> $log
    exit 1
  fi

  sudo install -m 0755 -o root -g root -t /usr/local/bin ./target/release/electrs

  echo $(outl)"Electrum Server current version:" $electrum_v >> $log
  electrum_latest=$(curl -sL https://api.github.com/repos/romanz/electrs/releases/latest | grep tag_name | sed 's|.*: "v||;s|",||;s|[\.00*]*$||')
  echo $(outl)"Electrum Server latest available release:" $electrum_latest >> $log

  electrum_v=$(electrs --version | grep version | sed 's|.* v||')
  common_prefix=$(printf "%s\n%s\n" "$electrum_v" "$electrum_latest" | sed -e 'N;s/^\(.*\).*\n\1.*$/\1/')
  if [ $electrum_v == $common_prefix ] || [ $electrum_latest == $common_prefix ]
  then
    electrum_updated=1
    echo $(outl)"Binaries installation ok, current Electrum Server version: $electrum_v" >> $log
  else
    echo $(errl)"Binaries installation error" >> $log
    exit 1
  fi

  # Service restart
  echo $(outl)"Restarting service electrs" >> $log
  sudo systemctl restart electrs
  electrum_status=$(sudo systemctl status electrs.service | grep Active | sed 's|.*Active:.*(||;s|).*||')
  if [ $electrum_status == "running" ]
  then
    echo $(outl)"Service electrs restarted correctly, service is now running" >> $log
  else
    echo $(errl)"Service electrs restart failed, service status is $electrum_status" >> $log
  fi
else
  echo $(outl)"Version matching, nothing to do" >> $log
fi
