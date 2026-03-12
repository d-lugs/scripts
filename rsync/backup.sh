#!/usr/bin/bash

# rsync backup script
# Usage: ./backup.sh [OPTIONS]
# Required environment variables
#   RSYNC_HOST
#   RSYNC_PASSWORD
# Options:
#   -a, --alert      Send discord alert (optional) requires the following variables:
#                      USERID              Discord user id (for tagging)
#                      ALERT_WEBHOOK_URL   Discord webhook URL
#   -b, --background Run rsync in the background and exit immediately

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
            ;;
        -b|--background)
            background="true"
            shift # past argument
            ;;
        --dry-run)
            testmode="true"
            options+="--list-only"
            shift
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
        local DISCORD_USERID ALERT_WEBHOOK_URL TEST_WEBHOOK_URL
        . .env

        if [ "$testmode" == "true" ]; then
            WEBHOOK_URL="$TEST_WEBHOOK_URL"
        else
            WEBHOOK_URL="$ALERT_WEBHOOK_URL"
        fi

        # ensure escape characters are interpreted in alert
        echo -e "$@"
        msg=$(echo -e "<@$DISCORD_USERID>\n$@")

        curl -s -X POST \
            -F "username=$HOSTNAME" \
            -F 'content="'"$msg"'"' \
            $WEBHOOK_URL

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
        if [ $status -eq 23 ]; then
            # extract failed files from the log
            failed_files=$(grep -E "(rsync: |IO error encountered|file has vanished)" "$log_file" | \
                grep -v "total size is" | \
                sed -n 's/.*"\(.*\)".*/\1/p' | \
                head -n 20)
            if [ -n "$failed_files" ]; then
                msg="ERROR: Rsync backup partially failed (exit code: 23)\nSome files were not backed up:\n\`\`\`\n$failed_files\n\`\`\`"
            else
                msg="ERROR: Rsync backup partially failed (exit code: 23)\nCheck log file: $log_file"
            fi
            send_alert "$msg"
        else
            send_alert "ERROR: Rsync backup failed (exit code: $status)"
        fi
    fi
}

run_backup() {
    . .env
    export RSYNC_PASSWORD=$RSYNC_PASSWORD

    start_time=$(date +"%s")
    echo "$(date '+%Y/%m/%d %H:%M:%S') Starting backup"
    rsync -arp --delete --relative \
        --files-from="${include_file}" \
        --exclude-from="${exclude_file}" \
        --log-file="${log_file}" \
        $options \
        "/" "rsync://rsync@$RSYNC_HOST:/Backup/$HOSTNAME"
    check_failure
    send_alert "$(date '+%Y/%m/%d %H:%M:%S') Backup completed (Time elapsed: $(($(date +"%s")-$start_time)) seconds)"
}

if [ "$background" == "true" ]; then
    # Run in background, redirect output to log file
    echo "Starting backup in background. Log file: $log_file"
    echo "PID will be written to: /tmp/rsync_backup.pid"
    nohup bash -c "$(declare -f run_backup); $(declare -f check_failure); $(declare -f send_alert); run_backup" >> "$log_file" 2>&1 &
    echo $! > /tmp/rsync_backup.pid
    echo "Background process started with PID: $!"
else
    # Run in foreground
    run_backup | tee -a "$log_file" 2>&1
fi

exit 0
