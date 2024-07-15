#!/bin/bash

#### VARIABLES ####

# Dialog parameters
DIALOG_HEIGHT=20
DIALOG_WIDTH=60


#### SCRIPT ####

# Get current script path
SCRIPT=$(realpath "$0")
SCRIPT_PATH=$(dirname "$SCRIPT")

# Load general environment variables
export $(xargs < ${SCRIPT_PATH}/../../envs)

# Get system information
SYS_DPKG_ARCH=$(dpkg --print-architecture)
SYS_UNAME_ARCH=$(uname -m)
SYS_VERSION=$(lsb_release -c | grep Codename | awk -F' ' '{print $2}')

# Stop rtl
sudo systemctl stop rtl

# Fetch the source code for the new version to use
sudo -u rtl bash -c "cd; cd RTL; git fetch; git reset --hard"
RTL_VERSION_LATEST=$(curl "https://api.github.com/repos/Ride-The-Lightning/RTL/releases/latest" -s | jq .tag_name -r)
RTL_VERSION=$(dialog \
    --clear \
    --title "Download Ride The Lightning" \
    --inputbox "What version would you like to use?" \
    $DIALOG_HEIGHT $DIALOG_WIDTH $RTL_VERSION_LATEST \
    2>&1 >/dev/tty)
sudo -u rtl bash -c "cd; cd RTL; git checkout $RTL_VERSION; git verify-tag $RTL_VERSION"

# Install rtl
sudo -u rtl bash -c 'cd; cd RTL; export NVM_DIR="$HOME/.nvm"; [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"; npm install --omit=dev --legacy-peer-deps'

# Start rtl
sudo systemctl start rtl


#### OUTPUT ####

echo ""
echo ""
echo "RTL has been updated to version ${RTL_VERSION}"
echo ""
echo ""
