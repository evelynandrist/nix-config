# :snowflake: ️My NixOS configuration

![My setup](desktop.png)

## Features

- Opt-in persistence through impermanence
- Secrets using sops-nix
- Animated wallpapers that are automatically pulled from [moewalls.com](https://moewalls.com/) and cropped
- Global themes matching wallpapers with a fork of nix-colors
- Hyprland & Neovim configuration

## Installation

> [!NOTE]
> This is my personal config and as such is tailored exactly to my needs and hardware. You probably don't want to install my exact config. And if you do, you need to at least change the sops-nix configuration.

Prerequisities:

- [Booted from a live NixOS iso](https://nixos.org/manual/nixos/stable/#sec-installation-booting)
- Connected to the internet

First, create the partitions you need using the tool of your choice, e.g. GParted.

Then, format the boot and nixos partitions with corresponding labels:

``` sh
sudo mkfs.fat -F 32 -n boot /dev/<your boot partition>
sudo mkfs.btrfs -L nixos /dev/<your nixos partition>
```

Now you can clone the repo and cd into it:

``` sh
git clone https://github.com/kev1nbam27/nix-config ~/nix-config && cd ~/nix-config
```

Then run the pre-install script to create and mount the btrfs subvolumes and choose your username:

``` sh
sudo ./pre-install.sh --user-name <your username>
```

Now you need to configure sops-nix, mount the persist subvolume and copy your ssh keys to persist/etc/ssh/.

You can then install the system:

``` sh
sudo nixos-install --flake .\#nixpad
```

If all went well, you should now be able to reboot into your new system!
Please feel free to [open an issue](https://github.com/kev1nbam27/nix-config/issues) if you have any questions.

## Appendix

Special thanks to [Misterio77](https://github.com/Misterio77) for his [nix-starter-configs](https://github.com/Misterio77/nix-starter-configs) and his [dotfiles](https://github.com/Misterio77/nix-config).
