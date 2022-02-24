set positional-arguments := true

INVENTORY := "./inventory.ini"
SUBNET_CMD := `ip -o -f inet addr show wlan0 | awk '/scope global/ {print $4}'`
export ANSIBLE_HOST_KEY_CHECKING := "False"

# Run an ansible playbook
aplay playbook:
    ansible-playbook -i {{ INVENTORY }} {{ playbook }}

# Run an arbitrary command with ansible
ashell +CMD:
    ansible -i {{ INVENTORY }} all -a "{{ CMD }}"

# Generate an ansible inventory
ainv target_subnet=SUBNET_CMD:
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
    sudo ./tools/pishrink/pishrink.sh {{ image }}

# Flash an image file to a device
flash device image="./rpi.img":
    sudo dd if={{image}} of={{device}} status=progress bs=64k

# Run a packer target
image target="./packer/from_raspios_remote.pkr.hcl" +args="": _ssh_key && (shrink "./output-pipuck/image")
    sudo packer build {{args}} "{{target}}"

# Build an image from scratch
pigen:
    cd ./tools/pi-gen-yrl && ./build.sh

# Generate a temporary ssh keyfile
_ssh_key dest="./.packer_ssh.key":
    rm -f "{{dest}}"
    ssh-keygen -f "{{dest}}" -N '""'
