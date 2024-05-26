# Raspiscripts

Create and manage your Bitcoin and Lightning Network node, based on Raspibolt, but with scripts.

## Why?

I decided to create this project because of some "limitations" that I was encountering with other similar projects:
- Why not **Raspibolt**? Because I wanted something more **automated** and **faster** to use
- Why not **Raspiblitz**? Beacause I didn't want to be **limited** by their release schedule and I wanted to **tune** some things based on my liking, and sometimes the overall architecture was just getting in my way.
- Why not any **other** plug-and-play software? Because they are usually **not** Bitcoin **specific**, plus I wanted something not **container** based.

Therefore this project is just a bunch of **scripts** and **templates** to install and update a Bitcoin Node and its related services.

## Services and Features

Here is the list of what is included:
- Bitcoin Core
- Electrs
- Mempool (only mainnet info)
- LND
- RTL (with integrated loop daemon for swaps)
- JoinMarket and the JAM web UI

## CAUTION !!!

**!!! This is still in development and not all scripts are already available !!!**

Some important things about this project:
- Even though the name contains "Raspi...", it is recommended **NOT** to use a Raspberry Pi or other **Single Board Computers** as they are not that reliable, instead **learn** about **Proxmox**, with which you can have multiple Virtual Machines and properly manage Storage and Backups.
- As stated before, this project is just a bunch of scripts and templates to automate what you would normally do with Raspibolt, so they are not really tested to be idempotent, so **use at your own risk**: install services only once and then update them with the specific script.
- This is **Highly Experimental** and not thoroughly tested, therefore YOU need to watch out for incompatibilities and changes between versions and during updates. I repeat: ***this is just an automated version of what Raspibolt already offers***.
- The scripts have been design to work with a **Debian 12 x86_64 system** (not arm) and only tested to work when **executed** from inside the **root** folder of the cloned **repository**.

## Requirements

You need to provide:
- A **fresh Debian 12 x86_64** machine
- A **user** with **sudo** access with your preferred SSH login configuration
- An already available **directory** where to store the node **data**

## Setup

1. Clone the repo inside your machine:
    ```
    cd
    git clone https://github.com/ciori/raspiscripts.git
    cd raspiscripts
    ```
2. Initialize the node using the init script, which will prepare the machine with some necessary stuff and then install bitcoind and start the blockchain sync:
    ```
    ./init.sh
    ```
3. Then, it is recommended to reboot the system:
    ```
    sudo reboot now
    ```
4. Now **wait** for the blockchain sync to finish ***Tick Tock Next Block...*** and then run the script to update some parameters that were useful only during syncing:
    ```
    cd ~/raspiscripts
    ./after_sync.sh
    ```
5. Finally, install the Bitcoin and LN services you want by using the other scripts, in this order: Electrs -> Mempool -> LND -> loop -> RTL. JoinMarket can be installed right after the blockchain has finished syncing.
    ```
    # Example
    cd ~/raspiscripts
    ./services/<SERVICE_NAME>/<SERVICE_NAME>_install.sh
    ```

Some useful notes:
- All relevant node data will be stored on the directory you specify during the first installation.
- The init script will create an `env` file inside the repo folder (not the data folder) where it will save some needed environment variables, like the path of the data folder, that will be used by the "install" and "update" scripts.

## Updates

The update process should be straightforward:
1. Update your debian system as you normally would.
2. Use the specific update script for the service you want to update:
    ```
    # Example
    cd ~/raspiscripts
    ./services/<SERVICE_NAME>/<SERVICE_NAME>_update.sh
    ```
