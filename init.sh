#!/bin/bash

#### VARIABLES ####

# Dialog parameters
DIALOG_HEIGHT=20
DIALOG_WIDTH=60


#### INIT ####

# Set repository path
REPO_PATH=$(pwd)

# Update system
sudo apt update -y
sudo apt upgrade -y
sudo apt autoremove -y

# Get system information
SYS_DPKG_ARCH=$(dpkg --print-architecture)
SYS_UNAME_ARCH=$(uname -m)
SYS_VERSION=$(lsb_release -c | grep Codename | awk -F' ' '{print $2}')

# Install packages
sudo apt install -y wget curl vim gpg apt-transport-https dialog

# Setup data disk permissions
DATA_PATH=$(dialog \
    --clear \
    --title "Initialize the Data Directory" \
    --inputbox "Enter the absolute path where you want to store the node data:" \
    $DIALOG_HEIGHT $DIALOG_WIDTH "/data" \
    2>&1 >/dev/tty)
# check if folder exists
sudo chown ${USER}:${USER} $DATA_PATH


#### FIREWALL ####

# Setup a general firewalld configuration
sudo apt install -y firewalld
sudo firewall-cmd --permanent --zone=public --add-service=ssh
sudo firewall-cmd --permanent --zone=public --remove-service=dhcpv6-client
sudo firewall-cmd --reload


#### TOR ####

# Add repos and keys
sudo cp ${REPO_PATH}/templates/tor/tor.list /etc/apt/sources.list.d/tor.list
sudo sed -i "s/SYS_ARCH/${SYS_DPKG_ARCH}/g" /etc/apt/sources.list.d/tor.list
sudo sed -i "s/SYS_VERSION/${SYS_VERSION}/g" /etc/apt/sources.list.d/tor.list
wget -qO- https://deb.torproject.org/torproject.org/A3C4F0F979CAA22CDBA8F512EE8CBC9E886DDD89.asc | gpg --dearmor | sudo tee /usr/share/keyrings/tor-archive-keyring.gpg >/dev/null

# Install tor
sudo apt update -y
sudo apt install -y tor deb.torproject.org-keyring

# Configure and enable the tor service
sudo cp ${REPO_PATH}/templates/tor/torrc /etc/tor/torrc
sudo systemctl enable --now tor
sudo systemctl restart tor


#### NGINX ####

# Install nginx
sudo apt install -y nginx libnginx-mod-stream

# Create the self signed certificate
sudo openssl req -x509 -nodes -newkey rsa:4096 \
    -keyout /etc/ssl/private/nginx-selfsigned.key \
    -out /etc/ssl/certs/nginx-selfsigned.crt \
    -subj "/CN=localhost" \
    -days 3650

# Configure and enable the nginx service
sudo cp ${REPO_PATH}/templates/nginx/nginx.conf /etc/nginx/nginx.conf
sudo mkdir /etc/nginx/streams-enabled
sudo systemctl enable --now nginx
sudo systemctl restart nginx


#### BITCOIN ####

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

# Setup the bitcoin user
sudo adduser --gecos "" --disabled-password bitcoin
sudo adduser $USER bitcoin
sudo adduser bitcoin debian-tor

# Setup bitcoin data folder
mkdir ${DATA_PATH}/bitcoin
sudo chown bitcoin:bitcoin ${DATA_PATH}/bitcoin
sudo -u bitcoin ln -s ${DATA_PATH}/bitcoin /home/bitcoin/.bitcoin

# Generate the rpcauth credential
cd /home/bitcoin/.bitcoin
sudo -u bitcoin wget https://raw.githubusercontent.com/bitcoin/bitcoin/master/share/rpcauth/rpcauth.py
RPCAUTH_PASSWORD=$(dialog \
    --clear \
    --title "Generate Bitcoin RPC Auth credential" \
    --passwordbox "Insert the password used to generate the credential:" \
    $DIALOG_HEIGHT $DIALOG_WIDTH \
    2>&1 >/dev/tty)
