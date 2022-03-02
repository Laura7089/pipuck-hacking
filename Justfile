set positional-arguments := true

# Tries to guess the wifi device
export WIFI_DEV := `ip address | grep wl | head -n 1 | cut -d ':' -f 2 | xargs`

# Gets the subnet on the wifi device
SUBNET_CMD := "$(ip -o -f inet addr show $WIFI_DEV | awk '/scope global/ {print $4}')"
export ANSIBLE_HOST_KEY_CHECKING := "False"
INVENTORY := "./inventory.ini"
TOOLS_DIR := "./tools"
PACKER_DIR := "./packer"
export PACKER_PLUGIN_PATH := "./.packer.d/plugins"

# Ssh into a pi with fixes applied
ssh pi_address: _clear_known_hosts _wifi_lab
    sshpass -p raspberry ssh -oStrictHostKeyChecking=no pi@{{ pi_address }}

# Run an ansible playbook
aplay playbook +args="": _clear_known_hosts _wifi_lab
    ansible-playbook -i {{ INVENTORY }} {{ args }} {{ playbook }}

# Run an arbitrary command with ansible
ashell +CMD: _clear_known_hosts _wifi_lab
    ansible -i {{ INVENTORY }} all -a "{{ CMD }}"

# Generate an ansible inventory
ainv target_subnet=SUBNET_CMD: _wifi_lab
    #!/bin/bash
    set -eo pipefail

    before=$(mktemp)
    after=$(mktemp)

    cleanup() {
        rm $before
        rm $after
    }
    trap cleanup 0

    # from https://unix.stackexchange.com/questions/181676/output-only-the-ip-addresses-of-the-online-machines-with-nmap
    printf "Turn off any pucks you want to add to your inventory.\n"
    read -p "Press any key to resume..."
    nmap -sn -n {{ target_subnet }} -oG - | awk '/Up$/{print $2}' > $before
    printf "Turn on the pucks, then wait about 2 minutes.\n"
    read -p "Press any key to resume..."
    printf "\n\n"
    nmap -sn -n {{ target_subnet }} -oG - | awk '/Up$/{print $2}' > $after
    changes=$(comm -13 $before $after)
    if [[ -z "$changes" ]]; then
        printf "Error: No new network devices!\n"
        exit 1
    fi
    echo "$changes"
    rm -f {{ INVENTORY }}
    echo "$changes" | xargs -I {} sh -c "printf '{} ansible_ssh_user=pi ansible_ssh_pass=raspberry\n' >> {{ INVENTORY }}"

# Take an image of a connected media
snap device outfile="./rpi.img": && (shrink outfile)
    @# From https://stackoverflow.com/questions/965053/extract-filename-and-extension-in-bash
    @if [[ "{{ extension(outfile) }}" != "img" ]]; then \
        printf "WARNING: '{{ outfile }}' is not a .img file!\n"; \
        read -p "Are you sure you want to continue? [y/N]" continue; \
        if [[ $continue != "y" ]]; then \
            exit 1; \
        fi \
    fi
    sudo dd if={{ device }} of={{ outfile }} status=progress bs=64k

# Shrink an image's size
shrink image="./rpi.img":
    sudo {{ TOOLS_DIR }}/pishrink/pishrink.sh {{ image }}

# Flash an image file to a device
flash device image="./rpi.img":
    sudo dd if={{ image }} of={{ device }} status=progress bs=64k

# Flash a media with the hostname patched in
flash_host device image tmp_mount="/mnt/sd": (flash device image) #!/bin/bash
    set -euxo pipefail

    HOSTNAME_FILE="{{ tmp_mount }}/hostname"

    UUID=$(uuidgen)
    e2fsck -f /dev/sda2
    tune2fs /dev/sda2 -U ${UUID}
    mount {{ device }} {{ tmp_mount }}

    FS_UUID=$($UUID | cut -d "-" -f 2)
    echo "puck-$FS_UUID" > $HOSTNAME_FILE
    umount {{ tmp_mount }}

# Run a packer target
image target="./packer/from_raspios_remote.pkr.hcl" +args="": _packer_plugin_arm && (shrink "./output-pipuck/image")
    sudo PACKER_PLUGIN_PATH="{{ PACKER_PLUGIN_PATH }}" packer build {{ args }} "{{ target }}"

# Run a packer target in docker
dimage dockerbin="podman" target="./packer/from_raspios_remote.pkr.hcl" +args="": _packer_plugin_arm && (shrink "./output-pipuck/image")
    sudo {{ dockerbin }} run \
        -e PACKER_PLUGIN_PATH="/mnt/{{ PACKER_PLUGIN_PATH }}" \
        -v $PWD:/mnt \
        -w /mnt \
        hashicorp/packer build {{ args }} "/mnt/{{ target }}"

# Build an image from scratch
pigen:
    cd {{ TOOLS_DIR }}/pi-gen-yrl && ./build.sh

# netctl: switch to correct wifi network
wifi action="lab" network="rts_lab":
    just wifi_{{ action }} network

# netctl: switch to lab wifi
_wifi_lab network="rts_lab":
    sudo systemctl stop netctl-auto@{{ WIFI_DEV }}
    sudo netctl start {{ network }}
    sleep 2

# netctl: turn off lab wifi
_wifi_off network="rts_lab":
    sudo netctl stop {{ network }}
    sudo systemctl start netctl-auto@{{ WIFI_DEV }}
    sleep 2

# Build the packer-plugin-arm-image binary
_packer_plugin_arm:
    #!/bin/bash
    set -euxo pipefail

    if [[ -f "{{ PACKER_PLUGIN_PATH }}/packer-plugin-arm-image" ]]; then
        echo "Plugin already built..."
        exit 0
    fi

    (
        cd "{{ TOOLS_DIR }}/packer-plugin-arm-image"
        export "GOPATH=$(mktemp -d)"
        go generate ./...
        go build -o packer-plugin-arm-image .
    )
    install -Dm 0755 "{{ TOOLS_DIR }}/packer-plugin-arm-image/packer-plugin-arm-image" "{{ PACKER_PLUGIN_PATH }}/packer-plugin-arm-image"

# Clear the hosts in INVENTORY from ~/.ssh/known_hosts
_clear_known_hosts inv=INVENTORY:
    #!/bin/bash
    set -euxo pipefail

    while read line; do
        ip=$(echo "$line" | cut -d " " -f 1)
        sed -i "/$ip/d" ~/.ssh/known_hosts
    done < {{ inv }}
