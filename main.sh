#!/bin/bash

# Main Raspiscripts script

# Find current relative path of script
REL_PATH=$(echo $0 | sed 's|.[^/]*.sh||;s|\.||')

SCRIPTS_DIR=$(pwd)$REL_PATH"/scripts"
LOG_DIR=$(pwd)$REL_PATH"/logs"
mkdir -p $LOG_DIR

LOG=$LOG_DIR"/raspiscript_"$(date +"%Y%m%d_T_%H%M%S")".log"

# Import functions
. $SCRIPTS_DIR/utils.sh
. $SCRIPTS_DIR/utils_update.sh

# Install dialog
sudo apt install -y dialog

# global settings for all wizard pages
HEIGHT=20
WIDTH=60
HALF_WIDTH=30

SCRIPTS_TO_EXEC=".$REL_PATH/scripts/update/update_system.sh $LOG $SCRIPTS_DIR $HEIGHT $WIDTH"

function show_main_menu {
  CHOICE=$(dialog \
        --clear \
        --title "Main Menu" \
        --ok-label "Ok" \
        --cancel-label "Abort" \
        --menu "Choose one of the following options:" \
        $HEIGHT $WIDTH 0 \
        "1" "Init System" \
        "2" "Update System" \
        "3" "Update Software" \
        2>&1 >/dev/tty)

  DIALOG_OUTPUT=$?
  if [ "$DIALOG_OUTPUT" -eq 0 ]; then
    case "$CHOICE" in
    1)
      TOR_SYS_ARC=1
      show_init_menu $TOR_SYS_ARC
      ;;
    2)
      choiceB=$(dialog --input-fd 2 --output-fd 1 --menu sub-B 10 30 5 1 B1 2 B2)
      ;;
    3)
      show_update_menu
      ;;
    esac
  else
    clear
    echo "script execution aborted"
  fi
}

function show_init_menu {
  exec 3>&1
  TOR_SYS_ARC=$(dialog \
        --ok-label "Next" \
        --cancel-label "Back" \
        --title "Tor Installation Settings" \
        --radiolist "Select the current system architecture:" \
        $HEIGHT $WIDTH 0 \
        1 amd64 $([[ $1 -eq 1 ]] && echo "on" || echo "off") \
        2 arm64 $([[ $1 -eq 2 ]] && echo "on" || echo "off") \
        2>&1 1>&3)
  DIALOG_OUTPUT=$?
  exec 3>&-
  
  if [ "$DIALOG_OUTPUT" -eq 0 ]; then
    TOR_SYS_ARC=$(echo $TOR_SYS_ARC | sed 's|1|amd64|;s|2|arm64|')
    show_init_confirmation $TOR_SYS_ARC
  else
    show_main_menu
  fi
}

function show_init_confirmation {
  dialog \
        --title "Init Menu" \
        --yes-label "Confirm" \
        --no-label "Back" \
        --input-fd 2 \
        --output-fd 1 \
        --yesno "The selected system architecture is $1\n The following software are going to be installed:\n* gpg\n* git\n* ufw\n* fail2ban\n* nginx\n* apt-transport-https\n* tor\n\nThe following directories will be created:\n* /data\n* /etc/nginx/streams-enabled" \
        $HEIGHT $WIDTH
  
  DIALOG_OUTPUT=$?
  if [ "$DIALOG_OUTPUT" -eq 0 ]; then
    SCRIPTS_TO_EXEC=$SCRIPTS_TO_EXEC$'\n'."$REL_PATH/scripts/setup/init.sh $LOG $SCRIPTS_DIR $HEIGHT $WIDTH $1"
  else
    show_init_menu 1
  fi
}

function show_update_menu {
  UPDATE_LIST=$(dialog \
        --title "Update Menu" \
        --ok-label "Next" \
        --cancel-label "Back" \
        --input-fd 2 \
        --output-fd 1 \
        --checklist "Chose one or more of the following options:\n[spacebar to select]" \
        $HEIGHT $WIDTH 0 \
        "1" "Bitcoin Core" "on" \
        "2" "Electrum Server" "on" \
        "3" "BTC RPC Explorer" "on" \
        "4" "Mempool Explorer" "on" \
        "5" "Lightning Network Daemon" "on" \
        "6" "Ride the Lightning" "on")
  
  DIALOG_OUTPUT=$?
  if [ "$DIALOG_OUTPUT" -eq 0 ]; then
    if [[ $UPDATE_LIST == "" ]]; then
      dialog \
        --title "Update Menu" \
        --no-collapse \
        --msgbox "Choose at least one software to update" \
        $HEIGHT $WIDTH
      show_update_menu
    else
      show_update_confirmation $UPDATE_LIST
    fi
  else
    show_main_menu
  fi
}