RPCAUTH_OUTPUT=$(sudo -u bitcoin python3 rpcauth.py bitcoin $RPCAUTH_PASSWORD)
unset $RPCAUTH_PASSWORD
RPCAUTH_STRING=$(echo "$RPCAUTH_OUTPUT" | grep rpcauth)
unset $RPCAUTH_OUTPUT

# Configure bitcoin
sudo cp ${REPO_PATH}/templates/bitcoind/bitcoin.conf /home/bitcoin/.bitcoin/bitcoin.conf
sudo chown bitcoin:bitcoin /home/bitcoin/.bitcoin/bitcoin.conf
sudo -u bitcoin sed -i "s/RPCAUTH/${RPCAUTH_STRING}/g" /home/bitcoin/.bitcoin/bitcoin.conf
BITCOIN_PRUNE=$(dialog \
    --clear \
    --title "Bitcoin Configuration" \
    --inputbox "Would you like to setup Bitcoin with pruning?\n\nInsert the pruning value here, or leave 0 to NOT enable pruning:" \
    $DIALOG_HEIGHT $DIALOG_WIDTH 0 \
    2>&1 >/dev/tty)
if [ $BITCOIN_PRUNE -eq 0 ]
then
    sudo -u bitcoin sed -i "s/PRUNE/# Pruning is disabled/g" /home/bitcoin/.bitcoin/bitcoin.conf
    sudo -u bitcoin sed -i "s/TXINDEX/txindex=1/g" /home/bitcoin/.bitcoin/bitcoin.conf
else
    sudo -u bitcoin sed -i "s/PRUNE/prune=${BITCOIN_PRUNE}/g" /home/bitcoin/.bitcoin/bitcoin.conf
    sudo -u bitcoin sed -i "s/TXINDEX/#txindex=1 Disabled with pruning/g" /home/bitcoin/.bitcoin/bitcoin.conf
fi
sudo -u bitcoin chmod 640 /home/bitcoin/.bitcoin/bitcoin.conf

# Test start bitcoin and add read permissions
sudo -u bitcoin timeout 5 bitcoind
sudo -u bitcoin chmod g+r ${DATA_PATH}/bitcoin/debug.log
sudo chmod g+rx /home/bitcoin
ln -s ${DATA_PATH}/bitcoin /home/${USER}/.bitcoin

# Add bitcoind service, enable it and start it
sudo cp ${REPO_PATH}/templates/bitcoind/bitcoind.service /etc/systemd/system/bitcoind.service
sudo systemctl enable --now bitcoind


#### COCKPIT ####

# # Install cockpit
# sudo apt install -y cockpit

# # Configure cockpit to listen on port 443 and restart the socket
# sudo mkdir -p /etc/systemd/system/cockpit.socket.d
# sudo cp ${REPO_PATH}/templates/cockpit/listen.conf /etc/systemd/system/cockpit.socket.d/listen.conf
# sudo systemctl daemon-reload
# sudo systemctl restart cockpit.socket

# # Allow cockpit on firewall
# sudo firewall-cmd --permanent --zone=public --add-service=https
# sudo firewall-cmd --reload

# # Add the bitcoin cockpit plugin
# # ...


#### CONFS ####

# Save useful variables in a file
touch ${REPO_PATH}/envs
grep -qxF "DATA_PATH=${DATA_PATH}" ${REPO_PATH}/envs || echo "DATA_PATH=${DATA_PATH}" >> ${REPO_PATH}/envs
sed -i "/DATA_PATH/c\DATA_PATH=${DATA_PATH}" ${REPO_PATH}/envs


#### NETWORK ####

# # Setup the Network

# # Let Network Manager manage the interfaces and reboot the system
# sudo apt install -y network-manager
# sudo mv /etc/network/interfaces /etc/network/interfaces.backup
# sudo systemctl enable --now NetworkManager
# sudo systemctl restart NetworkManager
# echo ""
# echo "The Blockchain Sync has been started..."
# echo ""
# echo "THE SYSTEM WILL NOW REBOOT -> The IP address will probably change!!!"
# echo ""
# sudo reboot now
