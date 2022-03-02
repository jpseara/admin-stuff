#!/bin/bash

# Backup script for Linux environments made by João Pedro Seara
# Last updated: Mar 2, 2022

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

# Unlock sudo before starting and grab the user and group ids

sudo cat /dev/null
bak_user=`id -u ${BACKUP_OWNER}`
bak_group=`id -g ${BACKUP_OWNER}`

# In this section, copy stuff that you'd like to backup into the backup directory, before starting

etc_settings_dir=${DIR_TO_BCK}/${BACKUP_OWNER}/Settings/Etc && sudo mkdir -p ${etc_settings_dir} && sudo tar --ignore-failed-read --no-wildcards-match-slash -czpf ${etc_settings_dir}/etc.tgz /etc && sudo chown -R ${bak_user}:${bak_group} ${etc_settings_dir} # Saving the contents of etc under the backup directory

# Remove any existing temporary files with the same name

sudo rm -f /tmp/"${BACKUP_NAME}".tgz

# Ask for a GPG Passphrase

echo "Please type a GPG encryption passphrase to encrypt your backup."
GPG_PASSPHRASE=""
GPG_CONFIRMATION=""
while [[ ${GPG_PASSPHRASE} = "" || ${GPG_PASSPHRASE} != ${GPG_CONFIRMATION} ]]; do
  read -s -p "GPG encryption passphrase: " GPG_PASSPHRASE
  echo ""
  read -s -p "Please confirm the passphrase: " GPG_CONFIRMATION
  echo ""
done

# Create an encrypted backup

echo "Backing up '${DIR_TO_BCK}' to '${OUTPUT_DIR}' ..."

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
  || { echo "tar failed!"; exit 1; }

sudo chown ${bak_user}:${bak_group} /tmp/"${BACKUP_NAME}".tgz

# Now encrypt it

gpg -c --batch --yes --passphrase ${GPG_PASSPHRASE} -o "${OUTPUT_DIR}"/"${BACKUP_NAME}".tgz.gpg /tmp/"${BACKUP_NAME}".tgz || { echo "gpg failed!"; rm -f /tmp/"${BACKUP_NAME}".tgz; exit 1; }

# Remove the generated temporary files

sudo rm -f /tmp/"${BACKUP_NAME}".tgz

# Show status of the generated file

stat "${OUTPUT_DIR}"/"${BACKUP_NAME}".tgz.gpg

echo "Backup file '${BACKUP_NAME}.tgz.gpg' created!"
echo "To decrypt and decompress the generated file: gpg -d '${BACKUP_NAME}'.tgz.gpg | tar -xzpf -"
echo "To umount the target: sudo umount '${OUTPUT_DIR}'"
echo "Done."

exit 0
