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

# Install nodejs with nvm
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
nvm install 16

# Allow mempool on firewall
sudo firewall-cmd --permanent --zone=public --add-port=4081/tcp
sudo firewall-cmd --reload

# Configure user
sudo adduser --disabled-password --gecos "" mempool
sudo adduser mempool bitcoin

# Get the source code and ask for the version to use
sudo -u mempool bash -c "cd; git clone https://github.com/mempool/mempool"
MEMPOOL_VERSION_LATEST=$(curl "https://api.github.com/repos/mempool/mempool/releases/latest" -s | jq .name -r)
MEMPOOL_VERSION=$(dialog \
    --clear \
    --title "Download Mempool" \
    --inputbox "What version would you like to download?" \
    $DIALOG_HEIGHT $DIALOG_WIDTH $MEMPOOL_VERSION_LATEST \
    2>&1 >/dev/tty)
sudo -u mempool bash -c "cd; cd mempool; git checkout $MEMPOOL_VERSION"

# Setup mempool database
sudo apt install -y mariadb-server mariadb-client
#MARIADB_PASSWORD=$(gpg --gen-random --armor 1 16)

