#!/bin/bash

# print an info message
function info {
  echo $(date "+%F %T")" - INFO - "
}

# print a warning message
function warning {
  echo $(date "+%F %T")" - WARNING - "
}

# print an error message
function error {
  echo $(date "+%F %T")" - ERROR - "
}

# create logs folder if it doesn't exist and a new log file
function init_log {
  abs_path=$(pwd)
  if [ $abs_path == "/" ]
  then
    abs_path="/$rel_path"
  else
    abs_path=$(pwd)"/$rel_path"
  fi
  log_dir=$abs_path"/logs"
  sudo mkdir -p $log_dir
  log=$log_dir/$1"_"$(date +"%Y%m%d_T_%H%M%S").log
}

# create logs folder if it doesn't exist
function init_log_dir {
  abs_path=$(pwd)
  if [ $abs_path == "/" ]
  then
    abs_path="/$rel_path"
  else
    abs_path=$(pwd)"/$rel_path"
  fi
  log_dir=$abs_path"/logs"
  sudo mkdir -p $log_dir
}

# download a file from the specified url
function download_file {
  url=$1
  file=$(echo $url | sed 's|.*/||')

  wget -q $url
  if [ $? == 0 ]; then
    if [ -f $file ]; then
      echo $(info)"$file downloaded from $url" >> $log
    else
      echo $(error)"$url downloaded but $file missing" >> $log
      exit 1
    fi
  else
    echo $(error)"error while downloading $file from $url" >> $log
    exit 1
  fi
}

# delete a file or a folder if it exists
function delete {
  if [[ -f $1 ]] || [[ -d $1 ]]; then
    rm -R $1
    if [[ $? != 0 ]]; then echo $(error) "Cannot cleanup $1" >> $log; exit 1; fi
  fi
}
