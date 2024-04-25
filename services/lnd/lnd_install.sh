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

# Download lnd
cd /tmp
LND_VERSION_LATEST=$(curl -sL https://api.github.com/repos/lightningnetwork/lnd/releases/latest | \
    grep tag_name | \
    sed 's|.*: "v||;s|",||')
LND_VERSION=$(dialog \
    --clear \
    --title "Download LND" \
    --inputbox "What version would you like to download?" \
    $DIALOG_HEIGHT $DIALOG_WIDTH $LND_VERSION_LATEST \
    2>&1 >/dev/tty)
wget https://github.com/lightningnetwork/lnd/releases/download/v${LND_VERSION}/lnd-linux-${SYS_DPKG_ARCH}-v${LND_VERSION}.tar.gz
wget https://github.com/lightningnetwork/lnd/releases/download/v${LND_VERSION}/manifest-v${LND_VERSION}.txt
wget https://github.com/lightningnetwork/lnd/releases/download/v${LND_VERSION}/manifest-roasbeef-v${LND_VERSION}.sig

# Verify the hash value
sha256sum --ignore-missing --check manifest-v${LND_VERSION}.txt
if [ $? -ne 0 ]
then
    echo ""
    echo "Hash value of lnd-linux-${SYS_DPKG_ARCH}-v${LND_VERSION}.tar.gz does not correspond"
    echo "ABORTED!!!"
    echo ""
    exit 1
fi

# Download developer gpg key (roasbeef)
curl https://raw.githubusercontent.com/lightningnetwork/lnd/master/scripts/keys/roasbeef.asc | gpg --import

# Verify gpg signature
gpg --verify manifest-roasbeef-v${LND_VERSION}.sig manifest-v${LND_VERSION}.txt
if [ $? -ne 0 ]
then
    echo ""
    echo "No good signature found from lnd developer gpg key (roasbeef)"
    echo "ABORTED!!!"
    echo ""
    exit 1
fi

# Install lnd
tar -xvf lnd-linux-${SYS_DPKG_ARCH}-v${LND_VERSION}.tar.gz
sudo install -m 0755 -o root -g root -t /usr/local/bin lnd-linux-${SYS_DPKG_ARCH}-v${LND_VERSION}/*

# Setup the lnd user
sudo adduser --gecos "" --disabled-password lnd
sudo usermod -a -G bitcoin,debian-tor lnd
sudo adduser $USER lnd

# Setup lnd data folder
mkdir ${DATA_PATH}/lnd
sudo chown lnd:lnd ${DATA_PATH}/lnd
sudo -u lnd ln -s ${DATA_PATH}/lnd /home/lnd/.lnd
sudo -u lnd ln -s ${DATA_PATH}/bitcoin /home/lnd/.bitcoin

# Configure lnd
sudo cp ${REPO_PATH}/templates/lnd/lnd.conf /data/lnd/lnd.conf
#sudo chmod 640 /data/lnd/lnd.conf
#sudo chown lnd:lnd /data/lnd/lnd.conf
LND_NODE_NAME=$(dialog \
    --clear \
    --title "LND Configuration" \
    --inputbox "Would you like to name your LND Node?\n\nInsert the name here, or leave it blank to generate a random alphanumeric string:" \
    $DIALOG_HEIGHT $DIALOG_WIDTH 0 \
    2>&1 >/dev/tty)
if [ $LND_NODE_NAME == "" ]
then
    sudo -u lnd sed -i "s/YOUR_FANCY_ALIAS/$(openssl rand -hex 16)/g" /data/lnd/lnd.conf
else
    sudo -u lnd sed -i "s/YOUR_FANCY_ALIAS/${LND_NODE_NAME}/g" /data/lnd/lnd.conf
fi

# Add lnd service, enable it and start it
sudo cp ${REPO_PATH}/templates/lnd/lnd.service /etc/systemd/system/lnd.service
sudo systemctl enable --now lnd

# Create the lnd wallet
echo ""
echo ""
echo "Now please follow the next commands to setup the LND Wallet..."
read -p "Press any key to continue" -n 1 -r -s
echo ""
echo ""
echo ""
sudo -u lnd lncli create

# Add lnd permissions to your user
ln -s ${DATA_PATH}/lnd /home/${USER}/.lnd
sudo chmod -R g+X ${DATA_PATH}/lnd/data/
sudo chmod g+r ${DATA_PATH}/lnd/data/chain/bitcoin/mainnet/admin.macaroon
