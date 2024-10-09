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

# Update Rust
# sudo apt purge -y cargo rustc
# sudo apt autoremove -y
sudo -u mempool -i bash -c 'rustup update'

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
cargo clean
cargo build --locked --release

# Install the release
sudo install -m 0755 -o root -g root -t /usr/local/bin ./target/release/electrs

# Restart the electrs service
sudo systemctl enable --now electrs


#### OUTPUT ####

echo ""
echo ""
echo "Electrs has been updated to version v${ELECTRS_VERSION}"
echo ""
echo ""
