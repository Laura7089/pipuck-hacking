#!/bin/sh
set -ex

HOSTNAME_FILE="/etc/hostname"
CURRENT_HOSTNAME=$(hostnamectl hostname)

# If hostname is not "pi-puck" and not blank, don't change it
if [ "$CURRENT_HOSTNAME" != "pi-puck" ] && [ -n "$CURRENT_HOSTNAME" ]; then
    echo "Hostname already set to '$CURRENT_HOSTNAME'"
    exit 0
fi

root_dev=$(mount | grep "on / " | cut -d " " -f 1)
fs_uuid=$(lsblk -no UUID "$root_dev")
uuid_part=$(echo "$fs_uuid" | cut -d "-" -f 2)

hostname="pi-$uuid_part"
echo "Setting hostname to '$hostname'..."
hostnamectl set-hostname "$hostname"
