#!/bin/bash

# Backup script for Linux environments made by João Pedro Seara
# Last updated: Apr 14, 2022

DIR_TO_BCK=/home
OUTPUT_DIR=/media/jpseara/STORAGE
BACKUP_OWNER=$(whoami)
BACKUP_NAME=Ubuntu

# Verify if directories exist

if [ ! -d "${DIR_TO_BCK}" ]; then
  echo "Directory to backup '${DIR_TO_BCK}' does not exist!"
  exit 1
fi

if [ ! -d "${OUTPUT_DIR}" ]; then
  echo "Destination directory '${OUTPUT_DIR}' does not exist!"
  exit 1
fi

# Unlock sudo before starting and grab the user and group ids, also clean some existing leftovers from previous backups

sudo cat /dev/null || exit 1
bak_user=`id -u ${BACKUP_OWNER}`
bak_group=`id -g ${BACKUP_OWNER}`
sudo rm -f /tmp/"${BACKUP_NAME}".tgz

# Ask for a GPG Passphrase

echo -e "\nPlease type a GPG encryption passphrase to encrypt your backup:\n"
GPG_PASSPHRASE=""
GPG_CONFIRMATION=""
while [[ ${GPG_PASSPHRASE} = "" || ${GPG_PASSPHRASE} != ${GPG_CONFIRMATION} ]]; do
  read -s -p "GPG encryption passphrase: " GPG_PASSPHRASE
  echo ""
  read -s -p "Please confirm the passphrase: " GPG_CONFIRMATION
  echo ""
done

# In this section, copy stuff that you'd like to backup into the backup directory, before starting

echo -e "\nGathering some data to back up, before starting the archiving ...\n"
etc_settings_dir=${DIR_TO_BCK}/${BACKUP_OWNER}/Settings/Etc && sudo mkdir -p ${etc_settings_dir} && sudo tar --ignore-failed-read --no-wildcards-match-slash -czpf ${etc_settings_dir}/etc.tgz /etc && sudo chown -R ${bak_user}:${bak_group} ${etc_settings_dir} # Saving the contents of etc under the backup directory

# Create an encrypted backup

echo -e "\nBacking up '${DIR_TO_BCK}' to '${OUTPUT_DIR}' ...\n"

# Archive it and compress it first
# First block of files are the specific includes
# Second block are the excludes

sudo tar --ignore-failed-read --no-wildcards-match-slash -czpf /tmp/"${BACKUP_NAME}".tgz \
\
  "${DIR_TO_BCK}"/*/.bash_profile \
  "${DIR_TO_BCK}"/*/.bashrc \
  "${DIR_TO_BCK}"/*/.profile \
  "${DIR_TO_BCK}"/*/.gitconfig \
  "${DIR_TO_BCK}"/*/.gnupg \
  "${DIR_TO_BCK}"/*/.ssh \
\
  --exclude="${DIR_TO_BCK}/*/.*" \
  --exclude="${DIR_TO_BCK}/*/snap" \
\
  "${DIR_TO_BCK}" \
  || { echo -e "\ntar failed!"; exit 1; }

sudo chown ${bak_user}:${bak_group} /tmp/"${BACKUP_NAME}".tgz

# Now encrypt it

gpg -c --batch --yes --passphrase ${GPG_PASSPHRASE} -o "${OUTPUT_DIR}"/"${BACKUP_NAME}".tgz.gpg /tmp/"${BACKUP_NAME}".tgz || { echo -e "\ngpg failed!"; rm -f /tmp/"${BACKUP_NAME}".tgz; exit 1; }

# Remove the generated temporary files

sudo rm -f /tmp/"${BACKUP_NAME}".tgz

# Show status of the generated file

stat "${OUTPUT_DIR}"/"${BACKUP_NAME}".tgz.gpg

echo -e "\nBackup file '${BACKUP_NAME}.tgz.gpg' created."
echo -e "\nTo decrypt and decompress the generated file with the original permissions: sudo bash -c 'gpg -d \"${BACKUP_NAME}\".tgz.gpg | sudo tar -xzpf -'"
echo -e "To umount the target: sudo umount '${OUTPUT_DIR}'"
echo -e "\nDone."

exit 0
