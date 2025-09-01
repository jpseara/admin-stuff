#!/bin/bash

# Backup script for Linux environments, by João Pedro Seara
# Last updated: Sep 1, 2025

DIR_TO_BCK="/home"
OUTPUT_DIR="/media/`loginctl user-status | head -1 | awk '{print $1}'`/STORAGE"
BACKUP_OWNER="`loginctl user-status | head -1 | awk '{print $1}'`"
BACKUP_NAME="`hostname -s`_`lsb_release -is`"
NUM_BCK_TO_KEEP=3

# Verify if this script is being run as root and/or if directories exist

if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root or using sudo!"
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

# Ask for a GPG Passphrase

echo -e "\nPlease type a GPG encryption passphrase to encrypt your backup:\n"
GPG_PASSPHRASE=""
GPG_CONFIRMATION=""
while [[ ${GPG_PASSPHRASE} = "" || "${GPG_PASSPHRASE}" != "${GPG_CONFIRMATION}" ]]; do
  read -s -p "GPG encryption passphrase: " GPG_PASSPHRASE
  echo ""
  read -s -p "Please confirm the passphrase: " GPG_CONFIRMATION
  echo ""
done

# Let's start

echo -e "\nBackup start time: "$(date "+%Y-%m-%d %H:%M:%S %Z")
start_time=$SECONDS

bak_user=`id -u "${BACKUP_OWNER}"`
bak_group=`id -g "${BACKUP_OWNER}"`

# Add some extra stuff into the backup directory, to include it in the final archive

echo -e "\nGathering some extra stuff to back up, before generating the archive ...\n"
extra_bak_dir="${DIR_TO_BCK}"/"${BACKUP_OWNER}"/Backups
mkdir -p "${extra_bak_dir}" -m 755
tar --ignore-failed-read --no-wildcards-match-slash -czpf "${extra_bak_dir}"/etc.tgz /etc # saving the contents of etc
#tar --ignore-failed-read --no-wildcards-match-slash -czpf "${extra_bak_dir}"/root.tgz /root # saving the contents of root
chown -R ${bak_user}:${bak_group} "${extra_bak_dir}"

# Start creation of encrypted backup

echo -e "\nBacking up '${DIR_TO_BCK}' into '${OUTPUT_DIR}' ...\n"
backup_timestamp=`date -u +%Y%m%d%H%M%SZ`

rm -f "${OUTPUT_DIR}"/"${BACKUP_NAME}".tgz.gpg /tmp/"${BACKUP_NAME}".tgz # remove any previous leftovers

# First, archive the directory and compress it
# First block of files are the specific includes
# Second block are the excludes

tar --ignore-failed-read --no-wildcards-match-slash -czpf /tmp/"${BACKUP_NAME}".tgz \
\
  "${DIR_TO_BCK}"/*/.bash_aliases \
  "${DIR_TO_BCK}"/*/.bash_profile \
  "${DIR_TO_BCK}"/*/.bashrc \
  "${DIR_TO_BCK}"/*/.gitconfig \
  "${DIR_TO_BCK}"/*/.gnupg \
  "${DIR_TO_BCK}"/*/.hidden \
  "${DIR_TO_BCK}"/*/.profile \
  "${DIR_TO_BCK}"/*/.ssh \
\
  --exclude="${DIR_TO_BCK}"/*/.* \
  --exclude="${DIR_TO_BCK}"/*/snap \
\
  "${DIR_TO_BCK}" \
  || { echo -e "\ntar failed!"; rm -f /tmp/"${BACKUP_NAME}".tgz; exit 1; }

chown ${bak_user}:${bak_group} /tmp/"${BACKUP_NAME}".tgz

# Now encrypt it

gpg -c --batch --yes --passphrase "${GPG_PASSPHRASE}" -o "${OUTPUT_DIR}"/"${BACKUP_NAME}".tgz.gpg /tmp/"${BACKUP_NAME}".tgz || { echo -e "\ngpg failed!"; rm -f "${OUTPUT_DIR}"/"${BACKUP_NAME}".tgz.gpg; rm -f /tmp/"${BACKUP_NAME}".tgz; exit 1; }

# Set permissions/ownership, add the timestamp, and show status of the generated file

chown ${bak_user}:${bak_group} "${OUTPUT_DIR}"/"${BACKUP_NAME}".tgz.gpg
chmod 644 "${OUTPUT_DIR}"/"${BACKUP_NAME}".tgz.gpg
mv "${OUTPUT_DIR}"/"${BACKUP_NAME}".tgz.gpg "${OUTPUT_DIR}"/"${BACKUP_NAME}_${backup_timestamp}".tgz.gpg
echo ""
stat "${OUTPUT_DIR}"/"${BACKUP_NAME}_${backup_timestamp}".tgz.gpg

echo -e "\nBackup file '${BACKUP_NAME}_${backup_timestamp}.tgz.gpg' created."
echo -e "\nTo decrypt and decompress the generated file with the original permissions: gpg -d '${BACKUP_NAME}_${backup_timestamp}.tgz.gpg' | sudo tar -xzpf -"
echo -e "To umount the target: sudo umount '${OUTPUT_DIR}'"

# Clean up temporary files and older backups

echo -e "\nCleaning up temporary files and old backups (keeping only last ${NUM_BCK_TO_KEEP}) ..."
rm -f /tmp/"${BACKUP_NAME}".tgz
find "${OUTPUT_DIR}" -type f -name "${BACKUP_NAME}_[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]Z.tgz.gpg" | sort | head -n -${NUM_BCK_TO_KEEP} | xargs rm -f

# All done

time_elapsed=$(( SECONDS - start_time ))
eval "echo -e \\\nDone. Time taken: $(date -ud "@$time_elapsed" +'$((%s/3600)) hr %M min %S sec')"

exit 0
