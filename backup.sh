#!/usr/bin/bash

# rsync backup script

log="/var/log/rsync_backup/rsync_backup_$(date +"%Y%m%d").log"
include_file="${HOME}/rsync-include.txt"
password_file="/root/backup/rsync_password.txt"
exclude_file="/root/backup/rsync_exclude.txt"
dest="rsync://rsync@qnap.lan:/Backup/$HOSTNAME"
src_list=(
    "/etc"
    "/home"
    "/opt"
    "/root"
    "/usr/local"
    "/var/lib"
)

# Start backup
{
    echo "Starting backup: $(date '+%Y-%m-%d %H:%M:%S')";
    for path in ${src_list[@]}; do
        rsync -varp --delete \
            --password-file "${password_file}" \
            --exclude-from="${exclude_file}" \
            "${path}" "${dest}";
    done
    echo "Backup completed: $(date '+%Y-%m-%d %H:%M:%S')";
} | tee -a "${log}"

# Error handling
status=$?
if [ $status -ne 0 ]; then
    echo "Rsync failed with exit code $status" | tee -a "${log}"
    exit $status
else
    echo "Rsync completed successfully." | tee -a "${log}"
fi
