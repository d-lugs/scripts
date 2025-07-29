#!/bin/bash

# Little bash script to gracefully update apt packages and docker containers.
# Usage: ./update.sh [OPTIONS]
# Options:
#
# -a    Send discord alert (optional) - requires alert-discord script be added to /bin

if [ "$1" == "-a" ]; then
    NOTIFY="true"
elif [ -z $1 ]; then
    NOTIFY="false"
else
    echo -e "Invalid option: $1"
    exit 1
fi

send_alert() {
    if [ "$NOTIFY" == "true" ]; then
        alert-discord "$1"
        if [ $? -ne 0 ]; then
            echo -e "Failed to send Discord alert"
        fi
    else
        echo -e $1
    fi
}

check_failure() {
        if [ $? -ne 0 ]; then
                MESSAGE="Error updating: Failed to $1."
                send_alert $MESSAGE
                exit 1
        fi
}

pull_updates() {
        echo -e "Updating package list..."
        sudo apt update
        check_failure "update package lists"

        for stack in "${STACK_LIST[@]}";
        do
                echo -e "\nPulling images for stack: $stack"
                docker compose -f "/opt/$stack/docker-compose.yaml" pull
                check_failure "pull images for stack: $stack"
        done
}

stop_stacks() {
        echo -e "\nStopping containers..."
        for stack in "${STACK_LIST[@]}";
        do
                echo -e "\nStopping stack: $stack"
                docker compose -p "$stack" down
                check_failure "stop stack: $stack"
        done
}

upgrade_apt_packages() {
        echo -e "\nUpgrading installed packages..."
        sudo apt upgrade -y
        check_failure "upgrade packages"

        echo -e "\nRemoving unnecessary packages..."
        sudo apt autoremove -y
        check_failure "remove unnecessary packages"

        echo -e "\nCleaning up package cache..."
        sudo apt clean
        check_failure "clean package cache"
}

start_stacks() {
        for stack in "${STACK_LIST[@]}";
        do
                echo -e "\nStarting stack: $stack"
                docker compose -f "/opt/$stack/docker-compose.yaml" up --force-recreate --build -d
                check_failure "start stack: $stack"
        done
}

prune_images() {
        echo -e "\nPruning old images..."
        docker image prune -f
        check_failure "prune images"
}

# list all running Docker stacks
STACK_LIST+=($(docker compose ls | grep running | awk '{print $1}'))

pull_updates $STACK_LIST

stop_stacks $STACK_LIST

upgrade_apt_packages

start_stacks $STACK_LIST

prune_images

send_alert "Update successful!"
exit 0
