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

# Get current lnd version
LND_VERSION_CURRENT=$(lncli --version | cut -d " " -f 3)

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

# Stop lnd
sudo systemctl stop lnd.service

# Install lnd
tar -xvf lnd-linux-${SYS_DPKG_ARCH}-v${LND_VERSION}.tar.gz
sudo install -m 0755 -o root -g root -t /usr/local/bin lnd-linux-${SYS_DPKG_ARCH}-v${LND_VERSION}/*

# Restart lnd
sudo systemctl restart lnd.service

# Final Output
echo ""
echo ""
echo "LND has been updated from version v${LND_VERSION_CURRENT} to v${LND_VERSION}"
echo ""
echo ""
