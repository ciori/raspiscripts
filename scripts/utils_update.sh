#!/bin/bash

# print usage info
function show_usage {
  printf "Usage: $0 [optional parameter(s)]\n"
  printf "\n"
  printf "Options:\n"
  if [[ $software == "Bitcoin Core" ]] || [[ $software == "Lightning Network Daemon" ]]; then
    printf " -s | --sig-min\tminimum number of valid signatures accepted [$sig_min]\n"
  fi
  if [[ $software == "Bitcoin Core" ]]; then
    printf " -a | --sys-arc\tsystem architecture, valid options: x86_64, aarch64, arm [$sys_arc]\n"
  fi
  if [[ $software == "Lightning Network Daemon" ]]; then
    printf " -a | --sys-arc\tsystem architecture, valid options: amd64, arm64 [$sys_arc]\n"
  fi
  if [[ $software == "BTC RPC Explorer" ]] || [[ "$software" == "Mempool Explorer" ]] || [[ "$software" == "Ride the Lightning" ]]; then
    printf " -u | --service-user\tuser of $software service [$service_user]\n"
  fi
  printf " -d | --log-dir\t\tpath to save logs [$log_dir]\n"
  printf " -h | --help\t\tshow usage\n"
}

# parse arguments given to the script
function parse_args {
  while [ ! -z "$1" ];
  do
    if [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
      show_usage $software
      exit 0
    elif ([[ "$1" == "-s" ]] || [[ "$1" == "--sig-min" ]]) && [[ "$software" == "Bitcoin Core" ]]; then
      sig_min=$2
      if [[ -z $sig_min ]]; then echo "No values provided for $1"; exit 1; fi
      sig_min_re='^[0-9]+$'
      if ! [[ $sig_min =~ $sig_min_re ]]; then echo "Invalid input $sig_min, $1 must be an integer"; exit 1; fi
      shift
    elif ([[ "$1" == "-a" ]] || [[ "$1" == "--sys-arc" ]]) && ([[ "$software" == "Bitcoin Core" ]] || [[ "$software" == "Lightning Network Daemon" ]]); then
      sys_arc=$2
      if [[ -z $sis_arc ]]; then echo "No values provided for $1"; exit 1; fi
      if [[ "$software" == "Bitcoin Core" ]] && [[ $sys_arc != "x86_64" ]] && [[ $sys_arc != "aarch64" ]] && [[ $sys_arc != "arm" ]]; then echo "Invalid input $sys_arc, $1 valid values are: x86_64, aarch64, arm"; exit 1; fi
      if [[ "$software" == "Lightning Network Daemon" ]] && [[ $sys_arc != "amd64" ]] && [[ $sys_arc != "arm64" ]]; then echo "Invalid input $sys_arc, $1 valid values are: amd64, arm64"; exit 1; fi
      shift
    elif [[ "$1" == "-u" ]] || [[ "$1" == "--service-user" ]] && ([[ "$software" == "BTC RPC Explorer" ]] || [[ "$software" == "Mempool Explorer" ]]); then
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
      show_usage $software
      exit 1
    fi
    shift
  done
}

# compute common prefix of given strings
function get_common_prefix {
  common_prefix=$(printf "%s\n%s\n" "$1" "$2" | sed -e 'N;s/^\(.*\).*\n\1.*$/\1/')
}

# verify if checksum is valid
function verify_checksum {
  echo $(info)"Starting checksum verification" >> $log
  sha256sum --quiet --ignore-missing --check $1
  if [[ $? != 0 ]]; then echo $(error)"Checksum verification failure" >> $log; exit 1; fi
  echo $(info)"Checksum verification succesfull" >> $log
}

# verify number of valid signatures
function verify_sig_min {
  count=0

  while IFS= read -r line
    do
      if [[ $line == *"Good signature from"* ]]; then
        sig_name=${line#*\"}
        sig_name="Good signature from "${sig_name%\"*}
      elif [[ $line == *"WARNING: This key is not certified with a trusted signature!"* ]]; then
        warning_found=true
      elif [[ $line == *"Primary key fingerprint:"* ]]; then
        key_fingerprint=${line#*:}
        echo $(info)$sig_name >> $log
        echo $(info)"Key fingerprint "$key_fingerprint >> $log
        count=$(($count+1))
        if $warning_found; then
          echo $(info)"WARNING: This key is not certified with a trusted signature!" >> $log
          warning_found=0
        fi
      fi
    done <<< $1

  echo $(info)$count" signatures found" >> $log

  if [[ $count -lt $sig_min ]]; then
    echo $(error)"Minimum signature count not reached("$sig_min"), signature verification failed" >> $log
    exit 1
  else
    echo $(info)"Minimum signature count reached, signature verification successfull" >> $log
  fi
}

# verify if installation was successfull
function check_installation {
  get_common_prefix $1 $latest_v
  if [[ $1 == $common_prefix ]] || [[ $latest_v == $common_prefix ]]; then
    echo $(info)"$software installation successfull, current $software version: $1" >> $log
    return 0
  else
    echo $(error)"$software installation failure" >> $log
    return 1
  fi
}

# create backup
function create_backup {
  echo $(info)"Backup of current version" >> $log
  while IFS= read -r file
    do
      if [[ -f $2/$file ]] || [[ -d $2/$file ]]; then
        sudo cp -R $2/$file $2/$file.bak
        if [[ $? != 0 ]]; then echo $(error) "Cannot backup $2/$file" >> $log; exit 1; fi
        echo $(info)"Backup of $2/$file created" >> $log
      fi
    done <<< $1
  echo $(info)"Backup of current version successfull" >> $log
}

# restore file backup
function restore_backup {
  stop_service $service
  echo $(info)"Restoring from backup" >> $log
  while IFS= read -r file
    do
      if [[ -f $2/$file.bak ]] || [[ -d $2/$file.bak ]]; then
        sudo cp -R $2/$file.bak $2/$file
        if [[ $? != 0 ]]; then echo $(error) "Cannot restore backup of $2/$file" >> $log; exit 1; fi
        echo $(info)"Backup of $2/$file restored" >> $log
      fi
    done <<< $1
  echo $(info)"Restore succesfull" >> $log
}

# delete file backup
function delete_backup {
  echo $(info)"Backup removal" >> $log
  while IFS= read -r file
    do
      if [[ -f $backup_path/$file.bak ]]; then
        sudo rm -R $backup_path/$file.bak
        if [[ $? != 0 ]]; then echo $(error) "Cannot remove backup of $backup_path/$file" >> $log; exit 1; fi
        echo $(info)"Backup of $backup_path/$file removed" >> $log
      fi
    done <<< $1
  echo $(info)"Backup removal successfull" >> $log
}

# cleanup function
function cleanup {
  if [[ $? != 0 ]]; then
    echo $(info)"Update Aborted" >> $log
  fi
  if $perform_restore; then
    restore_backup $backup_path $backup_list
  fi
  if $update_attempt; then
    restart_service $service
    if [[ $service == "mempool" ]]; then
      restart_service nginx
    fi
  fi
}

# stop specified service
function stop_service {
  echo $(info)"Stopping $1 service" >> $log
  sudo systemctl stop $1
  service_status=$(sudo systemctl status $1.service | grep Active | sed 's|.*Active: ||;s|).*|)|')
  if [ "$service_status" == "active (running)" ]; then
    echo $(error)"Impossible to stop $1 service, service is $service_status" >> $log
    exit 1
  else
    echo $(info)"Service $1 stopped, service is $service_status" >> $log
  fi
}

# restart specified service
function restart_service {
  echo $(info)"Restarting service $1" >> $log
  sudo systemctl restart $1
  service_status=$(sudo systemctl status $1.service | grep Active | sed 's|.*Active: ||;s|).*|)|')
  if [ "$service_status" == "active (running)" ]; then
    echo $(info)"Service $1 restarted correctly, service is $service_status" >> $log
  else
    echo $(error)"Service $1 restart failed, service status is $service_status" >> $log
  fi
}