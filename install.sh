#!/usr/bin/env bash

# More safety, by turning some bugs into errors.
# Without `errexit` you don’t need ! and can replace
# ${PIPESTATUS[0]} with a simple $?, but I prefer safety.
set -o errexit -o pipefail -o noclobber -o nounset

# -allow a command to fail with !’s side effect on errexit
# -use return value from ${PIPESTATUS[0]}, because ! hosed $?
! getopt --test > /dev/null
if [[ ${PIPESTATUS[0]} -ne 4 ]]; then
    echo 'I’m sorry, `getopt --test` failed in this environment.'
    exit 1
fi

LONGOPTS=user-name:,boot-partition:,nixos-partition:
OPTIONS=u:b:n:

# -regarding ! and PIPESTATUS see above
# -temporarily store output to be able to check for errors
# -activate quoting/enhanced mode (e.g. by writing out “--options”)
# -pass arguments only via   -- "$@"   to separate them correctly
! PARSED=$(getopt --options=$OPTIONS --longoptions=$LONGOPTS --name "$0" -- "$@")
if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
    # e.g. return value is 1
    #  then getopt has complained about wrong arguments to stdout
    exit 2
fi
# read getopt’s output this way to handle the quoting right:
eval set -- "$PARSED"

userName=- mainDrive="/dev/disk/by-label/nixos" bootDrive="/dev/disk/by-label/boot"
# now enjoy the options in order and nicely split until we see --
while true; do
    case "$1" in
        -u|--user-name)
            userName="$2"
            shift 2
            ;;
        -b|--boot-partition)
            bootDrive="$2"
            shift 2
            ;;
        -n|--nixos-partition)
            mainDrive="$2"
            shift 2
            ;;
        --)
            shift
            break
            ;;
        *)
            echo "Programming error"
            exit 3
            ;;
    esac
done

echo "Creating btrfs subvolumes..."

mount -t btrfs $mainDrive /mnt

# We first create the subvolumes outlined above:
btrfs subvolume create /mnt/root
btrfs subvolume create /mnt/home
btrfs subvolume create /mnt/nix
btrfs subvolume create /mnt/persist
btrfs subvolume create /mnt/log

# We then take an empty *readonly* snapshot of the root subvolume,
# which we'll eventually rollback to on every boot.
btrfs subvolume snapshot -r /mnt/root /mnt/root-blank

umount /mnt

echo "Mounting subvolumes..."

mount -o subvol=root,compress=zstd,noatime $mainDrive /mnt

mkdir /mnt/home
mount -o subvol=home,compress=zstd,noatime $mainDrive /mnt/home

mkdir /mnt/nix
mount -o subvol=nix,compress=zstd,noatime $mainDrive /mnt/nix

mkdir /mnt/persist
mount -o subvol=persist,compress=zstd,noatime $mainDrive /mnt/persist

mkdir -p /mnt/var/log
mount -o subvol=log,compress=zstd,noatime $mainDrive /mnt/var/log

echo "Mounting boot partition..."

mkdir /mnt/boot
mount $bootDrive /mnt/boot

if [[ $userName != - ]]; then
    echo "Setting username..."
    echo -e "{ lib, ... }:\nwith lib;\n{\n  userConfig.username = \"${userName}\";\n}" | tee ./modules/user-config/config.nix
fi

echo "Installing NixOS..."

nixos-install --flake .\#nixpad
