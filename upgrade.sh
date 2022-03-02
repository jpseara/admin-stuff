#!/bin/bash

# Ubuntu upgrade script for Ubuntu made by João Pedro Seara
# Last updated: Mar 2, 2022

# Unlock sudo before starting

sudo cat /dev/null

# Update packages, snaps and firmware

sudo apt clean && sudo apt update && sudo apt dist-upgrade -y && sudo apt autoremove -y --purge
sudo snap refresh
sudo fwupdmgr refresh -y --force && sudo fwupdmgr update -y

exit 0
