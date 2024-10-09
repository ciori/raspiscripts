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

# Configure user
sudo adduser --disabled-password --gecos "" mempool
sudo adduser mempool bitcoin

# Install Nodejs with nvm
sudo -u mempool -i bash -c 'curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash'
sudo tee -a /home/mempool/.profile <<EOF

export NVM_DIR="\$HOME/.nvm"
[ -s "\$NVM_DIR/nvm.sh" ] && \. "\$NVM_DIR/nvm.sh"
[ -s "\$NVM_DIR/bash_completion" ] && \. "\$NVM_DIR/bash_completion"
EOF
sudo -u mempool -i bash -c 'nvm install 20'

# Install Rust
sudo -u mempool -i bash -c "curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh"

# Allow mempool on firewall
sudo firewall-cmd --permanent --zone=public --add-port=4081/tcp
sudo firewall-cmd --reload

# Get the source code and ask for the version to use
sudo -u mempool -i bash -c "cd; git clone https://github.com/mempool/mempool"
MEMPOOL_VERSION_LATEST=$(curl "https://api.github.com/repos/mempool/mempool/releases/latest" -s | jq .name -r)
MEMPOOL_VERSION=$(dialog \
    --clear \
    --title "Download Mempool" \
    --inputbox "What version would you like to download?" \
    $DIALOG_HEIGHT $DIALOG_WIDTH $MEMPOOL_VERSION_LATEST \
    2>&1 >/dev/tty)
sudo -u mempool -i bash -c "cd; cd mempool; git checkout $MEMPOOL_VERSION"

# Setup mariadb
sudo apt install -y mariadb-server mariadb-client
MARIADB_PASSWORD=$(gpg --gen-random --armor 1 16)
sudo mysql <<EOF
create database mempool;
grant all privileges on mempool.* to 'mempool'@'localhost' identified by '${MARIADB_PASSWORD}';
EOF

# Build mempool backend
sudo -u mempool -i bash -c 'cd /home/mempool/mempool/backend; npm install --prod; npm run build'

# Configure the mempool backend
sudo cp ${SCRIPT_PATH}/../../templates/mempool/mempool-config.json /home/mempool/mempool/backend/mempool-config.json
sudo -u mempool sed -i "s/Password_M/${MARIADB_PASSWORD}/g" /home/mempool/mempool/backend/mempool-config.json
RPCAUTH_PASSWORD=$(dialog \
    --clear \
    --title "Setup Mempool Backend config credentials" \
    --passwordbox "Insert the Bitcoin RPC Auth password initially generated with the init.sh script:" \
    $DIALOG_HEIGHT $DIALOG_WIDTH \
    2>&1 >/dev/tty)
sudo -u mempool sed -i "s/Password_B/${RPCAUTH_PASSWORD}/g" /home/mempool/mempool/backend/mempool-config.json

# Build mempool frontend
sudo -u mempool -i bash -c 'cd /home/mempool/mempool/frontend; npm install --prod; npm run build'

# Configure permissions
sudo chmod 600 /home/mempool/mempool/backend/mempool-config.json

# Configure nginx for mempool
sudo rsync -av --delete /home/mempool/mempool/frontend/dist/mempool/ /var/www/mempool/
sudo chown -R www-data:www-data /var/www/mempool
sudo cp ${SCRIPT_PATH}/../../templates/mempool/mempool-ssl.conf /etc/nginx/sites-available/mempool-ssl.conf
sudo ln -sf /etc/nginx/sites-available/mempool-ssl.conf /etc/nginx/sites-enabled/
sudo rsync -av /home/mempool/mempool/nginx-mempool.conf /etc/nginx/snippets
sudo cp ${SCRIPT_PATH}/../../templates/mempool/nginx.conf /etc/nginx/nginx.conf
sudo systemctl restart nginx

# Add mempool service, enable it and start it
sudo cp ${SCRIPT_PATH}/../../templates/mempool/mempool.service /etc/systemd/system/mempool.service
sudo cp ${SCRIPT_PATH}/../../templates/mempool/mempool-start.sh /home/mempool/mempool/mempool-start.sh
sudo chown mempool:mempool /home/mempool/mempool/mempool-start.sh
sudo chmod 700 /home/mempool/mempool/mempool-start.sh
sudo systemctl daemon-reload
sudo systemctl enable --now mempool

# Enable the tor hidden service
if ! grep -q "hidden_service_mempool" /etc/tor/torrc; then
    echo "" | sudo tee -a /etc/tor/torrc
    echo "HiddenServiceDir /var/lib/tor/hidden_service_mempool/" | sudo tee -a /etc/tor/torrc
    echo "HiddenServiceVersion 3" | sudo tee -a /etc/tor/torrc
    echo "HiddenServicePort 443 127.0.0.1:4081" | sudo tee -a /etc/tor/torrc
    sudo systemctl reload tor
fi
MEMPOOL_TOR=$(sudo cat /var/lib/tor/hidden_service_mempool/hostname)

# Final output
echo ""
echo ""
echo "Mempool has been installed!!!"
echo ""
echo "The Tor hidden service is: ${MEMPOOL_TOR}"
echo "The HTTPS Port is: 4081"
echo ""
