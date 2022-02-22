set positional-arguments

INVENTORY := "./inventory.ini"
SUBNET_CMD := "$(ip -o -f inet addr show wlan0 | awk '/scope global/ {print $4}')"

# Run an ansible playbook
play playbook="./playbooks/default.yml" inv=INVENTORY:
    ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i {{inv}} {{playbook}}

# Run an arbitrary command
shell cmd="echo 'Hello, world'" inv=INVENTORY:
    ANSIBLE_HOST_KEY_CHECKING=False ansible -i {{inv}} all -a "{{cmd}}"

# Generate an inventory
inv target_subnet=SUBNET_CMD file=INVENTORY:
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
    nmap -sn -n {{target_subnet}} -oG - | awk '/Up$/{print $2}' > $before
    printf "Turn on the pucks, then wait about 2 minutes.\n"
    read -p "Press any key to resume..."
    printf "\n\n"
    nmap -sn -n {{target_subnet}} -oG - | awk '/Up$/{print $2}' > $after
    changes=$(comm -13 $before $after)
    if [[ -z "$changes" ]]; then
        printf "Error: No new network devices!\n"
        exit 1
    fi
    echo "$changes"
    rm -f {{file}}
    echo "$changes" | xargs -I {} sh -c "printf '{} ansible_ssh_user=pi ansible_ssh_pass=raspberry\n' >> {{file}}"
