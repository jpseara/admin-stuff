#!/bin/bash

# Backup script for the Windows mountpoint, by João Pedro Seara
# Last updated: May 7, 2022

DIR_TO_BCK="/media/`loginctl user-status | head -1 | awk '{print $1}'`/WINDOWS/Dados"
OUTPUT_DIR="/media/`loginctl user-status | head -1 | awk '{print $1}'`/STORAGE"
BACKUP_OWNER="`loginctl user-status | head -1 | awk '{print $1}'`"
BACKUP_NAME="Windows"

# Verify if this script is being run as root and/or if directories exist

if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root or using sudo!"
  exit 1
fi

if [ ! -d "${DIR_TO_BCK}" ]; then
  echo "Directory to backup '${DIR_TO_BCK}' does not exist!"
  exit 1
fi

if [ ! -d "${OUTPUT_DIR}" ]; then
  echo "Destination directory '${OUTPUT_DIR}' does not exist!"
  exit 1
fi

# Ask for a 7z Passphrase

echo -e "\nPlease type a 7z encryption passphrase to encrypt your backup:\n"
ZIP_PASSPHRASE=""
ZIP_CONFIRMATION=""
while [[ ${ZIP_PASSPHRASE} = "" || "${ZIP_PASSPHRASE}" != "${ZIP_CONFIRMATION}" ]]; do
  read -s -p "7z encryption passphrase: " ZIP_PASSPHRASE
  echo ""
  read -s -p "Please confirm the passphrase: " ZIP_CONFIRMATION
  echo ""
done

# Grab the user and group ids

bak_user=`id -u "${BACKUP_OWNER}"`
bak_group=`id -g "${BACKUP_OWNER}"`

# Create a backup timestamp and move previous backups to the side

date +%Y%m%d%H%M%S > "${DIR_TO_BCK}"/.backup_timestamp
mv -f "${OUTPUT_DIR}"/"${BACKUP_NAME}".7z "${OUTPUT_DIR}"/"${BACKUP_NAME}".7z.old 2> /dev/null

# Start creation of an encrypted backup

echo -e "\nBacking up '${DIR_TO_BCK}' to '${OUTPUT_DIR}' ...\n"

7z a -t7z -mhe -p"${ZIP_PASSPHRASE}" "${OUTPUT_DIR}"/"${BACKUP_NAME}".7z "${DIR_TO_BCK}" || { echo -e "\n7z failed!"; mv -f "${OUTPUT_DIR}"/"${BACKUP_NAME}".7z.old "${OUTPUT_DIR}"/"${BACKUP_NAME}".7z 2> /dev/null; rm -f "${DIR_TO_BCK}"/.backup_timestamp; exit 1; }

# Remove the timestamp and previous backups

rm -f "${OUTPUT_DIR}"/"${BACKUP_NAME}".7z.old
rm -f "${DIR_TO_BCK}"/.backup_timestamp

# Show status of the generated file

chown ${bak_user}:${bak_group} "${OUTPUT_DIR}"/"${BACKUP_NAME}".7z
echo ""
stat "${OUTPUT_DIR}"/"${BACKUP_NAME}".7z

echo -e "\nBackup file '${BACKUP_NAME}.7z' created."
echo -e "\nTo decrypt and decompress the generated file: 7z x '${BACKUP_NAME}.7z'"
echo -e "To umount the target: sudo umount '${OUTPUT_DIR}'"
echo -e "\nDone."

exit 0
