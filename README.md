# Raspiscripts

Create and manage your Bitcoin and Lightning Network node, based on Raspibolt, but with scripts.

**!!! Highly Experimental !!!**

**(Testing on Debian 12)**

## Requirements

You need to provide:
- Fresh Debian 12 machine
- User with sudo access with your preferred ssh login configuration
- Already available directory where to store the node data

## Idea

1. Clone repo
2. Initialize the machine using the `init.sh` script, which will:
    - prepare the machine
    - install bitcoind and start the blockchain sync
    - install a web app to manage the node (TODO: cockpit with a custom bitcoin plugin or a new dedicated web app)
    - reboot the system
3. The machine will probably change IP based on your DHCP (some network changes have been done internally)
4. Wait for the blockchain to finish syncing and then run the `after_sync.sh` script
4. Install and/or update the bitcoin and ln services by using the other scripts (TODO: or from the cockpit plugin)
