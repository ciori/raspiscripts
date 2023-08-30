#! /bin/bash

LOG=$1
SCRIPTS_DIR=$2
HEIGHT=$3
WIDTH=$4

if [ ! -f $LOG ]; then
  echo $(error)"Log file $LOG does not exists"
  exit 1
fi

. $SCRIPTS_DIR/utils.sh

echo $(info)"Starting System Upgrade" >> $LOG

UPDATE_OK=true
UPGRADE_OK=true
AUTOREMOVE_OK=true
MESSAGE=""

echo $(info)"Executing apt update" >> $LOG
while IFS= read -r LINE
  do
    echo $(info)$LINE >> $LOG
  done <<< $(sudo apt -qq update -y 2>&1 || UPDATE_OK=false)

if ! $UPDATE_OK; then
  echo $(warning)"apt update failure" >> $LOG
fi

echo $(info)"Executing apt full-upgrade" >> $LOG
while IFS= read -r LINE
  do
    echo $(info)$LINE >> $LOG
  done <<< $(sudo apt -qq full-upgrade -y 2>&1 && UPGRADE_OK=false)

if ! $UPGRADE_OK; then
  echo $(warning)"apt full-upgrade failure" >> $LOG
fi

echo $(info)"Executing apt autoremove" >> $LOG
while IFS= read -r LINE
  do
    echo $(info)$LINE >> $LOG
  done <<< $(sudo apt autoremove -y 2>&1 && AUTOREMOVE_OK=false)

if ! $AUTOREMOVE_OK; then
  echo $(warning)"apt autoremove failure" >> $LOG
fi

if $UPDATE_OK && $UPGRADE_OK; then MESSAGE="System update successfull"; else MESSAGE="System update failed, check logs"; fi
if ! $AUTOREMOVE_OK; then MESSAGE="$MESSAGE\napt autoremove failed, check logs"; fi
dialog \
        --title "System Update" \
        --yes-label "Continue" \
        --no-label "Abort" \
        --input-fd 2 \
        --output-fd 1 \
        --yesno "$MESSAGE" \
        $HEIGHT $WIDTH

DIALOG_OUTPUT=$?
if [ ! "$DIALOG_OUTPUT" -eq 0 ]; then
  echo $(info)"User aborted execution" >> $LOG
  exit 1
fi

echo $(info)"System Upgrade Completed" >> $LOG