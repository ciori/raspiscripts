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

echo $(outl)"Script update_node execution starts" >> $log

b_core_update_ok=0
electrum_update_ok=0
btcrpcexplorer_update_ok=0
mempool_update_ok=0

# Bitcoin Core Section
if [ $update_bitcoin_core == 1 ]
then
  echo $(outl)"Checking Bitcoin Core" >> $log

  # Checking version and latest release
  b_core_v=$(bitcoind --version | grep version | cut -c 23-)
  echo $(outl)"Bitcoin Core current version:" $b_core_v >> $log
  b_core_latest=$(curl -sL https://api.github.com/repos/bitcoin/bitcoin/releases/latest | grep tag_name | cut -d '"' -f 4 | cut -c 2-)
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
    wget -q https://bitcoincore.org/bin/bitcoin-core-$b_core_latest/bitcoin-$b_core_latest-$sys_arch-linux-gnu.tar.gz
    if [ $? == 0 ]
    then
      echo $(outl)"Bitcoin Core tar download ok" >> $log
    else
      echo $(errl)"Bitcoin Core tar download error" >> $log
    fi
    if [ -f bitcoin-$b_core_latest-$sys_arch-linux-gnu.tar.gz ]
    then
      echo $(outl)"Bitcoin Core tar file detected" >> $log
    else
      echo $(errl)"Bitcoin Core tar file missing, update aborted" >> $log
      exit 1
    fi

    # Download checksum
    wget -q https://bitcoincore.org/bin/bitcoin-core-$b_core_latest/SHA256SUMS
    if [ $? == 0 ]
    then
      echo $(outl)"Bitcoin Core checksum download ok" >> $log
    else
      echo $(errl)"Bitcoin Core checksum download error" >> $log
    fi
    if [ -f SHA256SUMS ]
    then
      echo $(outl)"Bitcoin Core checksum file detected" >> $log
    else
      echo $(errl)"Bitcoin Core checksum file missing, update aborted" >> $log
      exit 1
    fi

    # Download signature
    wget -q https://bitcoincore.org/bin/bitcoin-core-$b_core_latest/SHA256SUMS.asc
    if [ $? == 0 ]
    then
      echo $(outl)"Bitcoin Core signature download ok" >> $log
    else
      echo $(errl)"Bitcoin Core signature download error" >> $log
    fi
    if [ -f SHA256SUMS.asc ]
    then
      echo $(outl)"Bitcoin Core signature file detected" >> $log
    else
      echo $(errl)"Bitcoin Core signature file missing, update aborted" >> $log
      exit 1
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

    b_core_v=$(bitcoind --version | grep version | cut -c 23-)
    if [ $b_core_v == $b_core_latest ]
    then
      b_core_updated=1
      echo $(outl)"Binaries installation ok, latest Bitcoin Core Version: $b_core_v" >> $log
    else
      echo $(errl)"Binaries installation error" >> $log
      exit 1
    fi

    # Service restart
    echo $(outl)"Restarting service bitcoind" >> $log
    #sudo systemctl restart bitcoind
    b_core_status=$(sudo systemctl status bitcoind.service | grep Active | cut -c 14-)
    echo $b_core_status
    if [[ $b_core_status == *"running"* ]]
    then
      echo $(outl)"Service bitcoind restarted correctly, service is running" >> $log
    else
      echo $(errl)"Service bitcoind restart failed" >> $log
    fi
  fi
fi

# Electrum Section
#if [ $update_electrum == 1 ]

# Final Checks
if [ $b_core_update_ok == 1 ]
then
  echo $(outl)"Bitcoin Core has been updated, current version: $b_core_v" >> $log
else
  echo $(outl)"Bitcoin Core has NOT been updated, current version: $b_core_v" >> $log
fi
if [ $b_core_status == 1 ]
then
  echo $(outl)"Service bitcoind is running" >> $log
else
  echo $(errl)"Service bitcoind inactive" >> $log
fi
echo $(outl)"Script update_node execution completed" >> $log
