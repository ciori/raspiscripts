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
sudo -u mempool bash -c 'curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash; export NVM_DIR="$HOME/.nvm"; [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"; nvm install 16'

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

# Setup mariadb
sudo apt install -y mariadb-server mariadb-client
MARIADB_PASSWORD=$(gpg --gen-random --armor 1 16)
sudo mysql <<EOF
create database mempool;
grant all privileges on mempool.* to 'mempool'@'localhost' identified by '${MARIADB_PASSWORD}';
EOF

# Build backend
sudo -u mempool bash -c 'cd /home/mempool/mempool/backend; export NVM_DIR="$HOME/.nvm"; [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"; npm install --prod; npm run build'

# Configure the mempool backend
sudo cp ${SCRIPT_PATH}/../../templates/mempool/mempool-config.json /home/mempool/mempool/backend/mempool-config.json
sudo -u mempool sed -i "s/Password_M/${MARIADB_PASSWORD}/g" /home/mempool/mempool/backend/mempool-config.json
RPCAUTH_PASSWORD=$(dialog \
    --clear \
    --title "Setup Mempool Backend config credentials" \
    --passwordbox "Insert the Bitcoin RPC Auth password initially generated with the init.sh script:" \
    $DIALOG_HEIGHT $DIALOG_WIDTH \
    2>&1 >/dev/tty)
sudo -u mempool sed -i "s/Password_B/${RPCAUTH_PASSWORD}/g" /home/mempool/mempool/backend/mempool-config.json


