#!/bin/bash

#### VARIABLES ####

# Dialog parameters
DIALOG_HEIGHT=20
DIALOG_WIDTH=60

PYTHON_VERSION=3.10.14
PYTHON_BIN_VERSION=3.10


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

# Configure user
sudo adduser --disabled-password --gecos "" lnbits
sudo adduser lnbits lnd

# Setup lnbits data folders
mkdir -p ${DATA_PATH}/lnbits
sudo chown lnbits:lnbits -R ${DATA_PATH}/lnbits
sudo -u lnbits bash -c "ln -s ${DATA_PATH}/lnd /home/lnbits/.lnd"
sudo -u lnbits bash -c "ln -s ${DATA_PATH}/lnbits /home/lnbits/.lnbits"

# Allow lnbits on firewall
sudo firewall-cmd --permanent --zone=public --add-port=4003/tcp
sudo firewall-cmd --reload

# Copy lnbits nginx proxy configuration
sudo cp ${SCRIPT_PATH}/../../templates/lnbits/lnbits-reverse-proxy.conf /etc/nginx/streams-enabled/lnbits-reverse-proxy.conf
sudo systemctl reload nginx

# Install needed python 3.9 from tarball
sudo apt update -y
sudo apt install -y software-properties-common build-essential libnss3-dev zlib1g-dev libgdbm-dev libncurses5-dev libssl-dev libffi-dev libreadline-dev libsqlite3-dev libbz2-dev
cd /tmp
wget https://www.python.org/ftp/python/${PYTHON_VERSION}/Python-${PYTHON_VERSION}.tgz
# verify package !?
# ...
tar -xvf Python-${PYTHON_VERSION}.tgz
cd Python-${PYTHON_VERSION}
./configure --enable-optimizations
sudo make altinstall
python3.9 --version

# Install needed python 3.9 from ppa
# sudo apt update -y
# sudo apt install -y software-properties-common python3-launchpadlib
# sudo add-apt-repository -y ppa:deadsnakes/ppa
# sudo apt install python3.9 python3.9-distutils

# Install poetry for the lnbits user
sudo -u lnbits bash -c 'curl -sSL https://install.python-poetry.org | python3 -'

# Get the source code and ask for the version to use
sudo -u lnbits bash -c "cd; git clone https://github.com/lnbits/lnbits"
LNBITS_VERSION_LATEST=$(curl "https://api.github.com/repos/lnbits/lnbits/releases/latest" -s | jq .name -r)
LNBITS_VERSION=$(dialog \
    --clear \
    --title "Download LNbits" \
    --inputbox "What version would you like to download?" \
    $DIALOG_HEIGHT $DIALOG_WIDTH $LNBITS_VERSION_LATEST \
    2>&1 >/dev/tty)
sudo -u lnbits bash -c "cd; cd lnbits; git checkout $LNBITS_VERSION"

# Install lnbits
sudo -u lnbits bash -c "cd; cd lnbits; poetry env use python${PYTHON_BIN_VERSION}; poetry install --only main"

# Configure lnbits
sudo -u lnbits bash -c "cd; cd lnbits; cp .env.example .env"
# ...
