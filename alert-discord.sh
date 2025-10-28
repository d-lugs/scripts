#!/bin/bash

# Send a message to Discord via POST request
# Usage: alert-discord "enter message here"
#
# Requires a variables file with the following line:
# ALERT_WEBHOOK_URL="https://discord.com/api/webhooks/<your webhook token here>"

. /root/scripts/discord-vars

MESSAGE=$@

DATA='{"content":"'$MESSAGE'"}'

curl -s -X POST \
    -H "Content-Type: application/json" \
    -d "${DATA}" \
    $ALERT_WEBHOOK_URL
