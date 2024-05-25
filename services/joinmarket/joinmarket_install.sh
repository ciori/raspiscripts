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


#### SETUP JOINMARKET ####

# Install dependencies
sudo apt install python3-virtualenv curl python3-dev python3-pip build-essential automake pkg-config libtool libgmp-dev libltdl-dev libssl-dev libatlas3-base libopenjp2-7

# Create the wallet
bitcoin-cli -named createwallet wallet_name=jm_wallet descriptors=false

# Setup users, folders and permissions
sudo adduser --disabled-password --gecos "" joinmarket
sudo usermod -a -G bitcoin,debian-tor joinmarket
sudo mkdir ${DATA_PATH}/joinmarket
sudo chown -R joinmarket:joinmarket ${DATA_PATH}/joinmarket
sudo -u joinmarket ln -s ${DATA_PATH}/joinmarket /home/joinmarket/.joinmarket
sudo -u joinmarket ln -s ${DATA_PATH}/bitcoin /home/joinmarket/.bitcoin

# Download joinmarket
cd /tmp
JM_VERSION_LATEST=$(curl -sL https://api.github.com/repos/JoinMarket-Org/joinmarket-clientserver/releases/latest | \
    grep tag_name | \
    sed 's|.*: "v||;s|",||')
JM_VERSION=$(dialog \
    --clear \
    --title "Download JoinMarket" \
    --inputbox "What version would you like to download?" \
    $DIALOG_HEIGHT $DIALOG_WIDTH $JM_VERSION_LATEST \
    2>&1 >/dev/tty)
wget -O joinmarket-clientserver-${JM_VERSION}.tar.gz https://github.com/JoinMarket-Org/joinmarket-clientserver/archive/v${JM_VERSION}.tar.gz
wget https://github.com/JoinMarket-Org/joinmarket-clientserver/releases/download/v${JM_VERSION}/joinmarket-clientserver-${JM_VERSION}.tar.gz.asc

# Download developer gpg keys
curl https://raw.githubusercontent.com/JoinMarket-Org/joinmarket-clientserver/master/pubkeys/AdamGibson.asc | gpg --import
curl https://raw.githubusercontent.com/JoinMarket-Org/joinmarket-clientserver/master/pubkeys/KristapsKaupe.asc | gpg --import

# Verify gpg signature
gpg --verify joinmarket-clientserver-${JM_VERSION}.tar.gz.asc
if [ $? -ne 0 ]
then
    echo ""
    echo "No good signature found from joinmarket developer gpg keys"
    echo "ABORTED!!!"
    echo ""
    exit 1
fi

# Install joinmarket
sudo tar -xvzf joinmarket-clientserver-${JM_VERSION}.tar.gz -C /home/joinmarket/
sudo -u joinmarket ln -s joinmarket-clientserver-${JM_VERSION} joinmarket
sudo -u joinmarket bash -c "cd /home/joinmarket/joinmarket; ./install.sh --without-qt --disable-secp-check --disable-os-deps-check"





#### SETUP JAM ####

# ...


# Final output
echo ""
echo ""
echo "Joinmarket and Jam has been installed!!!"
echo ""
echo "The Tor hidden service is: ${JAM_TOR}"
echo "HTTP Port: xxxx"
echo "HTTPS Port: xxxx"
echo ""