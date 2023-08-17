#! /bin/bash

# Show usage function
function show_usage() {
  printf "Usage: $0 [optional parameter(s)]\n"
  printf "\n"
  printf "Options:\n"
  printf " -s | --sig-min\tminimum number of valid signatures accepted [3]\n"
  printf " -a | --sys-arc\tsystem architecture, valid options: x86_64, aarch64, arm [x86_64]\n"
  printf " -d | --log-dir\tpath to save logs [$log_dir]\n"
  printf " -h | --help\tshow usage\n"

  return 0
}

# Cleanup function
function cleanup {
  echo $(outl)"Update Aborted" >> $log
  echo $(outl)"Restarting lnd service" >> $log
  sudo systemctl start lnd
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
sys_arc=amd64
sig_min=1
log_dir=$abs_path"/logs"
lnd_update_ok=0

# Check if optional arguments are valid
while [ ! -z "$1" ];
do
  if [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
    show_usage
    exit 0
  elif [[ "$1" == "-s" ]] || [[ "$1" == "--sig-min" ]]; then
    sig_min=$2
    if [[ -z $sig_min ]]; then echo "No values provided for $1"; exit 1; fi
    sig_min_re='^[0-9]+$'
    if ! [[ $sig_min =~ $sig_min_re ]]; then echo "Invalid input $sig_min, $1 must be an integer"; exit 1; fi
    shift
  elif [[ "$1" == "-a" ]] || [[ "$1" == "--sys-arc" ]]; then
    sys_arc=$2
    if [[ -z $sys_arc ]]; then echo "No values provided for $1"; exit 1; fi
    if ! ([[ $sys_arc == "amd64" ]] || [[ $sys_arc == "arm64" ]]); then echo "Invalid input $sys_arc, $1 valid values are: amd64, arm64"; exit 1; fi
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
log=$log_dir/update_lightning_$(date +"%Y%m%d_T_%H%M%S").log

echo $(outl)"Checking Lightning Client LND" >> $log

# Check version and latest release
lnd_v=$(lnd --version | grep version | sed 's|.*v||;s|[\.00*]*$||')
echo $(outl)"Lightning Network current version:" $lnd_v >> $log
lnd_latest=$(curl -sL https://api.github.com/repos/lightningnetwork/lnd/releases/latest | grep tag_name | sed 's|.*: "v||;s|",||;s|[\.00*]*$||')
echo $(outl)"Lightning Network latest available release:" $lnd_latest >> $log

# Compare versions
if [[ "$lnd_v" > "$lnd_latest" ]] || [[ "$lnd_v" < "$lnd_latest" ]]
then
  echo $(outl)"Version mismatch, starting update process" >> $log
  lnd_tag=$(curl -sL https://api.github.com/repos/lightningnetwork/lnd/releases/latest | grep tag_name | sed 's|.*: "v||;s|",||')
  cd /tmp

  # Stopping service
  echo $(outl)"Stopping lnd service" >> $log
  sudo systemctl stop lnd
  lnd_status=$(systemctl is-active lnd.service)
  if [ "$lnd_status" == "active" ]; then echo $(errl)"Impossible to stop lnd service, service is $lnd_status" >> $log; exit 1; fi
  echo $(outl)"Service lnd stopped, service is $lnd_status" >> $log

  # Clean any previously downloaded files
  echo $(outl)"Cleanup of previously downloaded files" >> $log

  if [ -f lnd-linux-$sys_arc-v$lnd_tag.tar.gz ]
  then
    rm -R lnd-linux-$sys_arc-v$lnd_tag.tar.gz
    if [[ $? != 0 ]]; then echo "Cannot cleanup file lnd-linux-$sys_arc-v$lnd_tag.tar.gz" >> $log; exit 1; fi
  fi
  if [ -f manifest-v$lnd_tag.txt ]
  then
    rm -R manifest-v$lnd_tag.txt
    if [[ $? != 0 ]]; then echo "Cannot cleanup file manifest-v$lnd_tag.txt" >> $log; exit 1; fi
  fi
  if [ -f manifest-roasbeef-v$lnd_tag.sig ]
  then
    rm -R manifest-roasbeef-v$lnd_tag.sig
    if [[ $? != 0 ]]; then echo "Cannot cleanup file manifest-roastbeef-v$lnd_tag.sig" >> $log; exit 1; fi
  fi

  # Clean any previously extracted folder
  if [ -d "lnd-linux-$sys_arc-v$lnd_tag/" ]
  then
    rm -R "lnd-linux-$sys_arc-v$lnd_tag/"
    if [[ $? != 0 ]]; then echo "Cannot cleanup previously extracted folder lnd-linux-$sys_arc-v$lnd_tag/" >> $log; exit 1; fi
  fi

  # File download
  echo $(outl)"Starting files download" >> $log

  # Download tar
  download_res=$(download_file https://github.com/lightningnetwork/lnd/releases/download/v$lnd_tag/lnd-linux-$sys_arc-v$lnd_tag.tar.gz)
  if [[ $? == 0 ]]; then echo $(outl)$download_res >> $log; else echo $(errl)$download_res >> $log; fi

  # Download manifest
  download_res=$(download_file https://github.com/lightningnetwork/lnd/releases/download/v$lnd_tag/manifest-v$lnd_tag.txt)
  if [[ $? == 0 ]]; then echo $(outl)$download_res >> $log; else echo $(errl)$download_res >> $log; fi

  # Download signature
  download_res=$(download_file https://github.com/lightningnetwork/lnd/releases/download/v$lnd_tag/manifest-roasbeef-v$lnd_tag.sig)
  if [[ $? == 0 ]]; then echo $(outl)$download_res >> $log; else echo $(errl)$download_res >> $log; fi

  echo $(outl)"Files downloaded" >> $log

  # Checksum verification
  echo $(outl)"Starting checksum verification" >> $log
  sha256sum --quiet --ignore-missing --check manifest-v$lnd_tag.txt
  if [[ $? != 0 ]]; then echo $(errl)"Checksum verification error" >> $log; exit 1; fi
  echo $(outl)"Checksum verification ok" >> $log

  # Signature verification
  echo $(outl)"Starting signature verification" >> $log
  sig_ver_out=$({ sig_ver_stdout=$(gpg --verify manifest-roasbeef-v$lnd_tag.sig manifest-v$lnd_tag.txt); } 2>&1)

  sig_count=0

  # Parsing signature verification output
  parse_sig_log "$sig_ver_out"
  sig_count=$?

  echo $(outl)$sig_count" signatures found" >> $log

  # Signature number check
  if [[ $sig_count -lt $sig_min ]]
  then
    echo $(errl)"Minimum signature count not reached("$sig_min")" >> $log
    exit 1
  else
    echo $(outl)"Minimum signature count reached" >> $log
  fi

  # Extraction of tar file
  echo $(outl)"Starting extraction of tar file" >> $log
  tar -xf lnd-linux-$sys_arc-v$lnd_tag.tar.gz
  if [[ $? != 0 ]]; then echo $(errl)"Tar extraction error" >> $log; exit 1; fi
  echo $(outl)"Tar extraction ok" >> $log

  # Installation of binaries
  echo $(outl)"Starting binaries installation" >> $log
  sudo install -m 0755 -o root -g root -t /usr/local/bin lnd-linux-$sys_arc-v$lnd_tag/*

  lnd_v=$(lnd --version | grep version | sed 's|.* v||')
  common_prefix=$(printf "%s\n%s\n" "$lnd_v" "$lnd_latest" | sed -e 'N;s/^\(.*\).*\n\1.*$/\1/')
  if [[ $lnd_v == $common_prefix ] || [ $lnd_latest == $common_prefix ]]
  then
    lnd_updated=1
    echo $(outl)"Binaries installation ok, current LND client version: $lnd_v" >> $log
  else
    echo $(errl)"Binaries installation error" >> $log
    exit 1
  fi

  # Service restart
  echo $(outl)"Starting service lnd" >> $log
  sudo systemctl start lnd
  lnd_status=$(systemctl is-active lnd.service)
  if [ "$lnd_status" == "active" ]
  then
    echo $(outl)"Service lnd started correctly, service is now running" >> $log
  else
    echo $(errl)"Service lnd start failed, service status is $lnd_status" >> $log
  fi
else
  echo $(outl)"Version matching, nothing to do" >> $log
fi
