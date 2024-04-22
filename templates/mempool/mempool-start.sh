#!/bin/bash

export NVM_DIR="/home/mempool/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
node --max-old-space-size=2048 dist/index.js
