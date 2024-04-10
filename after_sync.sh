#!/bin/bash

# Check whether the blockchain has finished syncing
echo "Checking whether the blockchain has finished syncing..."
BLOCKCHAIN_STATUS=$(bitcoin-cli getblockchaininfo)
if [[ $BLOCKCHAIN_STATUS == *"\"initialblockdownload\": false"* ]]; then
    # Reduce the size of the database cache after sync
    sudo -u bitcoin sed -i "s/dbcache=2000/#dbcache=2000/g" /home/bitcoin/.bitcoin/bitcoin.conf
    sudo -u bitcoin sed -i "s/blocksonly=1/#blocksonly=1/g" /home/bitcoin/.bitcoin/bitcoin.conf
    sudo systemctl restart bitcoind
    echo ""
    echo "OK, size of the Bitcoin database cache has been reduced"
    echo "You should now install other services!!!"
    echo ""
else
    echo ""
    echo "ABORT, the blockchain is still synchronizing!!!"
    echo ""
fi
