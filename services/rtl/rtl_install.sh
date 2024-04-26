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

# Configure user
sudo adduser --disabled-password --gecos "" rtl
sudo adduser rtl loop
sudo cp ${DATA_PATH}/lnd/data/chain/bitcoin/mainnet/admin.macaroon /home/rtl/admin.macaroon
sudo chown rtl:rtl /home/rtl/admin.macaroon

# Install nodejs with nvm
sudo -u rtl bash -c 'curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash; export NVM_DIR="$HOME/.nvm"; [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"; nvm install 20'

# Allow rtl on firewall
sudo firewall-cmd --permanent --zone=public --add-port=4001/tcp
sudo firewall-cmd --reload

# Copy rtl nginx proxy configuration
sudo cp ${SCRIPT_PATH}/../../templates/rtl/rtl-reverse-proxy.conf /etc/nginx/streams-enabled/rtl-reverse-proxy.conf
sudo systemctl reload nginx

# Get the source code and ask for the version to use
sudo -u rtl bash -c "cd; git clone https://github.com/Ride-The-Lightning/RTL.git"
RTL_VERSION_LATEST=$(curl "https://api.github.com/repos/Ride-The-Lightning/RTL/releases/latest" -s | jq .tag_name -r)
RTL_VERSION=$(dialog \
    --clear \
    --title "Download Ride The Lightning" \
    --inputbox "What version would you like to use?" \
    $DIALOG_HEIGHT $DIALOG_WIDTH $RTL_VERSION_LATEST \
    2>&1 >/dev/tty)
sudo -u rtl bash -c "cd; cd RTL; git checkout $RTL_VERSION"

# Verify tag and abort if it fails
# ... git verify-tag $RTL_VERSION ...

# Install rtl
sudo -u rtl bash -c 'cd; cd RTL; export NVM_DIR="$HOME/.nvm"; [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"; npm install --omit=dev'

# Configure rtl
#sudo -u rtl bash -c 'cd; cd RTL; cp Sample-RTL-Config.json ./RTL-Config.json'
sudo cp ${SCRIPT_PATH}/../../templates/rtl/RTL-Config.json /home/rtl/RTL/RTL-Config.json
RTL_PASSWORD=$(dialog \
    --clear \
    --title "Setup RTL credentials" \
    --passwordbox "Please insert the RTL password you want to use to login on the web page:" \
    $DIALOG_HEIGHT $DIALOG_WIDTH \
    2>&1 >/dev/tty)
sudo -u rtl sed -i "s/PASSWORD/${RTL_PASSWORD}/g" /home/rtl/RTL/RTL-Config.json
sudo -u rtl sed -i "s#CONFIG_PATH#${DATA_PATH}/lnd/lnd.conf#g" /home/rtl/RTL/RTL-Config.json

# Add rtl service, enable it and start it
sudo cp ${SCRIPT_PATH}/../../templates/rtl/rtl.service /etc/systemd/system/rtl.service
sudo cp ${SCRIPT_PATH}/../../templates/rtl/rtl-start.sh /home/rtl/RTL/rtl-start.sh
sudo chown rtl:rtl /home/rtl/RTL/rtl-start.sh
sudo chmod 700 /home/rtl/RTL/rtl-start.sh
sudo systemctl daemon-reload
sudo systemctl enable --now rtl

# Enable the tor hidden service
sudo grep -qxF "hidden_service_rtl" /etc/tor/torrc
if [ ! $? ]; then
    echo "" | sudo tee -a /etc/tor/torrc
    echo "HiddenServiceDir /var/lib/tor/hidden_service_rtl/" | sudo tee -a /etc/tor/torrc
    echo "HiddenServiceVersion 3" | sudo tee -a /etc/tor/torrc
    echo "HiddenServicePort 443 127.0.0.1:4001" | sudo tee -a /etc/tor/torrc
    sudo systemctl reload tor
fi
RTL_TOR=$(sudo cat /var/lib/tor/hidden_service_rtl/hostname)

# Final output
echo ""
echo ""
echo "Ride The Lightning has been installed!!!"
echo ""
echo "The Tor hidden service is: ${RTL_TOR}"
echo "The HTTPS Port is: 4001"
echo ""
