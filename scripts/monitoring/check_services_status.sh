#!/bin/bash

# Telegram bot variables
BOT_PATH=$(echo $0 | sed 's|/.[^/]*.sh$||;s|\./||')
. $BOT_PATH/telegram.bot.conf

# check bitcoind status if service is enabled
bitcoind_enabled=$(systemctl is-enabled bitcoind.service)
bitcoind_status=$(systemctl status bitcoind.service | grep Active | sed 's|.*Active: ||;s|).*|)|;s|(|\\(|;s|)|\\)|')
if [ $bitcoind_enabled == "enabled" ] && [ "$bitcoind_status" != "active \\(running\\)" ]
then
  $BOT_PATH/telegram.bot --bottoken $BOT_TOKEN --chatid $CHAT_ID --title "🚨 $(hostname):" --text "Bitcoin Core is $bitcoind_status"
fi

# check electrs status if service is enabled
electrs_enabled=$(systemctl is-enabled electrs.service)
electrs_status=$(systemctl status electrs.service | grep Active | sed 's|.*Active: ||;s|).*|)|;s|(|\\(|;s|)|\\)|')
if [ $electrs_enabled == "enabled" ] && [ "$electrs_status" != "active \\(running\\)" ]
then
  $BOT_PATH/telegram.bot --bottoken $BOT_TOKEN --chatid $CHAT_ID --title "🚨 $(hostname):" --text "Electrum Server is $electrum_status"
fi

# check btcrpcexplorer status if service is enabled
btcrpcexplorer_enabled=$(systemctl is-enabled btcrpcexplorer.service)
btcrpcexplorer_status=$(systemctl status btcrpcexplorer.service | grep Active | sed 's|.*Active: ||;s|).*|)|;s|(|\\(|;s|)|\\)|')
if [ $btcrpcexplorer_enabled == "enabled" ] && [ "$btcrpcexplorer_status" != "active \\(running\\)" ]
then
  $BOT_PATH/telegram.bot --bottoken $BOT_TOKEN --chatid $CHAT_ID --title "🚨 $(hostname):" --text "BTC RPC Explorer is $btcrpcexplorer_status"
fi

# check mempool status if service is enabled
mempool_enabled=$(systemctl is-enabled mempool.service)
mempool_status=$(systemctl status mempool.service | grep Active | sed 's|.*Active: ||;s|).*|)|;s|(|\\(|;s|)|\\)|')
if [ $mempool_enabled == "enabled" ] && [ "$mempool_status" != "active \\(running\\)" ]
then
  $BOT_PATH/telegram.bot --bottoken $BOT_TOKEN --chatid $CHAT_ID --title "🚨 $(hostname):" --text "Mempool is $mempool_status"
fi

# check jmwalletd status if service is enabled
jmwalletd_enabled=$(systemctl is-enabled jmwalletd.service)
jmwalletd_status=$(systemctl status jmwalletd.service | grep Active | sed 's|.*Active: ||;s|).*|)|;s|(|\\(|;s|)|\\)|')
if [ $jmwalletd_enabled == "enabled" ] && [ "$jmwalletd_status" != "active \\(running\\)" ]
then
  $BOT_PATH/telegram.bot --bottoken $BOT_TOKEN --chatid $CHAT_ID --title "🚨 $(hostname):" --text "JoinMarket is $jmwalletd_status"
fi

# check obwatcher status if service is enabled
obwatcher_enabled=$(systemctl is-enabled obwatcher.service)
obwatcher_status=$(systemctl status obwatcher.service | grep Active | sed 's|.*Active: ||;s|).*|)|;s|(|\\(|;s|)|\\)|')
if [ $obwatcher_enabled == "enabled" ] && [ "$obwatcher_status" != "active \\(running\\)" ]
then
  $BOT_PATH/telegram.bot --bottoken $BOT_TOKEN --chatid $CHAT_ID --title "🚨 $(hostname):" --text "Joinmarket - Orderbook Watcher is $obwatcher_status"
fi

# check jam status if service is enabled
jam_enabled=$(systemctl is-enabled jam.service)
jam_status=$(systemctl status jam.service | grep Active | sed 's|.*Active: ||;s|).*|)|;s|(|\\(|;s|)|\\)|')
if [ $jam_enabled == "enabled" ] && [ "$jam_status" != "active \\(running\\)" ]
then
  $BOT_PATH/telegram.bot --bottoken $BOT_TOKEN --chatid $CHAT_ID --title "🚨 $(hostname):" --text "Jam is $jam_status"
fi

# check lnd status if service is enabled
lnd_enabled=$(systemctl is-enabled lnd.service)
lnd_status=$(systemctl status lnd.service | grep Active | sed 's|.*Active: ||;s|).*|)|;s|(|\\(|;s|)|\\)|')
if [ $lnd_enabled == "enabled" ] && [ "$lnd_status" != "active \\(running\\)" ]
then
  $BOT_PATH/telegram.bot --bottoken $BOT_TOKEN --chatid $CHAT_ID --title "🚨 $(hostname):" --text "Lightning is $lnd_status"
fi

# check rtl status if service is enabled
rtl_enabled=$(systemctl is-enabled rtl.service)
rtl_status=$(systemctl status rtl.service | grep Active | sed 's|.*Active: ||;s|).*|)|;s|(|\\(|;s|)|\\)|')
if [ $rtl_enabled == "enabled" ] && [ "$rtl_status" != "active \\(running\\)" ]
then
  $BOT_PATH/telegram.bot --bottoken $BOT_TOKEN --chatid $CHAT_ID --title "🚨 $(hostname):" --text "Ride the Lightning is $rtl_status"
fi
