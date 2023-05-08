#!/bin/bash

# Main Raspiscripts script

sudo apt install -y dialog

HEIGHT=15
WIDTH=40
CHOICE_HEIGHT=4
BACKTITLE="Raspiscripts"
TITLE="Raspiscripts Main Menu"
MENU="Choose one of the following options:"

OPTIONS=(1 "Init System"
         2 "... WIP ...")

CHOICE=$(dialog --clear \
          --backtitle "$BACKTITLE" \
          --title "$TITLE" \
          --menu "$MENU" \
          $HEIGHT $WIDTH $CHOICE_HEIGHT \
          "${OPTIONS[@]}" \
          2>&1 >/dev/tty)

clear
case $CHOICE in
  1)
    sudo -E bash ./scripts/setup/init.sh
    ;;
  2)
    echo "WIP"
    ;;
esac
