#! /bin/bash

function show_usage() {
  printf "Usage: $0 [optional parameter(s)]\n"
  printf "\n"
  printf "Options:\n"
  printf " -s | --sig_min\tminimum number of valid signatures accepted [3]\n"
  printf " -a | --sys_arc\tsystem architecture, valid options: x86_64, aarch64, arm [x86_64]\n"
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
sys_arc=x86_64
sig_min=3
log_dir=$abs_path"/logs"
b_core_update_ok=0

# Check if optional arguments are valid
while [ ! -z "$1" ];
do
  if [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
    show_usage
  elif [[ "$1" == "-s" ]] || [[ "$1" == "--sig_min" ]]; then
    sig_min=$2
    if [[ -z $sig_min ]]
    then
      echo "No values provided for $1"
      exit 1
    fi
    sig_min_re='^[0-9]+$'
    if ! [[ $sig_min =~ $sig_min_re ]]
    then
      echo "Invalid input $sig_min, $1 must be an integer"
      exit 1
    fi
    shift
  elif [[ "$1" == "-a" ]] || [[ "$1" == "--sys_arc" ]]; then
    sys_arc=$2
    if [[ -z $sis_arc ]]
    then
      echo "No values provided for $1"
      exit 1
    fi
    if ! [[ $sys_arc == "x86_64" ]] || [[ $sys_arc == "aarch64" ]] || [[ $sys_arc == "arm" ]]
    then
      echo "Invalid input $sys_arc, $1 valid values are: x86_64, aarch64, arm"
    fi
    shift
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

log=$log_dir/update_bitcoin_core_$(date +"%Y%m%d_T_%H%M%S").log

echo $(outl)"Checking Bitcoin Core" >> $log

# Checking version and latest release
b_core_v=$(bitcoind --version | grep version | sed 's|.*v||;s|[\.00*]*$||')
echo $(outl)"Bitcoin Core current version:" $b_core_v >> $log
b_core_latest=$(curl -sL https://api.github.com/repos/bitcoin/bitcoin/releases/latest | grep tag_name | sed 's|.*: "v||;s|",||;s|[\.00*]*$||')
echo $(outl)"Bitcoin Core latest available release:" $b_core_latest >> $log

# Compare versions
if [[ "$b_core_v" > "$b_core_latest" ]] || [[ "$b_core_v" < "$b_core_latest" ]]
then
  echo $(outl)"Version mismatch, starting update process" >> $log
  b_core_tag=$(curl -sL https://api.github.com/repos/bitcoin/bitcoin/releases/latest | grep tag_name | sed 's|.*: "v||;s|",||')
  cd /tmp

  # File download
  echo $(outl)"Cleanup of previously downloaded files" >> $log

  # Clean any previously downloaded files
  if [ -z bitcoin-$b_core_tag-$sys_arc-linux-gnu.tar.gz ]
  then
    rm -R bitcoin-$b_core_tag-$sys_arc-linux-gnu.tar.gz
    if [ ! $? ]
    then
      echo "Cannot cleanup file bitcoin-$b_core_tag-$sys_arc-linux-gnu.tar.gz" >> $log
      exit 1
    fi
  fi
  if [ -z SHA256SUMS ]
  then
    rm -R SHA256SUMS
    if [ ! $? ]
    then
      echo "Cannot cleanup file SHA256SUMS" >> $log
      exit 1
    fi
  fi
  if [ -z SHA256SUMS.asc ]
  then
    rm -R SHA256SUMS.asc"
    if [ ! $? ]
    then
      echo "Cannot cleanup file SHA256SUMS.asc" >> $log
      exit 1
    fi
  fi

  echo $(outl)"Starting files download" >> $log

  # Download tar
  download_res=$(download_file https://bitcoincore.org/bin/bitcoin-core-$b_core_tag/bitcoin-$b_core_tag-$sys_arc-linux-gnu.tar.gz)
  if [ $? == 0 ]
  then
    echo $(outl)$download_res >> $log
  else
    echo $(errl)$download_res >> $log
  fi

  # Download checksum
  download_res=$(download_file https://bitcoincore.org/bin/bitcoin-core-$b_core_tag/SHA256SUMS)
  if [ $? == 0 ]
  then
    echo $(outl)$download_res >> $log
  else
    echo $(errl)$download_res >> $log
  fi

  # Download signature
  download_res=$(download_file https://bitcoincore.org/bin/bitcoin-core-$b_core_tag/SHA256SUMS.asc)
  if [ $? == 0 ]
  then
    echo $(outl)$download_res >> $log
  else
    echo $(errl)$download_res >> $log
  fi

  echo $(outl)"Files downloaded" >> $log

  # Checksum verification
  echo $(outl)"Starting checksum verification" >> $log
  sha256sum --ignore-missing --check SHA256SUMS
  if [ $? ]
  then
    echo $(outl)"Checksum verification ok" >> $log
  else
    echo $(errl)"Checksum verification error, update aborted" >> $log
    exit 1
  fi

  # Signature verification
  echo $(outl)"Starting signature verification" >> $log
  sig_ver_out=$({ sig_ver_stdout=$(gpg --verify SHA256SUMS.asc); } 2>&1)

  sig_count=0

  # Parsing signature verification output
  parse_sig_log "$sig_ver_out"
  sig_count=$?

  echo $(outl)$sig_count" signatures found" >> $log

  # Signature number check
  if [[ $sig_count -lt $sig_min ]]
  then
    echo $(errl)"Minimum signature count not reached("$sig_min"), update aborted" >> $log
    exit 1
  else
    echo $(outl)"Minimum signature count reached" >> $log
  fi

  # Clean any previously extracted folder
  if [ -d "bitcoin-$b_core_tag/" ]
  then
    rm -R "bitcoin-$b_core_tag/"
    if [ ! $? ]
    then
      echo "Cannot cleanup previously extracted folder bitcoin-$b_core_tag/" >> $log
      exit 1
    fi
  fi
  # Extraction of tar file
  echo $(outl)"Starting extraction of tar file" >> $log
  tar -xf bitcoin-$b_core_tag-$sys_arc-linux-gnu.tar.gz
  if [ $? ]
  then
    echo $(outl)"Tar extraction ok" >> $log
  else
    echo $(errl)"Tar extraction error, update aborted" >> $log
    exit 1
  fi

  # Installation of binaries
  echo $(outl)"Starting binaries installation" >> $log
  sudo install -m 0755 -o root -g root -t /usr/local/bin bitcoin-$b_core_tag/bin/*

  b_core_v=$(bitcoind --version | grep version | sed 's|.* v||')
  common_prefix=$(printf "%s\n%s\n" "$b_core_v" "$b_core_latest" | sed -e 'N;s/^\(.*\).*\n\1.*$/\1/')
  if [ $b_core_v == $common_prefix ] || [ $b_core_latest == $common_prefix ]
  then
    b_core_updated=1
    echo $(outl)"Binaries installation ok, current Bitcoin Core version: $b_core_v" >> $log
  else
    echo $(errl)"Binaries installation error" >> $log
    exit 1
  fi

  # Service restart
  echo $(outl)"Restarting service bitcoind" >> $log
  sudo systemctl restart bitcoind
  b_core_status=$(sudo systemctl status bitcoind.service | grep Active | sed 's|.*Active: ||;s|).*|)|')
  if [ "$b_core_status" == "active (running)" ]
  then
    echo $(outl)"Service bitcoind restarted correctly, service is $b_core_status" >> $log
  else
    echo $(errl)"Service bitcoind restart failed, service status is $b_core_status" >> $log
  fi
else
  echo $(outl)"Version matching, nothing to do" >> $log
fi