function show_update_confirmation {
  dialog \
        --title "Update Menu" \
        --yes-label "Next" \
        --no-label "Back" \
        --input-fd 2 \
        --output-fd 1 \
        --yesno "The following software are going to be updated:$(echo $@ | sed 's|1|\n* Bitcoin Core|;s|2|\n* Electrum Server|;s|3|\n* BTC RPC Explorer|;s|4|\n* Mempool Explorer|;s|5|\n* Lightning Network Daemon|;s|6|\n* Ride the Lightning|')" \
        $HEIGHT $WIDTH
  
  DIALOG_OUTPUT=$?
  if [ "$DIALOG_OUTPUT" -eq 0 ]; then
    UPDATE_LIST=$(echo $UPDATE_LIST | sed 's|1|bitcoin_core|;s|2|electrs|;s|3|btcrpcexplorer|;s|4|mempool|;s|5|lnd|;s|6|rtl|')
    show_update_parameters_menu $UPDATE_LIST
  else
    show_update_menu
  fi
}

function show_update_parameters_menu {
  if [[ "$1" == "bitcoin_core" ]]; then
    BITCOIN_CORE_SIG_MIN="5"
    show_bitcoin_sig_min_menu $BITCOIN_CORE_SIG_MIN
  elif [[ "$1" == "electrs" ]]; then
    SCRIPTS_TO_EXEC=$SCRIPTS_TO_EXEC$'\n'."$REL_PATH/scripts/update/update_electrs.sh"
  elif [[ "$1" == "btcrpcexplorer" ]]; then
    BTCRPCEXPLORER_SERVICE_USER="btcrpcexplorer"
    show_btcrpcexplorer_service_user_menu $BTCRPCEXPLORER_SERVICE_USER
  elif [[ "$1" == "mempool" ]]; then
    MEMPOOL_SERVICE_USER="mempool"
    show_mempool_service_user_menu $MEMPOOL_SERVICE_USER
  elif [[ "$1" == "lnd" ]]; then
    LND_SYS_ARC=1
    show_lnd_sys_arc_menu $LND_SYS_ARC
  elif [[ "$1" == "rtl" ]]; then
    RTL_SERVICE_USER="rtl"
    show_rtl_service_user_menu $RTL_SERVICE_USER
  fi
  if [[ $UPDATE_LIST = *" "* ]]; then
    UPDATE_LIST=$(echo $@ | sed 's|.[^ ]* ||')
    show_update_parameters_menu $UPDATE_LIST
  fi
}

function show_bitcoin_sig_min_menu {
  exec 3>&1
  BITCOIN_CORE_SIG_MIN=$(dialog \
        --ok-label "Next" \
        --cancel-label "Back" \
        --title "Bitcoin Core Update Settings" \
        --form "Minimum valid signatures to verify the release:" \
        $HEIGHT $WIDTH 0 \
        "Minimum Signatures:" 1 1 "$1" 1 $HALF_WIDTH $HALF_WIDTH 0 \
        2>&1 1>&3)
  DIALOG_OUTPUT=$?
  exec 3>&-

  if [ "$DIALOG_OUTPUT" -eq 0 ]; then
    BITCOIN_SIG_MIN_RE='^[0-9]+$'
    if ! [[ $BITCOIN_CORE_SIG_MIN =~ $BITCOIN_SIG_MIN_RE ]]; then
      dialog \
        --title "Bitcoin Core Update Settings" \
        --no-collapse \
        --msgbox "Invalid input $BITCOIN_CORE_SIG_MIN\nMinimum Signatures must be an integer" \
        $HEIGHT $WIDTH
      show_bitcoin_sig_min_menu $BITCOIN_CORE_SIG_MIN
    else
      BITCOIN_SYS_ARC=1
      show_bitcoin_sys_arc_menu $BITCOIN_SYS_ARC
    fi
  else
    show_update_menu
  fi
}

function show_bitcoin_sys_arc_menu {
  exec 3>&1
  BITCOIN_SYS_ARC=$(dialog \
        --ok-label "Next" \
        --cancel-label "Back" \
        --title "Bitcoin Core Update Settings" \
        --radiolist "Select the current system architecture:" \
        $HEIGHT $WIDTH 0 \
        1 x86_64 $([[ $1 -eq 1 ]] && echo "on" || echo "off") \
        2 aarch64 $([[ $1 -eq 2 ]] && echo "on" || echo "off") \
        3 arm $([[ $1 -eq 3 ]] && echo "on" || echo "off") \
        2>&1 1>&3)
  DIALOG_OUTPUT=$?
  exec 3>&-
  
  if [ "$DIALOG_OUTPUT" -eq 0 ]; then
    BITCOIN_SYS_ARC=$(echo $BITCOIN_SYS_ARC | sed 's|1|x86_64|;s|2|aarch64|;s|3|arm|')
    SCRIPTS_TO_EXEC=$SCRIPTS_TO_EXEC$'\n'."$REL_PATH/scripts/update/update_bitcoin_core.sh --sig-min $BITCOIN_CORE_SIG_MIN --sys-arc $BITCOIN_SYS_ARC"
  else
    show_bitcoin_sig_min_menu $BITCOIN_CORE_SIG_MIN
  fi
}


