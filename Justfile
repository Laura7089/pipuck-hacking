set positional-arguments

INVENTORY := "./inventory.ini"

alias p := playbook
alias s := shell
alias i := inventory

# Run an ansible playbook against the hosts (host key checking disabled)
playbook playbook="./playbook.yml" inv=INVENTORY:
    ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i {{inv}} {{playbook}}

# Run an arbitrary command
shell args="" inv=INVENTORY :
    ANSIBLE_HOST_KEY_CHECKING=False ansible -i {{inv}} all -a "{{args}}"

# Interactively generate an inventory based on diffing nmap output
inventory search file=INVENTORY:
    #!/bin/bash
    set -eo pipefail
    rm -f {{file}}

    before=$(mktemp)
    after=$(mktemp)

    cleanup() {
        rm $before
        rm $after
    }
    trap 0 cleanup

    # from https://unix.stackexchange.com/questions/181676/output-only-the-ip-addresses-of-the-online-machines-with-nmap
    printf "Turn off any pucks you want to add to your inventory.\n"
    read -p "Press any key to resume..."
    nmap -sn -n {{search}} -oG - | awk '/Up$/{print $2}' > $before
    printf "Turn on the pucks, then wait about 2 minutes.\n"
    read -p "Press any key to resume..."
    printf "\n\n"
    nmap -sn -n {{search}} -oG - | awk '/Up$/{print $2}' > $after
    changes=$(comm -13 $before $after)
    if [[ -z "$changes" ]]; then
        printf "No new network devices..."
        exit 1
    fi
    echo "$changes"
    echo "$changes" | xargs -I {} sh -c "printf '{} ansible_ssh_user=pi ansible_ssh_pass=raspberry\n' >> {{file}}"
