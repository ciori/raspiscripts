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

# Copy needed lnd files
sudo cp /home/lnd/.lnd/tls.cert /home/mempool/lnd-tls.cert
sudo cp /home/lnd/.lnd/data/chain/bitcoin/mainnet/readonly.macaroon /home/mempool/lnd-readonly.macaroon
sudo chown mempool:mempool /home/mempool/lnd-tls.cert
sudo chown mempool:mempool /home/mempool/lnd-readonly.macaroon

# Enable lightning integration
sudo -u mempool bash -c "jq '.LIGHTNING.ENABLED = true' /home/mempool/mempool/backend/mempool-config.json > /home/mempool/temp.json"
sudo -u mempool bash -c "cp /home/mempool/temp.json /home/mempool/mempool/backend/mempool-config.json"
sudo -u mempool bash -c "rm -f /home/mempool/temp.json"

# Restart the mempool service
sudo systemctl restart mempool

# Final output
echo ""
echo ""
echo "LND integration has been added to Mempool!!!"
echo ""
echo ""
