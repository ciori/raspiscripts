#!/usr/bin/bash

# Initialize the system with all the necessary parts

# update and install packages
sudo apt update -y && sudo apt full-upgrade -y && sudo autoremove -y
sudo apt install -y vim tree curl wget gpg git --install-recommends

