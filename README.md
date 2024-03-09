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
2. Initialize the machine using the init script, which will:
    - prepare the machine
    - install bitcoind and start the blockchain sync
    - install cockpit and a custom plugin for monitoring and managing bitcoin and ln services
3. Manage other bitcoin and ln services from the cockpit plugin or by using scripts
