#!/bin/bash
TOKEN="<your_bot_API_token>"
CHAT_ID="<telegram_chat_id>"

function send() {
  if [ ! -z "$1" ]
  then
    MESSAGE=$1
    curl -s -X POST https://api.telegram.org/bot$TOKEN/sendMessage -d chat_id=$CHAT_ID -d text="$MESSAGE" > /dev/null
    return 0
  else
    echo message to send missing
    return 1
  fi
}
