set positional-arguments := true
set dotenv-load := true

# Tries to guess the wifi device
export WIFI_DEV := trim(`ip address | grep wl | head -n 1 | cut -d ':' -f 2`)
# Gets the subnet on the wifi device (lazy evaluated)
SUBNET_CMD := "$(ip -o -f inet addr show $WIFI_DEV | awk '/scope global/ {print $4}')"

# Disable host key checking with ansible to avoid quibbles
export ANSIBLE_HOST_KEY_CHECKING := "False"

# Directories
INVENTORY := "./inventory.ini"
TOOLS_DIR := "./tools"
ARTS_DIR := "./artefacts"
PACKER_DIR := "./packer"
export PACKER_PLUGIN_PATH := PACKER_DIR + "/plugins"
EPUCK_ROS2_CC_PATH := TOOLS_DIR + "/epuck_ros2/installation/cross_compile"

DOCKER_BIN := env_var_or_default("DOCKER_BIN", "sudo docker")

PUCK_HOSTNAME_GEN := "puck-" + `uuidgen | cut -d "-" -f 2`

# Ssh into a pi with fixes applied
ssh pi_address user="pi" pass="raspberry": _clear_known_hosts _wifi_lab
    sshpass -p "{{ pass }}" ssh -oStrictHostKeyChecking=no "{{ user }}@{{ pi_address }}"

# Run an ansible playbook
aplay playbook +args="": _clear_known_hosts _wifi_lab
    ansible-playbook -i {{ INVENTORY }} {{ args }} {{ playbook }}

# Run an arbitrary command with ansible
ashell +command: _clear_known_hosts _wifi_lab
    ansible -i {{ INVENTORY }} all -a "{{ command }}"

# Generate an ansible inventory
ainv target_subnet=SUBNET_CMD: _wifi_lab
    #!/bin/bash
    set -eo pipefail

    before=$(mktemp)
    after=$(mktemp)

    cleanup() {
        rm -vf $before
        rm -vf $after
    }
    trap cleanup 0

    # from https://unix.stackexchange.com/questions/181676/output-only-the-ip-addresses-of-the-online-machines-with-nmap
    printf "Turn off any pucks you want to add to your inventory.\n"
    read -p "Press any key to resume..."
    nmap -sn -n {{ target_subnet }} -oG - | awk '/Up$/{print $2}' | tee $before
    printf "Turn on the pucks, then wait about 2 minutes.\n"
    read -p "Press any key to resume..."
    printf "\n\n"
    nmap -sn -n {{ target_subnet }} -oG - | awk '/Up$/{print $2}' | tee $after
    changes=$(comm -13 $before $after)
    if [[ -z "$changes" ]]; then
        printf "Error: No new network devices!\n"
        exit 1
    fi
    echo "$changes"
    rm -vf {{ INVENTORY }}
    echo "$changes" | xargs -I {} sh -c "printf '{} ansible_ssh_user=pi ansible_ssh_pass=raspberry\n' | tee -a {{ INVENTORY }}"

# Take an image of a connected media
isnap device outfile=(ARTS_DIR + "/rpi.img"): && (ishrink outfile)
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
ishrink image=(ARTS_DIR + "/rpi.img"):
    sudo {{ TOOLS_DIR }}/pishrink/pishrink.sh -v {{ image }}

# Flash a medium, patch the hostname
iflash device image=(ARTS_DIR + "/rpi.img"): (_flash_raw device image) (hostset device)

# Flash an image file to a device
_flash_raw device image=(ARTS_DIR + "/rpi.img"):
    sudo dd if={{ image }} of={{ device }} status=progress bs=64k

# Patch a hostname onto a medium or image
hostset target mountpoint="/mnt/sd" hostname=PUCK_HOSTNAME_GEN: (_mnt target mountpoint "0" "2") && (_umnt mountpoint "0")
    echo {{ hostname }} | sudo tee "{{ mountpoint }}/etc/hostname"

# Run a packer target
packer target=(PACKER_DIR + "/from_raspios_remote.pkr.hcl") +args="": _packer_plugin_arm && (ishrink ARTS_DIR + "/output-pipuck/image")
    sudo packer build {{ args }} "{{ target }}"

# Build an image from scratch with pi-gen
pigen:
    cd {{ TOOLS_DIR }}/pi-gen-yrl && ./build.sh

# netctl: switch to correct wifi network
wifi action="lab" network="rts_lab":
    just _wifi_{{ action }} {{ network }}

