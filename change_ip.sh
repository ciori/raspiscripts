#!/bin/bash

#### VARIABLES ####

# Dialog parameters
DIALOG_HEIGHT=20
DIALOG_WIDTH=60


#### SCRIPT ####

# Show current IP address and ask to change it
IP_ADDRESS=$(hostname -I)
CHANGE_FLAG=$(dialog \
    --clear \
    --title "Change IP Address" \
    --yesno "Your current IP address is ${IP_ADDRESS}, would you like to change it?" \
    $DIALOG_HEIGHT $DIALOG_WIDTH \
    2>&1 >/dev/tty)

# Ask if the user wants a DHCP or static IP
if [ CHANGE_FLAG ]
then
    IP_TYPE=$(dialog \
        --clear \
        --title "Change IP Address" \
        --menu "What type of IP address do you want??" \
        $DIALOG_HEIGHT $DIALOG_WIDTH "Automatic (DHCP)" "Manual (Static)" \
        2>&1 >/dev/tty)
    echo $IP_TYPE
fi