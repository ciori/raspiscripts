#!/usr/bin/bash

# Main Raspiscripts script

echo "--------------------"
echo "--- Raspiscripts ---" 
echo "--------------------"
echo ""

show_main_options () {
  echo "What do you want to do?"
  echo "[1] init system"
  echo "[...] ... WIP ..."
  echo "[h] show options"
  echo "[q] quit"
}

while true; do
  read -p "Choose your option: " main_choice
  case $main_choice in
    [1]* ) curl -fsSL https://raw.githubusercontent.com/ciori/raspiscripts/main/scripts/setup/init.sh | sudo -E bash -; break;;
    [h]* ) show_main_options;;
    [q]* ) exit;;
    * ) echo "Please give a correct option";;
  esac
done
