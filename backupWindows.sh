#!/bin/bash

# Backup script for a Windows (NTFS) mountpoint within a Linux environment, by João Pedro Seara
# Last updated: Sep 1, 2025

DIR_TO_BCK="/media/`loginctl user-status | head -1 | awk '{print $1}'`/WINDOWS/Dados"
OUTPUT_DIR="/media/`loginctl user-status | head -1 | awk '{print $1}'`/STORAGE"
HOST_NAME="JP"
BACKUP_NAME="${HOST_NAME}_Windows"
NUM_BCK_TO_KEEP=3

# Verify if this script is being run as the session user and/or if directories exist

if [[ $EUID -ne `loginctl user-status | head -1 | awk '{print $2}' | grep -Eo '[0-9]*'` ]]; then
  echo "This script must be run as the session user!"
  exit 1
fi

if [ ! -d "${DIR_TO_BCK}" ]; then
  echo "Directory to back up '${DIR_TO_BCK}' does not exist!"
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

# Let's start

echo -e "\nBackup start time: "$(date "+%Y-%m-%d %H:%M:%S %Z")
start_time=$SECONDS

# Start creation of an encrypted backup (excluding some Windows system files/folders)

echo -e "\nBacking up '${DIR_TO_BCK}' into '${OUTPUT_DIR}' ...\n"
backup_timestamp=`date -u +%Y%m%d%H%M%SZ`

rm -f "${OUTPUT_DIR}"/"${BACKUP_NAME}".7z # remove any previous leftovers

7z a -t7z -mhe -ssc- -p"${ZIP_PASSPHRASE}" "${OUTPUT_DIR}"/"${BACKUP_NAME}".7z \
\
  -xr'!$Recycle.Bin/' \
  -xr'!Default.rdp' \
  -xr'!desktop.ini' \
  -xr'!Thumbs.db' \
  -xr'!System Volume Information/' \
\
  "${DIR_TO_BCK}" || { echo -e "\n7z failed!"; rm -f "${OUTPUT_DIR}"/"${BACKUP_NAME}".7z; exit 1; }

# Set permissions, add the timestamp, and show status of the generated file

chmod 644 "${OUTPUT_DIR}"/"${BACKUP_NAME}".7z
echo ""
mv "${OUTPUT_DIR}"/"${BACKUP_NAME}".7z "${OUTPUT_DIR}"/"${BACKUP_NAME}_${backup_timestamp}".7z
echo ""
stat "${OUTPUT_DIR}"/"${BACKUP_NAME}_${backup_timestamp}".7z

echo -e "\nBackup file '${BACKUP_NAME}_${backup_timestamp}.7z' created."
echo -e "\nTo decrypt and decompress the generated file: 7z x '${BACKUP_NAME}_${backup_timestamp}.7z'"
echo -e "To umount the target: sudo umount '${OUTPUT_DIR}'"

# Clean up older backups

echo -e "\nCleaning up old backups (keeping only last ${NUM_BCK_TO_KEEP}) ..."
find "${OUTPUT_DIR}" -type f -name "${BACKUP_NAME}_[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]Z.7z" | sort | head -n -${NUM_BCK_TO_KEEP} | xargs rm -f

# All done

time_elapsed=$(( SECONDS - start_time ))
eval "echo -e \\\nDone. Time taken: $(date -ud "@$time_elapsed" +'$((%s/3600)) hr %M min %S sec')"

exit 0
