#!/bin/bash

# Reduce the size of the database cache after sync
sudo -u bitcoin sed -i "s/dbcache=2000/#dbcache=2000/g" /home/bitcoin/.bitcoin/bitcoin.conf
sudo -u bitcoin sed -i "s/blocksonly=1/#blocksonly=1/g" /home/bitcoin/.bitcoin/bitcoin.conf
sudo systemctl restart bitcoind
