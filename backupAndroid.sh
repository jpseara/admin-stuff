#!/bin/bash

# Backup script for an Android (MTP) mountpoint within a Linux environment, by João Pedro Seara
# Last updated: Apr 25, 2026

DIR_TO_BCK="${XDG_RUNTIME_DIR}/gvfs/mtp:host=SAMSUNG_SAMSUNG_Android_R58N80JHCYJ/Cartão SD"
OUTPUT_DIR="/media/`loginctl user-status | head -1 | awk '{print $1}'`/STORAGE"
#OUTPUT_DIR="${XDG_RUNTIME_DIR}/gvfs/google-drive:host=gmail.com,user=joao.pedro.seara/O meu disco"
#TEMP_DIR="/tmp" # write the compressed bundle into this temporary directory and only then upload it to the target. Leave commented to stream the output directly into the target
HOST_NAME="JP-MOBILE"
BACKUP_NAME="${HOST_NAME}_Android"
NUM_BCK_TO_KEEP=3
ENCR_PASSFILE="/home/`loginctl user-status | head -1 | awk '{print $1}'`/.backup-passphrase" # use the content of this file as the encryption passphrase of the backup. Leave commented for an interactive passphrase prompt

cleanup() {
  rm -f /tmp/".backup_${BACKUP_NAME}_passphrase".*
  rm -f "${OUTPUT_DIR}"/"${BACKUP_NAME}".7z
  rm -f "${TEMP_DIR}"/"${BACKUP_NAME}".7z
}

# Verify if this script is being run as the session user and/or if required directories/files exist

if [[ $EUID -ne `loginctl user-status | head -1 | awk '{print $2}' | grep -Eo '[0-9]*'` ]]; then
  echo "This script must be run as the session user!"
  exit 1
fi

if [[ `pgrep -f $0` != "$$" ]]; then
  echo "Another instance of this script is already running, or you are using sudo to run it. Exiting!"
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

if [[ -v TEMP_DIR && ! -d "${TEMP_DIR}" ]]; then
  echo "Temporary directory '${TEMP_DIR}' does not exist!"
  exit 1
fi

if [[ -v ENCR_PASSFILE && ! -f "${ENCR_PASSFILE}" ]]; then
  echo "Encryption passfile '${ENCR_PASSFILE}' does not exist!"
  exit 1
fi

cleanup # remove any previous leftovers

# Ask for a backup encryption passphrase if the passfile does not exist

if [[ ! -v ENCR_PASSFILE ]]; then
  echo -e "\nPlease type a passphrase to encrypt your backup:\n"
  encr_passphrase=""
  encr_confirmation=""
  while [[ ${encr_passphrase} = "" || "${encr_passphrase}" != "${encr_confirmation}" ]]; do
    read -s -p "Encryption passphrase: " encr_passphrase
    echo ""
    read -s -p "Please confirm the passphrase: " encr_confirmation
    echo ""
  done
  ENCR_PASSFILE=$(mktemp "/tmp/.backup_${BACKUP_NAME}_passphrase.XXXXX")
  chmod 600 "${ENCR_PASSFILE}"
  printf "%s" "${encr_passphrase}" > "${ENCR_PASSFILE}"
else
  echo -e "\nUsing the encryption passphrase stored in the passfile."
fi

# Let's start

[[ -v TEMP_DIR ]] || TEMP_DIR="${OUTPUT_DIR}" # if no TEMP_DIR is set, write directly into OUTPUT_DIR

echo -e "\nBackup start time: "$(date "+%Y-%m-%d %H:%M:%S %Z")
start_time=$SECONDS

# Start creation of an encrypted backup (excluding some Android system files/folders)

echo -e "\nBacking up '${DIR_TO_BCK}' into '${OUTPUT_DIR}' ...\n"
backup_timestamp=`date -u +%Y%m%d%H%M%SZ`

7z a -t7z -mhe -p"`cat "${ENCR_PASSFILE}"`" "${TEMP_DIR}"/"${BACKUP_NAME}".7z \
\
  -xr'!.history' \
  -xr'!.thumbnails/' \
  -xr'!.MetaEcfsFile' \
  -xr'!Android/' \
\
  "${DIR_TO_BCK}" || { echo -e "\n7z failed!"; cleanup; exit 1; }

#chmod 644 "${TEMP_DIR}"/"${BACKUP_NAME}".7z

# Upload the data and show status of the generated file

if [[ "$TEMP_DIR" != "$OUTPUT_DIR" ]]; then
  echo -e "\nNow uploading data ...\n"
  #cp "${TEMP_DIR}"/"${BACKUP_NAME}".7z "${OUTPUT_DIR}"/ || { echo -e "\nUpload failed!"; cleanup; exit 1; }
  rsync -h --progress "${TEMP_DIR}"/"${BACKUP_NAME}".7z "${OUTPUT_DIR}"/ || { echo -e "\nUpload failed!"; cleanup; exit 1; }
fi
sleep 3 # let things settle in the target
mv "${OUTPUT_DIR}"/"${BACKUP_NAME}".7z "${OUTPUT_DIR}"/"${BACKUP_NAME}_${backup_timestamp}".7z
echo ""
stat "${OUTPUT_DIR}"/"${BACKUP_NAME}_${backup_timestamp}".7z

echo -e "\nBackup file '${BACKUP_NAME}_${backup_timestamp}.7z' created."
echo -e "\nTo extract the generated file: 7z x \"${OUTPUT_DIR}/${BACKUP_NAME}_${backup_timestamp}.7z\""

# Clean up temporary files and older backups

echo -e "\nCleaning up temporary files and old backups (keeping only last ${NUM_BCK_TO_KEEP}) ..."
cleanup
find "${OUTPUT_DIR}" -maxdepth 1 -type f -name "${BACKUP_NAME}_[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]Z.7z" | sort | head -n -${NUM_BCK_TO_KEEP} | xargs rm -f
gio list -d "${OUTPUT_DIR}" 2> /dev/null | grep "${BACKUP_NAME}_[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]Z.7z" | sort | head -n -${NUM_BCK_TO_KEEP} | xargs -I% rm -f "${OUTPUT_DIR}/%" # make sure deletion happens in drives with encoded names

# All done

time_elapsed=$(( SECONDS - start_time ))
eval "echo -e \\\nDone. Time taken: $(date -ud "@$time_elapsed" +'$((%s/3600)) hr %M min %S sec')"

exit 0
