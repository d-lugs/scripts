#!/usr/bin/bash

# rsync backup script

log_file="/var/log/rsync/backup_$(date +"%Y%m%d").log"
include_file="/root/rsync/include.txt"
exclude_file="/root/rsync/exclude.txt"

. .env

# Start backup
echo "Starting backup: $(date '+%Y-%m-%d %H:%M:%S')"
rsync -varp --delete --relative \
    --files-from="${include_file}" \
    --exclude-from="${exclude_file}" \
    --password-file="${password_file}" \
    --log-file="${log_file}" \
    "/" "rsync://rsync@qnap.lan:/Backup/$HOSTNAME"
status=$?
echo "Backup completed: $(date '+%Y-%m-%d %H:%M:%S')"

# Error handling
if [ $status -ne 0 ]; then
    echo "Rsync failed with exit code $status" | tee -a "${log_file}"
    exit $status
else
    echo "Rsync completed successfully." | tee -a "${log_file}"
fi
