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
sudo apt install -y python3-virtualenv python3-venv curl python3-dev python3-pip build-essential automake pkg-config libtool libgmp-dev libltdl-dev libssl-dev libatlas3-base libopenjp2-7

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
sudo chown -R joinmarket:joinmarket /home/joinmarket/joinmarket-clientserver-${JM_VERSION}
sudo -u joinmarket bash -c "cd /home/joinmarket; ln -s joinmarket-clientserver-${JM_VERSION} joinmarket"
sudo -u joinmarket bash -c "cd /home/joinmarket/joinmarket; ./install.sh --without-qt --disable-secp-check --disable-os-deps-check"

# Configure joinmarket
sudo cp ${SCRIPT_PATH}/../../templates/joinmarket/activate.sh /home/joinmarket/activate.sh
sudo chmod 740 /home/joinmarket/activate.sh
sudo chown joinmarket:joinmarket /home/joinmarket/activate.sh
sudo -u joinmarket bash -c "cd /home/joinmarket; . activate.sh; ./wallet-tool.py"
sudo sed -i "/rpc_user/c\#rpc_user = bitcoin"  ${DATA_PATH}/joinmarket/joinmarket.cfg
sudo sed -i "/rpc_password/c\#rpc_password = password" ${DATA_PATH}/joinmarket/joinmarket.cfg
sudo sed -i "/rpc_cookie_file/c\rpc_cookie_file = ${DATA_PATH}/bitcoin/.cookie" ${DATA_PATH}/joinmarket/joinmarket.cfg
sudo sed -i "/onion_serving_port/c\onion_serving_port = 8090" ${DATA_PATH}/joinmarket/joinmarket.cfg


#### SETUP JAM ####

# Configure user
sudo adduser --disabled-password --gecos "" jam

# Install nodejs with nvm
sudo -u jam bash -c 'curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash; export NVM_DIR="$HOME/.nvm"; [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"; nvm install 16'

# Configure joinmarket for jam
sudo sed -i "/max_cj_fee_rel/c\max_cj_fee_rel = 0.00003" ${DATA_PATH}/joinmarket/joinmarket.cfg
sudo sed -i "/max_cj_fee_abs/c\max_cj_fee_abs = 600" ${DATA_PATH}/joinmarket/joinmarket.cfg
sudo -u joinmarket bash -c 'cd /home/joinmarket/.joinmarket; mkdir ssl/ && cd "$_"; openssl req -newkey rsa:4096 -x509 -sha256 -days 3650 -nodes -out cert.pem -keyout key.pem -subj "/CN=localhost"'

# Configure nginx
sudo cp ${SCRIPT_PATH}/../../templates/joinmarket/jam-reverse-proxy.conf /etc/nginx/streams-enabled/jam-reverse-proxy.conf
sudo systemctl reload nginx

# Allow jam on firewall
sudo firewall-cmd --permanent --zone=public --add-port=4020/tcp
sudo firewall-cmd --reload

# Get the jam source code and ask for the version to use
sudo -u jam bash -c 'curl https://dergigi.com/PGP.txt | gpg --import'
sudo -u jam bash -c "cd; git clone https://github.com/joinmarket-webui/jam.git"
JAM_VERSION_LATEST=$(curl "https://api.github.com/repos/joinmarket-webui/jam/releases/latest" -s | jq .name -r | awk '{print $1;}')
JAM_VERSION=$(dialog \
    --clear \
    --title "Download Jam" \
    --inputbox "What version would you like to download?" \
    $DIALOG_HEIGHT $DIALOG_WIDTH $JAM_VERSION_LATEST \
    2>&1 >/dev/tty)
sudo -u jam bash -c "cd; cd jam; git checkout tags/${JAM_VERSION}; git verify-tag ${JAM_VERSION}"

# Install jam
sudo -u jam bash -c 'cd; cd jam; export NVM_DIR="$HOME/.nvm"; [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"; npm install'
sudo -u jam bash -c "cd; cd jam; touch .env"
sudo -u jam bash -c 'grep -qxF "PORT=3020" /home/jam/jam/.env || echo "PORT=3020" >> /home/jam/jam/.env'

# Setup systemd services
sudo cp ${SCRIPT_PATH}/../../templates/joinmarket/jmwalletd.service /etc/systemd/system/jmwalletd.service
sudo cp ${SCRIPT_PATH}/../../templates/joinmarket/obwatcher.service /etc/systemd/system/obwatcher.service
sudo cp ${SCRIPT_PATH}/../../templates/joinmarket/jam.service /etc/systemd/system/jam.service
sudo cp ${SCRIPT_PATH}/../../templates/joinmarket/jam-start.sh /home/jam/jam/jam-start.sh
sudo chown jam:jam /home/jam/jam/jam-start.sh
sudo chmod 700 /home/jam/jam/jam-start.sh
sudo systemctl daemon-reload
sudo systemctl enable --now jmwalletd
sudo systemctl enable --now obwatcher
sudo systemctl enable --now jam

# Enable the tor hidden service
if ! grep -q "hidden_service_jam" /etc/tor/torrc; then
    echo "" | sudo tee -a /etc/tor/torrc
    echo "HiddenServiceDir /var/lib/tor/hidden_service_jam/" | sudo tee -a /etc/tor/torrc
    echo "HiddenServiceVersion 3" | sudo tee -a /etc/tor/torrc
    echo "HiddenServicePort 443 127.0.0.1:4020" | sudo tee -a /etc/tor/torrc
    sudo systemctl reload tor
fi
JAM_TOR=$(sudo cat /var/lib/tor/hidden_service_jam/hostname)

# Final output
echo ""
echo ""
echo "Joinmarket and Jam has been installed!!!"
echo ""
echo "The Tor hidden service is: ${JAM_TOR}"
echo "HTTPS Port: 4020"
echo ""
