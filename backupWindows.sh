#!/bin/bash

# Backup script for a Windows (NTFS) mountpoint within a Linux environment, by João Pedro Seara
# Last updated: Dec 1, 2023

DIR_TO_BCK="/media/`loginctl user-status | head -1 | awk '{print $1}'`/WINDOWS/Dados"
OUTPUT_DIR="/media/`loginctl user-status | head -1 | awk '{print $1}'`/STORAGE"
BACKUP_NAME="JP_Windows"

# Verify if this script is being run as the session user and/or if directories exist

if [[ $EUID -ne `loginctl user-status | head -1 | awk '{print $2}' | grep -Eo '[0-9]*'` ]]; then
  echo "This script must be run as the session user!"
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

start_time=$SECONDS

# Create a backup timestamp and move previous backups to the side

date +%Y%m%d%H%M%S > "${DIR_TO_BCK}"/.backup_timestamp
mv -f "${OUTPUT_DIR}"/"${BACKUP_NAME}".7z "${OUTPUT_DIR}"/"${BACKUP_NAME}".7z.old 2> /dev/null

# Start creation of an encrypted backup (excluding some Windows system files/folders)

echo -e "\nBacking up '${DIR_TO_BCK}' into '${OUTPUT_DIR}/${BACKUP_NAME}.7z' ...\n"

7z a -t7z -mhe -ssc- -p"${ZIP_PASSPHRASE}" "${OUTPUT_DIR}"/"${BACKUP_NAME}".7z \
\
  -xr'!$Recycle.Bin/' \
  -xr'!Default.rdp' \
  -xr'!desktop.ini' \
  -xr'!Thumbs.db' \
  -xr'!System Volume Information/' \
\
  "${DIR_TO_BCK}" || { echo -e "\n7z failed!"; mv -f "${OUTPUT_DIR}"/"${BACKUP_NAME}".7z.old "${OUTPUT_DIR}"/"${BACKUP_NAME}".7z 2> /dev/null; rm -f "${DIR_TO_BCK}"/.backup_timestamp; exit 1; }

# Remove the timestamp and previous backups

rm -f "${OUTPUT_DIR}"/"${BACKUP_NAME}".7z.old
rm -f "${DIR_TO_BCK}"/.backup_timestamp

# Show status of the generated file

chmod 644 "${OUTPUT_DIR}"/"${BACKUP_NAME}".7z
echo ""
stat "${OUTPUT_DIR}"/"${BACKUP_NAME}".7z

time_elapsed=$(( SECONDS - start_time ))

echo -e "\nBackup file '${BACKUP_NAME}.7z' created."
echo -e "\nTo decrypt and decompress the generated file: 7z x '${BACKUP_NAME}.7z'"
echo -e "To umount the target: sudo umount '${OUTPUT_DIR}'"
eval "echo -e \\\nDone. Time taken: $(date -ud "@$time_elapsed" +'$((%s/3600)) hr %M min %S sec')"

exit 0
