#!/bin/bash

dd status=progress if=$1 of=/dev/sda
echo "Image written"

echo "Mounting /mnt/sd"
mount /dev/sda1 /mnt/sd

HOSTNAME_FILE="/mnt/sd/hostname"


root_dev=$(mount | grep "on / " | cut -d " " -f 1)

fs_uuid=$(lsblk -no UUID "/dev/sda2" | cut -d "-" -f 2)

hostname="puck-$fs_uuid"
echo "Setting hostname to '$hostname'..."
echo "$hostname" > $HOSTNAME_FILE

umount /mnt/sd
echo "Unmounted /mnt/sd"
