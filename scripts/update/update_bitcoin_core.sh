#! /bin/bash
. update_node.conf

function parse_sig_log() {
  count=$1
  st=$2

  while IFS= read -r line
    do
      if [[ $line == *"Good signature from"* ]]
      then
        sig_name=${line#*\"}
        sig_name="Good signature from "${sig_name%\"*}
      elif [[ $line == *"WARNING: This key is not certified with a trusted signature!"* ]]
      then
        warning_found=1
      elif [[ $line == *"Primary key fingerprint:"* ]]
      then
        key_fingerprint=${line#*:}
        echo $(outl)$sig_name >> $log
        echo $(outl)"Key fingerprint "$key_fingerprint >> $log
        count=$(($count+1))
        if [ $warning_found == 1 ]
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

b_core_update_ok=0

echo $(outl)"Checking Bitcoin Core" >> $log

# Checking version and latest release
b_core_v=$(bitcoind --version | grep version | sed 's|.* v||')
echo $(outl)"Bitcoin Core current version:" $b_core_v >> $log
b_core_latest=$(curl -sL https://api.github.com/repos/bitcoin/bitcoin/releases/latest | grep tag_name | sed 's|.*: "v||;s|",||')
echo $(outl)"Bitcoin Core latest available release:" $b_core_latest >> $log
b_core_v=1.0.0
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
  if [ $sig_count -lt $min_sig_threeshold ]
  then
    echo $(errl)"Minimum signature count not reached("$min_sig_threeshold"), update aborted" >> $log
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
  #sudo install -m 0755 -o root -g root -t /usr/local/bin bitcoin-$b_core_latest/bin/*

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
  #sudo systemctl restart bitcoind
  b_core_status=$(sudo systemctl status bitcoind.service | grep Active | sed 's|.*Active:.*(||;s|).*||')
  if [ $b_core_status == "running" ]
  then
    echo $(outl)"Service bitcoind restarted correctly, service is now running" >> $log
  else
    echo $(errl)"Service bitcoind restart failed, service status is $b_core_status" >> $log
  fi
fi
