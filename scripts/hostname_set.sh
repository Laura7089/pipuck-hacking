#!/bin/sh

HOSTNAME_FILE="/etc/hostname"

if [ -n "$(cat $HOSTNAME_FILE)" ] || [ "$(cat $HOSTNAME_FILE)" = "pi-puck" ]; then
    echo "Hostname already set to $(cat $HOSTNAME_FILE)"
    exit 0
fi

root_dev=$(mount | grep "on / " | cut -d " " -f 1)
fs_uuid=$(lsblk -no UUID "$root_dev")
uuid_part=$(echo "$fs_uuid" | cut -d "-" -f 2)

hostname="pi-$uuid_part"
echo "$hostname" > HOSTNAME_FILE