# netctl: switch to lab wifi
_wifi_lab network="rts_lab":
    sudo systemctl stop netctl-auto@{{ WIFI_DEV }}
    sudo netctl start {{ network }}

# netctl: turn off lab wifi
_wifi_reset network="rts_lab":
    sudo netctl stop {{ network }}
    sudo systemctl start netctl-auto@{{ WIFI_DEV }}

# Build the packer-plugin-arm-image binary
_packer_plugin_arm:
    #!/bin/bash
    set -euxo pipefail

    if {{ path_exists(PACKER_PLUGIN_PATH + "/packer-plugin-arm-image") }} ; then
        echo "Plugin already built..."
        exit 0
    fi

    (
        cd "{{ TOOLS_DIR }}/packer-plugin-arm-image"
        export "GOPATH=$(mktemp -d)"
        go generate ./...
        go build -o packer-plugin-arm-image .
    )
    install -vDm 0755 \
        "{{ TOOLS_DIR }}/packer-plugin-arm-image/packer-plugin-arm-image" \
        "{{ PACKER_PLUGIN_PATH }}/packer-plugin-arm-image"

# Clear the hosts in INVENTORY from ~/.ssh/known_hosts
_clear_known_hosts inv=INVENTORY:
    #!/bin/bash
    set -euxo pipefail

    while read line; do
        ip=$(echo "$line" | cut -d " " -f 1)
        sed -i "/$ip/d" ~/.ssh/known_hosts
    done < {{ inv }}

# Cross-compile epuck_ros2
epuckros2 pi_fs=(ARTS_DIR + "/rpi.img") out=(ARTS_DIR + "/epuck_ros2_out") pkg="ros2topic" loop="0": _epuckros2_di (_mnt pi_fs out loop "2") && (_umnt out loop)
    @# Ignore failure so that cleanup still runs
    -{{ DOCKER_BIN }} run \
        --rm \
        --device /dev/fuse \
        --cap-add SYS_ADMIN \
        --security-opt apparmor=unconfined \
        -v "$PWD/{{ out }}:/home/develop/rootfs:ro" \
        -v "$PWD/{{ EPUCK_ROS2_CC_PATH }}/ros2_ws:/home/develop/ros2_ws" \
        --entrypoint /bin/bash \
        rpi_cross_compile \
        -ieuxo pipefail -c \
        'export ROS_DISTRO=foxy && cross-initialize && cross-colcon-build --packages-up-to {{ pkg }}'

# Build the docker image for epuck_ros2 cross compiling
_epuckros2_di:
    cd "{{ EPUCK_ROS2_CC_PATH }}" && \
        {{ DOCKER_BIN }} build -t rpi_cross_compile -f Dockerfile .

# Mount an image or device (dynamic dispatch)
_mnt target mountpoint loop_num part_num:
    just _mnt_{{ if parent_directory(target) == "/dev" { "dev" } else { "pimg" } }} \
        "{{ target }}" "{{ mountpoint }}" {{ loop_num }} {{ part_num }}

# Unmount an image or device (dynamic dispatch)
_umnt mountpoint loop_num:
    if [[ "$(mount | grep {{ mountpoint }})" =~ '/dev/loop' ]]; then \
        just _umnt_pimg "{{ mountpoint }}" {{ loop_num }}; \
    else \
        just _umnt_dev "{{ mountpoint }}"; \
    fi

# Mount a device
_mnt_dev device mountpoint _loop part:
    mkdir -vp "{{ mountpoint }}"
    sudo mount {{ device }}{{ part }} "{{ mountpoint }}"

# Unmount a device
_umnt_dev mountpoint:
    sudo umount "{{ mountpoint }}"

# Mount a pi image (assumes partition layout)
_mnt_pimg image mountpoint loop_num _part:
    sudo partx -va "{{ image }}"
    mkdir -vp "{{ mountpoint }}"
    sudo mount -v /dev/loop{{ loop_num }}p2 "{{ mountpoint }}"
    -sudo mount -v /dev/loop{{ loop_num }}p1 "{{ mountpoint }}/boot"

# Unmount a pi image (assumes partition layout)
_umnt_pimg mountpoint loop_num:
    -sudo umount -v "{{ mountpoint }}/boot"
    sudo umount -v "{{ mountpoint }}"
    sudo partx -vd /dev/loop{{ loop_num }}
    sudo losetup -vd /dev/loop{{ loop_num }}
