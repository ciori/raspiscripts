#!/bin/bash

# Telegram bot variables
BOT_PATH=$(echo $0 | sed 's|/.[^/]*.sh$||;s|\./||')
. $BOT_PATH/telegram.bot.conf

# check bitcoind status if service is enabled
bitcoind_enabled=$(systemctl is-enabled bitcoind.service)
bitcoind_active=$(systemctl is-active bitcoind.service)

# check lnd status if service is enabled
lnd_enabled=$(systemctl is-enabled lnd.service)
lnd_active=$(systemctl is-active lnd.service)

if [ $bitcoind_enabled == "enabled" ] && [ "$bitcoind_status" != "active" ] && [ $lnd_enabled == "enabled" ] && [ "$lnd_status" != "active" ]; then
  bitcoin_blocks=$(bitcoin-cli getblockchaininfo | grep "blocks" | sed 's|.*": ||;s|,||')
  if [[ $? -eq 0 ]]; then
    lnd_blocks=$(lncli getinfo | grep "block_height" | sed 's|.*": ||;s|,||')
    if [[ $? -eq 0 ]]; then
      if [[ $bitcoin_blocks != $lnd_blocks ]]; then #if [[ $bitcoin_blocks == $lnd_blocks ]]; then
      #  $BOT_PATH/telegram.bot --bottoken $BOT_TOKEN --chatid $CHAT_ID --title "✅ $(hostname) \\[ BTCD-LND Sync \\]:" --text "BTCD blocks: $bitcoin_blocks\nLND blocks: $lnd_blocks"
      #else
        $BOT_PATH/telegram.bot --bottoken $BOT_TOKEN --chatid $CHAT_ID --title "🚨 $(hostname) \\[ BTCD-LND Sync \\]:" --text "BTCD blocks: $bitcoin_blocks\nLND blocks: $lnd_blocks"
      fi
    else
      $BOT_PATH/telegram.bot --bottoken $BOT_TOKEN --chatid $CHAT_ID --title "🚨 $(hostname) \\[ BTCD-LND Sync \\]:" --text "error retrieving chain info with lncli"
    fi
  else
    $BOT_PATH/telegram.bot --bottoken $BOT_TOKEN --chatid $CHAT_ID --title "🚨 $(hostname) \\[ BTCD-LND Sync \\]:" --text "error retrieving chain info with bitcoin-cli"
  fi
fi