function show_lnd_sys_arc_menu {
  exec 3>&1
  LND_SYS_ARC=$(dialog \
        --ok-label "Next" \
        --cancel-label "Back" \
        --title "Lightning Network Daemon Update Settings" \
        --radiolist "Select the current system architecture:" \
        $HEIGHT $WIDTH 0 \
        1 amd64 $([[ $1 -eq 1 ]] && echo "on" || echo "off") \
        2 arm64 $([[ $1 -eq 2 ]] && echo "on" || echo "off") \
        2>&1 1>&3)
  DIALOG_OUTPUT=$?
  exec 3>&-
  
  if [ "$DIALOG_OUTPUT" -eq 0 ]; then
    LND_SYS_ARC=$(echo $LND_SYS_ARC | sed 's|1|amd64|;s|2|arm64|')
    SCRIPTS_TO_EXEC=$SCRIPTS_TO_EXEC$'\n'."$REL_PATH/scripts/update/update_lnd.sh --sys-arc $LND_SYS_ARC"
  else
    show_update_menu
  fi
}

function show_btcrpcexplorer_service_user_menu {
  exec 3>&1
  BTCRPCEXPLORER_SERVICE_USER=$(dialog \
        --ok-label "Next" \
        --cancel-label "Back" \
        --title "BTC RPC Explorer Update Settings" \
        --form "User that installed BTC RPC Explorer and runs it:" \
        $HEIGHT $WIDTH 0 \
        "Service User:" 1 1 "$1" 1 $HALF_WIDTH $HALF_WIDTH 0 \
        2>&1 1>&3)
  DIALOG_OUTPUT=$?
  exec 3>&-

  if [ "$DIALOG_OUTPUT" -eq 0 ]; then
    id $BTCRPCEXPLORER_SERVICE_USER > /dev/null 2>&1
    if [[ $? != 0 ]]; then
      dialog \
        --title "BTC RPC Explorer Update Settings" \
        --no-collapse \
        --msgbox "User $BTCRPCEXPLORER_SERVICE_USER does not exists" \
        $HEIGHT $WIDTH
      show_btcrpcexplorer_service_user_menu $BTCRPCEXPLORER_SERVICE_USER
    else
      SCRIPTS_TO_EXEC=$SCRIPTS_TO_EXEC$'\n'."$REL_PATH/scripts/update/update_btcrpcexplorer.sh --service-user $BTCRPCEXPLORER_SERVICE_USER"
    fi
  else
    show_update_menu
  fi
}

function show_mempool_service_user_menu {
  exec 3>&1
  MEMPOOL_SERVICE_USER=$(dialog \
        --ok-label "Next" \
        --cancel-label "Back" \
        --title "Mempool Explorer Update Settings" \
        --form "User that installed Mempool Explorer and runs it:" \
        $HEIGHT $WIDTH 0 \
        "Service User:" 1 1 "$1" 1 $HALF_WIDTH $HALF_WIDTH 0 \
        2>&1 1>&3)
  DIALOG_OUTPUT=$?
  exec 3>&-

  if [ "$DIALOG_OUTPUT" -eq 0 ]; then
    id $MEMPOOL_SERVICE_USER > /dev/null 2>&1
    if [[ $? != 0 ]]; then
      dialog \
        --title "Mempool Explorer Update Settings" \
        --no-collapse \
        --msgbox "User $MEMPOOL_SERVICE_USER does not exists" \
        $HEIGHT $WIDTH
      show_mempool_service_user_menu $MEMPOOL_SERVICE_USER
    else
      SCRIPTS_TO_EXEC=$SCRIPTS_TO_EXEC$'\n'."$REL_PATH/scripts/update/update_mempool.sh --service-user $MEMPOOL_SERVICE_USER"
    fi
  else
    show_update_menu
  fi
}

function show_rtl_service_user_menu {
  exec 3>&1
  RTL_SERVICE_USER=$(dialog \
        --ok-label "Next" \
        --cancel-label "Back" \
        --title "Ride the Lightning Update Settings" \
        --form "User that installed Ride the Lightning and runs it:" \
        $HEIGHT $WIDTH 0 \
        "Service User:" 1 1 "$1" 1 $HALF_WIDTH $HALF_WIDTH 0 \
        2>&1 1>&3)
  DIALOG_OUTPUT=$?
  exec 3>&-

  if [ "$DIALOG_OUTPUT" -eq 0 ]; then
    id $RTL_SERVICE_USER > /dev/null 2>&1
    if [[ $? != 0 ]]; then
      dialog \
        --title "Ride the Lightning Update Settings" \
        --no-collapse \
        --msgbox "User $RTL_SERVICE_USER does not exists" \
        $HEIGHT $WIDTH
      show_rtl_service_user_menu $RTL_SERVICE_USER
    else
      SCRIPTS_TO_EXEC=$SCRIPTS_TO_EXEC$'\n'."$REL_PATH/scripts/update/update_rtl.sh --service-user $RTL_SERVICE_USER"
    fi
  else
    show_update_menu
  fi
}

show_main_menu

while IFS= read -r SCRIPT
  do
    echo $(info)"Executing $SCRIPT" >> $LOG
    bash -E $SCRIPT
  done <<< $SCRIPTS_TO_EXEC

#clear
