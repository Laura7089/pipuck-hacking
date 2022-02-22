set positional-arguments := true

INVENTORY := "./inventory.ini"
SUBNET_CMD := `ip -o -f inet addr show wlan0 | awk '/scope global/ {print $4}'`
export ANSIBLE_HOST_KEY_CHECKING := "False"

# Run an ansible playbook
play playbook="./playbooks/default.yml":
    ansible-playbook -i {{ INVENTORY }} {{ playbook }}

# Run an arbitrary command with ansible
shell +CMD:
    ansible -i {{ INVENTORY }} all -a "{{ CMD }}"

# Generate an ansible inventory
inv target_subnet=SUBNET_CMD:
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
snap device outfile="./rpi.img":
    @# From https://stackoverflow.com/questions/965053/extract-filename-and-extension-in-bash
    @if [[ "{{ extension(outfile) }}" != "img" ]]; then \
        printf "WARNING: '{{ outfile }}' is not a .img file!\n"; \
        read -p "Are you sure you want to continue? [y/N]" continue; \
        if [[ $continue != "y" ]]; then \
            exit 1; \
        fi \
    fi
    sudo dd if={{ device }} of={{ outfile }} status=progress bs=64k
    ./tools/pishrink/pishrink.sh {{ outfile }}

# Generate an image with packer
image +args="./packer/default.pkr.hcl":
    sudo packer build {{args}}
