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

# Stop mempool
sudo systemctl stop mempool

# Update nodejs with nvm
sudo -u mempool -i bash -c 'curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash'
sudo -u mempool -i bash -c '. "$NVM_DIR/nvm.sh"; nvm install 20'
sudo -u mempool -i bash -c '. "$NVM_DIR/nvm.sh"; nvm alias default 20'

# Update Rust
sudo -u mempool -i bash -c 'rustup update'

# Fetch the source code for the new version to use
sudo -u mempool -i bash -c "cd; cd mempool; git fetch; git reset --hard"
MEMPOOL_VERSION_LATEST=$(curl "https://api.github.com/repos/mempool/mempool/tags" -s | jq '.|=sort_by(.name)' | jq .[].name -r | tail -1)
MEMPOOL_VERSION=$(dialog \
    --clear \
    --title "Download Mempool" \
    --inputbox "What version would you like to download?" \
    $DIALOG_HEIGHT $DIALOG_WIDTH $MEMPOOL_VERSION_LATEST \
    2>&1 >/dev/tty)
sudo -u mempool -i bash -c "cd; cd mempool; git checkout $MEMPOOL_VERSION"

# Build mempool backend
sudo -u mempool -i bash -c 'cd /home/mempool/mempool/backend; npm install --prod; npm run build'

# Build mempool frontend
sudo rm -rf /home/mempool/mempool/frontend/node_modules
sudo -u mempool -i bash -c 'cd /home/mempool/mempool/frontend; npm install --prod; npm run build'

# Configure nginx for mempool
sudo rsync -av --delete /home/mempool/mempool/frontend/dist/mempool/ /var/www/mempool/
sudo chown -R www-data:www-data /var/www/mempool
sudo rsync -av /home/mempool/mempool/nginx-mempool.conf /etc/nginx/snippets
sudo systemctl restart nginx

# Start mempool
sudo systemctl start mempool


#### OUTPUT ####

echo ""
echo ""
echo "Mempool has been updated to version ${MEMPOOL_VERSION}"
echo ""
echo ""