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

# Download bitcoin core
cd /tmp
BITCOIN_VERSION_LATEST=$(curl -sL https://api.github.com/repos/bitcoin/bitcoin/releases/latest | \
    grep tag_name | \
    sed 's|.*: "v||;s|",||')
BITCOIN_VERSION=$(dialog \
    --clear \
    --title "Download Bitcoin" \
    --inputbox "What version would you like to download?" \
    $DIALOG_HEIGHT $DIALOG_WIDTH $BITCOIN_VERSION_LATEST \
    2>&1 >/dev/tty)
wget https://bitcoincore.org/bin/bitcoin-core-${BITCOIN_VERSION}/bitcoin-${BITCOIN_VERSION}-${SYS_UNAME_ARCH}-linux-gnu.tar.gz
wget https://bitcoincore.org/bin/bitcoin-core-${BITCOIN_VERSION}/SHA256SUMS
wget https://bitcoincore.org/bin/bitcoin-core-${BITCOIN_VERSION}/SHA256SUMS.asc

# Verify the hash value
sha256sum --ignore-missing --check SHA256SUMS
if [ $? -ne 0 ]
then
    echo ""
    echo "Hash value of bitcoin-${BITCOIN_VERSION}-${SYS_UNAME_ARCH}-linux-gnu.tar.gz does not correspond"
    echo "ABORTED!!!"
    echo ""
    exit 1
fi

# Download developers gpg keys
curl -s "https://api.github.com/repositories/355107265/contents/builder-keys" | \
    grep download_url | \
    grep -oE "https://[a-zA-Z0-9./-]+" | \
    while read url; do curl -s "$url" | gpg --import; done

# Verify gpg signature
gpg --verify SHA256SUMS.asc
if [ $? -ne 0 ]
then
    echo ""
    echo "No good signature found from bitcoin core developers gpg keys"
    echo "ABORTED!!!"
    echo ""
    exit 1
fi

# Install bitcoind
tar -xvf bitcoin-${BITCOIN_VERSION}-${SYS_UNAME_ARCH}-linux-gnu.tar.gz
sudo install -m 0755 -o root -g root -t /usr/local/bin bitcoin-${BITCOIN_VERSION}/bin/*

# Restart the bitcoind service
sudo systemctl restart bitcoind


#### OUTPUT ####

echo ""
echo ""
echo "Bitcoin Core has been updated to ${BITCOIN_VERSION}"
echo ""
echo ""
