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

# Install electrs build tools
sudo apt install -y cargo clang cmake

# Copy electrs nginx proxy configuration
sudo cp ${SCRIPT_PATH}/../../templates/electrs/electrs-reverse-proxy.conf /etc/nginx/streams-enabled/electrs-reverse-proxy.conf
sudo systemctl reload nginx

# Allow electrs on firewall
sudo firewall-cmd --permanent --zone=public --add-port=50002/tcp
sudo firewall-cmd --reload

# Ask for the version and download the electrs repo
cd /tmp
rm -rf electrs
ELECTRS_VERSION_LATEST=$(curl -sL https://api.github.com/repos/romanz/electrs/releases/latest | \
    grep tag_name | \
    sed 's|.*: "v||;s|",||')
ELECTRS_VERSION=$(dialog \
    --clear \
    --title "Download Electrs" \
    --inputbox "What version would you like to download? (type only the numbers, not the 'v')" \
    $DIALOG_HEIGHT $DIALOG_WIDTH $ELECTRS_VERSION_LATEST \
    2>&1 >/dev/tty)
git clone --branch v$ELECTRS_VERSION https://github.com/romanz/electrs.git
cd electrs

# Verify tag
curl https://romanzey.de/pgp.txt | gpg --import
git verify-tag v$ELECTRS_VERSION
if [ $? -ne 0 ]
then
    echo ""
    echo "No good signature found from electrs developer gpg key"
    echo "ABORTED!!!"
    echo ""
    exit 1
fi

# Build the release
cargo build --locked --release

# Install the release
sudo install -m 0755 -o root -g root -t /usr/local/bin ./target/release/electrs

# Configure user and data permissions
sudo adduser --disabled-password --gecos "" electrs
sudo adduser electrs bitcoin
sudo mkdir ${DATA_PATH}/electrs
sudo chown -R electrs:electrs ${DATA_PATH}/electrs

# Copy electrs config
sudo cp ${SCRIPT_PATH}/../../templates/electrs/electrs.conf ${DATA_PATH}/electrs/electrs.conf
sudo chown electrs:electrs ${DATA_PATH}/electrs/electrs.conf
sudo -u electrs sed -i "s#DB_DIR#db_dir = \"${DATA_PATH}/electrs/db\"#g" ${DATA_PATH}/electrs/electrs.conf

# Add electrs service, enable it and start it
sudo cp ${SCRIPT_PATH}/../../templates/electrs/electrs.service /etc/systemd/system/electrs.service
sudo sed -i "s#EXEC_START#ExecStart=/usr/local/bin/electrs --conf ${DATA_PATH}/electrs/electrs.conf#g" /etc/systemd/system/electrs.service
sudo systemctl daemon-reload
sudo systemctl enable --now electrs

# Enable the tor hidden service
sudo grep -qxF "hidden_service_electrs" /etc/tor/torrc
if [ ! $? ]; then
    echo "" | sudo tee -a /etc/tor/torrc
    echo "HiddenServiceDir /var/lib/tor/hidden_service_electrs/" | sudo tee -a /etc/tor/torrc
    echo "HiddenServiceVersion 3" | sudo tee -a /etc/tor/torrc
    echo "HiddenServicePort 50002 127.0.0.1:50002" | sudo tee -a /etc/tor/torrc
    sudo systemctl reload tor
fi
ELECTRS_TOR=$(sudo cat /var/lib/tor/hidden_service_electrs/hostname)

# Final output
echo ""
echo ""
echo "Electrs has been installed!!!"
echo ""
echo "The Tor hidden service is: ${ELECTRS_TOR}"
echo "HTTP Port: 50001"
echo "HTTPS Port: 50002"
echo ""
