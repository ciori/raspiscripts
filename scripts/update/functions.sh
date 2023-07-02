#!/bin/bash

function outl {
  echo $(date "+%F %T")" - INFO - "
}

function errl {
  echo $(date "+%F %T")" - ERROR - "
}

function parse_sig_log() {
  count=0
  st=$1

  while IFS= read -r line
    do
      if [[ $line == *"Good signature from"* ]]
      then
        sig_name=${line#*\"}
        sig_name="Good signature from "${sig_name%\"*}
      elif [[ $line == *"WARNING: This key is not certified with a trusted signature!"* ]]
      then
        warning_found=true
      elif [[ $line == *"Primary key fingerprint:"* ]]
      then
        key_fingerprint=${line#*:}
        echo $(outl)$sig_name >> $log
        echo $(outl)"Key fingerprint "$key_fingerprint >> $log
        count=$(($count+1))
        if $warning_found
        then
          echo $(outl)"WARNING: This key is not certified with a trusted signature!" >> $log
          warning_found=0
        fi
      fi
    done <<< $st

    return $count
}

function download_file() {
  url=$1
  file=$(echo $url | sed 's|.*/||')

  wget -q $url
  if [ $? == 0 ]
  then
    if [ -f $file ]
    then
      echo "$file downloaded from $url"
      return 0
    else
      echo "error while downloading $file from error"
      return 1
    fi
  else
    echo "$url downloaded but $file missing"
    return 2
  fi
}
