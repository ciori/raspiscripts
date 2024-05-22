#!/bin/bash

# Create a named pipe. As the name suggests, this is a FIFO (first in first
# out) pipe. Everything sent in can be read out again without the content
# actually being written to a disk.
mkfifo /tmp/lnd-wallet-password-pipe

# Read the password from the manager and attempt to write it to the pipe. Any
# write to a pipe will only be accepted once there is a process that reads
# from the pipe at the same time. That's why we need to run this process in
# the background (the ampersand & at the end) because it would block our
# script from continuing otherwise.
pass lnd/wallet-password > /tmp/lnd-wallet-password-pipe &

# Start lnd
/usr/local/bin/lnd
