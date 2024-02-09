#!/bin/bash

# Upgrade script for Linux, by João Pedro Seara
# Last updated: Feb 9, 2024

# Verify if this script is being run as root

if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root or using sudo!"
  exit 1
fi

# Update packages, snaps, and firmware

echo -e "\nUpgrading packages ...\n"
which apt > /dev/null 2>&1 && (apt clean && apt update && apt upgrade -y && apt-mark minimize-manual -y && apt autoremove -y --purge && apt purge -y '~c')
which yum > /dev/null 2>&1 && (yum clean all && yum makecache && yum upgrade -y && yum autoremove -y)

echo -e "\nUpgrading snaps ...\n"
snap refresh

echo -e "\nUpgrading firmware ...\n"
fwupdmgr refresh -y --force && fwupdmgr update -y

echo -e "\nDone."

exit 0
