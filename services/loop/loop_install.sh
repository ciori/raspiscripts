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

# Download loop
cd /tmp
LOOP_VERSION_LATEST=$(curl https://api.github.com/repos/lightninglabs/loop/releases/latest -s | jq .tag_name -r)
LOOP_VERSION=$(dialog \
    --clear \
    --title "Download Loop" \
    --inputbox "What version would you like to download?" \
    $DIALOG_HEIGHT $DIALOG_WIDTH $LOOP_VERSION_LATEST \
    2>&1 >/dev/tty)
wget https://github.com/lightninglabs/loop/releases/download/${LOOP_VERSION}/loop-linux-${SYS_DPKG_ARCH}-${LOOP_VERSION}.tar.gz
wget https://github.com/lightninglabs/loop/releases/download/${LOOP_VERSION}/manifest-${LOOP_VERSION}.txt
wget https://github.com/lightninglabs/loop/releases/download/${LOOP_VERSION}/manifest-${LOOP_VERSION}.txt.sig

# Verify the hash value
sha256sum --ignore-missing --check manifest-${LOOP_VERSION}.txt
if [ $? -ne 0 ]
then
    echo ""
    echo "Hash value of loop-linux-${SYS_DPKG_ARCH}-${LOOP_VERSION}.tar.gz does not correspond"
    echo "ABORTED!!!"
    echo ""
    exit 1
fi

# Download developer gpg key
curl -s "https://keys.openpgp.org/vks/v1/by-fingerprint/DE23E73BFA8A0AD5587D2FCDE80D2F3F311FD87E" | gpg --import

# Verify gpg signature
gpg --verify manifest-${LOOP_VERSION}.txt.sig manifest-${LOOP_VERSION}.txt
if [ $? -ne 0 ]
then
    echo ""
    echo "No good signature found from loop developer gpg key"
    echo "ABORTED!!!"
    echo ""
    exit 1
fi

# Install loop
tar -xvf loop-linux-${SYS_DPKG_ARCH}-${LOOP_VERSION}.tar.gz
sudo install -m 0755 -o root -g root -t /usr/local/bin loop-linux-${SYS_DPKG_ARCH}-${LOOP_VERSION}/*

# Configure users and permissions
sudo adduser --disabled-password --gecos "" loop
sudo adduser $USER loop
sudo adduser loop lnd
sudo -u loop ln -s ${DATA_PATH}/lnd /home/loop/.lnd
# ...

# Add loopd service, enable it and start it
sudo cp ${SCRIPT_PATH}/../../templates/loop/loopd.service /etc/systemd/system/loopd.service
sudo systemctl daemon-reload
sudo systemctl enable --now loopd
