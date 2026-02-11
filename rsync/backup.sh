#!/usr/bin/bash

# rsync backup script
# Usage: ./backup.sh [OPTIONS]
# Required environment variables
#   RSYNC_HOST
#   RSYNC_PASSWORD
# Options:
#   -a, --alert   Send discord alert (optional) requires the following variables:
#                   USERID              Discord user id (for tagging)
#                   ALERT_WEBHOOK_URL   Discord webhook URL

# Get absolute path of script
path=$( cd "$(dirname "${BASH_SOURCE[0]}")" ; pwd -P)
cd $path

log_file="/var/log/rsync/backup_$(date +"%Y%m%d").log"
include_file="./include.txt"
exclude_file="./exclude.txt"

# parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -a|--alert)
            notify="true"
            shift # past argument
            shift # past value
            ;;
        -*|--*)
            echo "Unknown option $1"
            exit 1
            ;;
        *)
            POSITIONAL_ARGS+=("$1") # save positional arg
            shift # past argument
            ;;
    esac
done

send_alert() {
    if [ "$notify" == "true" ]; then
        local DISCORD_USERID ALERT_WEBHOOK_URL
        . .env

        msg="$@"
        echo $msg

        curl -s -X POST \
            -F "username=$HOSTNAME" \
            -F 'content="<@'"$DISCORD_USERID"'>
'"$msg"'"' \
            $ALERT_WEBHOOK_URL

        if [ $? -ne 0 ]; then
            echo -e "Failed to send Discord alert"
        fi
    else
        echo -e $1
    fi
}

check_failure(){
    status=$?
    if [ $status -ne 0 ]; then
        send_alert "ERROR: Rsync backup failed (exit code: $status)"
        exit 1
    fi
}

{
    . .env
    export RSYNC_PASSWORD=$RSYNC_PASSWORD

    start_time=$(date +"%s")
    echo "$(date '+%Y/%m/%d %H:%M:%S') Starting backup"
    rsync -arp --delete --relative \
        --files-from="${include_file}" \
        --exclude-from="${exclude_file}" \
        --log-file="${log_file}" \
        "/" "rsync://rsync@$RSYNC_HOST:/Backup/$HOSTNAME"
    check_failure
    send_alert "$(date '+%Y/%m/%d %H:%M:%S') Backup completed (Time elapsed: $(($(date +"%s")-$start_time)) seconds)"
} | tee -a "$log_file" 2>&1

exit 0
