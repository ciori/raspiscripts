#!/bin/bash

#### VARIABLES ####

# Dialog parameters
DIALOG_HEIGHT=20
DIALOG_WIDTH=60

PYTHON_VERSION=3.10.15
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

# Update python
cd /tmp
wget https://www.python.org/ftp/python/${PYTHON_VERSION}/Python-${PYTHON_VERSION}.tgz
# verify package !?
# ...
tar -xvf Python-${PYTHON_VERSION}.tgz
cd Python-${PYTHON_VERSION}
./configure --enable-optimizations
sudo make altinstall
python3.10 --version

# Fetch the source code for the new version to use
sudo -u lnbits bash -c "cd; cd lnbits; git fetch; git reset --hard"
LNBITS_VERSION_LATEST=$(curl "https://api.github.com/repos/lnbits/lnbits/releases/latest" -s | jq .name -r)
LNBITS_VERSION=$(dialog \
    --clear \
    --title "Update LNbits" \
    --inputbox "What version would you like to update to?" \
    $DIALOG_HEIGHT $DIALOG_WIDTH $LNBITS_VERSION_LATEST \
    2>&1 >/dev/tty)
sudo -u lnbits bash -c "cd; cd lnbits; git checkout $LNBITS_VERSION"

# Install lnbits
sudo -u lnbits bash -c "cd; cd lnbits; /home/lnbits/.local/bin/poetry env use python${PYTHON_BIN_VERSION}; /home/lnbits/.local/bin/poetry install --only main"


#### OUTPUT ####

echo ""
echo ""
echo "LNbits has been updated to version ${LNBITS_VERSION}"
echo ""
echo ""