#!/bin/bash

# compute path and import send message function
path=$(echo $0 | sed 's|/.[^/]*.sh$||;s|\./||')
. $path/send_message.sh

# check bitcoind status if service is enabled
bitcoind_enabled=$(sudo systemctl is-enabled bitcoind.service)
bitcoind_status=$(sudo systemctl status bitcoind.service | grep Active | sed 's|.*Active:.*(||;s|).*||')
if [ $bitcoind_enabled == "enabled" ] && [ $bitcoind_status != "running" ]
then
  send "$(hostname): Bitcoin Core is $bitcoind_status"
fi

# check electrs status if service is enabled
electrs_enabled=$(sudo systemctl is-enabled electrs.service)
electrs_status=$(sudo systemctl status electrs.service | grep Active | sed 's|.*Active:.*(||;s|).*||')
if [ $electrs_enabled == "enabled" ] && [ $electrs_status != "running" ]
then
  send "$(hostname): Electrum Server is $electrum_status"
fi

# check btcrpcexplorer status if service is enabled
btcrpcexplorer_enabled=$(sudo systemctl is-enabled btcrpcexplorer.service)
btcrpcexplorer_status=$(sudo systemctl status btcrpcexplorer.service | grep Active | sed 's|.*Active:.*(||;s|).*||')
if [ $btcrpcexplorer_enabled == "enabled" ] && [ $btcrpcexplorer_status != "running" ]
then
  send "$(hostname): BTC RPC Explorer is $btcrpcexplorer_status"
fi

# check mempool status if service is enabled
mempool_enabled=$(sudo systemctl is-enabled mempool.service)
mempool_status=$(sudo systemctl status mempool.service | grep Active | sed 's|.*Active:.*(||;s|).*||')
if [ $mempool_enabled == "enabled" ] && [ $mempool_status != "running" ]
then
  send "$(hostname): Mempool is $mempool_status"
fi

# check jmwalletd status if service is enabled
jmwalletd_enabled=$(sudo systemctl is-enabled jmwalletd.service)
jmwalletd_status=$(sudo systemctl status jmwalletd.service | grep Active | sed 's|.*Active:.*(||;s|).*||')
if [ $jmwalletd_enabled == "enabled" ] && [ $jmwalletd_status != "running" ]
then
  send "$(hostname): JoinMarket is $jmwalletd_status"
fi

# check obwatcher status if service is enabled
obwatcher_enabled=$(sudo systemctl is-enabled obwatcher.service)
obwatcher_status=$(sudo systemctl status obwatcher.service | grep Active | sed 's|.*Active:.*(||;s|).*||')
if [ $obwatcher_enabled == "enabled" ] && [ $obwatcher_status != "running" ]
then
  send "$(hostname): Joinmarket - Orderbook Watcher is $obwatcher_status"
fi

# check jam status if service is enabled
jam_enabled=$(sudo systemctl is-enabled jam.service)
jam_status=$(sudo systemctl status jam.service | grep Active | sed 's|.*Active:.*(||;s|).*||')
if [ $jam_enabled == "enabled" ] && [ $jam_status != "running" ]
then
  send "$(hostname): Jam is $jam_status"
fi
