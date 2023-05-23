#! /bin/bash

# Import helping functions
. functions.sh

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

# Parameters Definition
user=$(whoami)
sys_arch=x86_64
sig_min=3
log_dir=/home/$(whoami)/logs/

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
    if [[ -z $sig_min ]]
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
    if ! [ -d $log_dir ]
    then
      echo "directory $log_dir does not exist"
    fi
    shift
  else
    echo "Invalid argument $1"
    show_usage
    exit 1
  fi
  shift
done

log=$log_dir/update_bitcoin_core_$(date +"%Y%m%d_T_%H%M%S").log

b_core_update_ok=0

echo $(outl)"Checking Bitcoin Core" >> $log

# Checking version and latest release
b_core_v=$(bitcoind --version | grep version | sed 's|.* v||')
echo $(outl)"Bitcoin Core current version:" $b_core_v >> $log
b_core_latest=$(curl -sL https://api.github.com/repos/bitcoin/bitcoin/releases/latest | grep tag_name | sed 's|.*: "v||;s|",||')
echo $(outl)"Bitcoin Core latest available release:" $b_core_latest >> $log

if [ $b_core_v == $b_core_latest ]
then
  echo $(outl)"Version matching, nothing to do" >> $log
else
  echo $(outl)"Version mismatch, starting update process" >> $log
  cd /tmp

  # File download
  echo $(outl)"Starting files download" >> $log

  # Download tar
  download_res=$(download_file https://bitcoincore.org/bin/bitcoin-core-$b_core_latest/bitcoin-$b_core_latest-$sys_arch-linux-gnu.tar.gz)
  if [ $? == 0 ]
  then
    echo $(outl)$download_res >> $log
  else
    echo $(errl)$download_res >> $log
  fi

  # Download checksum
  download_res=$(download_file https://bitcoincore.org/bin/bitcoin-core-$b_core_latest/SHA256SUMS)
  if [ $? == 0 ]
  then
    echo $(outl)$download_res >> $log
  else
    echo $(errl)$download_res >> $log
  fi

  # Download signature
  download_res=$(download_file https://bitcoincore.org/bin/bitcoin-core-$b_core_latest/SHA256SUMS.asc)
  if [ $? == 0 ]
  then
    echo $(outl)$download_res >> $log
  else
    echo $(errl)$download_res >> $log
  fi

  # Checksum verification
  echo $(outl)"Starting checksum verification" >> $log
  checksum_ver=$(sha256sum --ignore-missing --check SHA256SUMS)
  if [ "$checksum_ver" == "bitcoin-${b_core_latest}-${sys_arch}-linux-gnu.tar.gz: OK" ]
  then
    echo $(outl)"Checksum verification ok" >> $log
  else
    echo $(errl)"Checksum verification error, update aborted" >> $log
    exit 1
  fi

  # Signature verification
  echo $(outl)"Starting signature verification" >> $log
  sig_ver_stderr=$({ sig_ver_stdout=$(gpg --verify SHA256SUMS.asc); } 2>&1)

  sig_count=0

  # Parsing signature verification output log
  parse_sig_log $sig_count "$sig_ver_stderr"
  sig_count=$?

  # Parsing signature verification error log
  parse_sig_log $sig_count "$sig_ver_stderr"
  sig_count=$?

  echo $(outl)$sig_count" signatures found" >> $log

  # Signature number check
  if [ $sig_count -lt $sig_min ]
  then
    echo $(errl)"Minimum signature count not reached("$sig_min"), update aborted" >> $log
    exit 1
  else
    echo $(outl)"Minimum signature count reached" >> $log
  fi

  # Extraction of tar file
  echo $(outl)"Starting extraction of tar file" >> $log
  tar_stderr=$({ tar_stdout=$(tar -xvf bitcoin-$b_core_latest-$sys_arch-linux-gnu.tar.gz); } 2>&1)
  if [ -z "$tar_stderr" ]
  then
    echo $(outl)"Tar extraction ok" >> $log
  else
    echo $(errl)"Tar extraction error, update aborted" >> $log
    exit 1
  fi

  # Installation of binaries
  echo $(outl)"Starting binaries installation" >> $log
  sudo install -m 0755 -o root -g root -t /usr/local/bin bitcoin-$b_core_latest/bin/*

  b_core_v=$(bitcoind --version | grep version | sed 's|.* v||')
  if [ $b_core_v == $b_core_latest ]
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
fi
