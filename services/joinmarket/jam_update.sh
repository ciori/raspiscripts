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

# Stop jam
sudo systemctl stop jam

# Update nodejs with nvm
sudo -u mempool -i bash -c 'curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash'
sudo -u mempool -i bash -c '. "$NVM_DIR/nvm.sh"; nvm install 16'
sudo -u mempool -i bash -c '. "$NVM_DIR/nvm.sh"; nvm alias default 16'

# Fetch the source code for the new version to use
sudo rm -rf /home/jam/jam
sudo -u jam -i bash -c "cd; git clone https://github.com/joinmarket-webui/jam.git"
JAM_VERSION_LATEST=$(curl "https://api.github.com/repos/joinmarket-webui/jam/releases/latest" -s | jq .name -r | awk '{print $1;}')
JAM_VERSION=$(dialog \
    --clear \
    --title "Download Jam" \
    --inputbox "What version would you like to download?" \
    $DIALOG_HEIGHT $DIALOG_WIDTH $JAM_VERSION_LATEST \
    2>&1 >/dev/tty)
sudo -u jam -i bash -c "cd; cd jam; git checkout tags/${JAM_VERSION}; git verify-tag ${JAM_VERSION}"

# Install jam
sudo -u jam -i bash -c 'cd; cd jam; npm install'
sudo -u jam -i bash -c "cd; cd jam; touch .env"
sudo -u jam -i bash -c 'grep -qxF "PORT=3020" /home/jam/jam/.env || echo "PORT=3020" >> /home/jam/jam/.env'

# Copy the start script back into the jam folder
sudo cp ${SCRIPT_PATH}/../../templates/joinmarket/jam-start.sh /home/jam/jam/jam-start.sh
sudo chown jam:jam /home/jam/jam/jam-start.sh
sudo chmod 700 /home/jam/jam/jam-start.sh

# Start jam
sudo systemctl start jam


#### OUTPUT ####

echo ""
echo ""
echo "Jam has been updated to version ${JAM_VERSION}"
echo ""
echo ""