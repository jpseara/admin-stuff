#!/bin/bash

# Backup script for Linux environments, by João Pedro Seara
# Last updated: Apr 25, 2026

DIR_TO_BCK="/home"
OUTPUT_DIR="/media/`loginctl user-status | head -1 | awk '{print $1}'`/STORAGE"
#OUTPUT_DIR="${XDG_RUNTIME_DIR}/gvfs/google-drive:host=gmail.com,user=joao.pedro.seara/O meu disco"
#TEMP_DIR="/tmp" # write the compressed bundle into this temporary directory and only then upload it to the target. Leave commented to stream the output directly into the target
BACKUP_OWNER="`loginctl user-status | head -1 | awk '{print $1}'`"
BACKUP_NAME="`hostname -s`_`lsb_release -is`"
NUM_BCK_TO_KEEP=3
ENCR_PASSFILE="/home/`loginctl user-status | head -1 | awk '{print $1}'`/.backup-passphrase" # use the content of this file as the encryption passphrase of the backup. Leave commented for an interactive passphrase prompt

cleanup() {
  rm -f /tmp/".backup_${BACKUP_NAME}_passphrase".*
  rm -f "${OUTPUT_DIR}"/"${BACKUP_NAME}".tgz.gpg
  rm -f "${TEMP_DIR}"/"${BACKUP_NAME}".tgz.gpg
  sudo rm -f /tmp/"${BACKUP_NAME}".tgz
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

# Validate sudo

echo -e "\nSome parts of this script will have to run as root. Validating sudo ..."
sudo -v || exit 1
echo -e "OK"

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

bak_user=`id -u "${BACKUP_OWNER}"`
bak_group=`id -g "${BACKUP_OWNER}"`

# Add some extra stuff into the backup directory, to include it in the final archive

echo -e "\nGathering some extra stuff to back up, before generating the archive ...\n"
extra_bak_dir="${DIR_TO_BCK}"/"${BACKUP_OWNER}"/Backups
mkdir -p "${extra_bak_dir}" -m 755
sudo tar --ignore-failed-read --no-wildcards-match-slash -czpf "${extra_bak_dir}"/etc.tgz /etc # saving the contents of etc
#sudo tar --ignore-failed-read --no-wildcards-match-slash -czpf "${extra_bak_dir}"/root.tgz /root # saving the contents of root
sudo chown -R ${bak_user}:${bak_group} "${extra_bak_dir}"

# Start creation of encrypted backup

echo -e "\nBacking up '${DIR_TO_BCK}' into '${OUTPUT_DIR}' ...\n"
backup_timestamp=`date -u +%Y%m%d%H%M%SZ`

# First, archive the directory and compress it
# First block of files are the specific includes
# Second block are the excludes

sudo tar --ignore-failed-read --no-wildcards-match-slash -czpf /tmp/"${BACKUP_NAME}".tgz \
\
  /home/*/.bash_aliases \
  /home/*/.bash_profile \
  /home/*/.bashrc \
  /home/*/.gitconfig \
  /home/*/.gnupg \
  /home/*/.hidden \
  /home/*/.profile \
  /home/*/.ssh \
\
  --exclude=/home/*/.* \
  --exclude=/home/*/snap \
\
  "${DIR_TO_BCK}" \
  || { echo -e "\ntar failed!"; cleanup; exit 1; }

sudo chown ${bak_user}:${bak_group} /tmp/"${BACKUP_NAME}".tgz

# Now encrypt it

gpg -c --batch --yes --passphrase-file "${ENCR_PASSFILE}" -o "${TEMP_DIR}"/"${BACKUP_NAME}".tgz.gpg /tmp/"${BACKUP_NAME}".tgz || { echo -e "\ngpg failed!"; cleanup; exit 1; }

#chmod 644 "${TEMP_DIR}"/"${BACKUP_NAME}".tgz.gpg

# Upload the data and show status of the generated file

if [[ "$TEMP_DIR" != "$OUTPUT_DIR" ]]; then
  echo -e "\nNow uploading data ...\n"
  #cp "${TEMP_DIR}"/"${BACKUP_NAME}".tgz.gpg "${OUTPUT_DIR}"/ || { echo -e "\nUpload failed!"; cleanup; exit 1; }
  rsync -h --progress "${TEMP_DIR}"/"${BACKUP_NAME}".tgz.gpg "${OUTPUT_DIR}"/ || { echo -e "\nUpload failed!"; cleanup; exit 1; }
fi
sleep 3 # let things settle in the target
mv "${OUTPUT_DIR}"/"${BACKUP_NAME}".tgz.gpg "${OUTPUT_DIR}"/"${BACKUP_NAME}_${backup_timestamp}".tgz.gpg
echo ""
stat "${OUTPUT_DIR}"/"${BACKUP_NAME}_${backup_timestamp}".tgz.gpg

echo -e "\nBackup file '${BACKUP_NAME}_${backup_timestamp}.tgz.gpg' created."
echo -e "\nTo extract the generated file (with the original permissions): gpg -d \"${OUTPUT_DIR}/${BACKUP_NAME}_${backup_timestamp}.tgz.gpg\" | sudo tar -xzpf -"

# Clean up temporary files and older backups

echo -e "\nCleaning up temporary files and old backups (keeping only last ${NUM_BCK_TO_KEEP}) ..."
cleanup
find "${OUTPUT_DIR}" -maxdepth 1 -type f -name "${BACKUP_NAME}_[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]Z.tgz.gpg" | sort | head -n -${NUM_BCK_TO_KEEP} | xargs rm -f
gio list -d "${OUTPUT_DIR}" 2> /dev/null | grep "${BACKUP_NAME}_[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]Z.tgz.gpg" | sort | head -n -${NUM_BCK_TO_KEEP} | xargs -I% rm -f "${OUTPUT_DIR}/%" # make sure deletion happens in drives with encoded names

# All done

time_elapsed=$(( SECONDS - start_time ))
eval "echo -e \\\nDone. Time taken: $(date -ud "@$time_elapsed" +'$((%s/3600)) hr %M min %S sec')"

exit 0
