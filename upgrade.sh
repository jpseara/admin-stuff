#!/bin/bash

# Upgrade script for Linux made by João Pedro Seara
# Last updated: Mar 12, 2022

# Unlock sudo before starting

sudo cat /dev/null

# Update packages, snaps and firmware

echo -e "\nUpgrading packages ...\n"
sudo apt clean && sudo apt update && sudo apt dist-upgrade -y && sudo apt autoremove -y --purge && sudo apt purge -y '~c'
#sudo yum clean all && sudo yum check-update && sudo yum upgrade -y && sudo yum autoremove -y

echo -e "\nUpgrading snaps ...\n"
sudo snap refresh

echo -e "\nUpgrading firmware ...\n"
sudo fwupdmgr refresh -y --force && sudo fwupdmgr update -y

echo -e "\nDone."

exit 0
