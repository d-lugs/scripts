#!/usr/bin/bash

# Initial bash script copied from:
# https://www.slingacademy.com/article/ubuntu-how-to-write-an-rsync-backup-script/

log="${HOME}/backup/rsync_backup_
.log"dest="${HOME}/backup/destination"
src="/source/directory"

# Start backup
{ 
    echo "Starting backup: $(date '+%Y-%m-%d %H:%M:%S')";
    rsync -avz --delete --exclude-from='${HOME}/rsync-exclude.txt' "${src}" "${dest}";
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