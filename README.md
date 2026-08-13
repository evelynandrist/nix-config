# :snowflake: ️My NixOS configuration

![My setup](desktop.png)

## Features

- Opt-in persistence through impermanence
- Secrets using sops-nix
- Animated wallpapers that are automatically pulled from [moewalls.com](https://moewalls.com/) and cropped
- Global themes matching wallpapers with a fork of nix-colors
- Hyprland & Neovim configuration

## Installation (NixOS)

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
git clone https://github.com/evelynandrist/nix-config ~/nix-config && cd ~/nix-config
```

Then run the pre-install script to create and mount the btrfs subvolumes:

``` sh
sudo ./pre-install.sh
```

Now you need to configure sops-nix, mount the persist subvolume and copy your ssh keys to persist/etc/ssh/.

You can then install the system:

``` sh
sudo nixos-install --flake .\#nixpad
```

If all went well, you should now be able to reboot into your new system!
Please feel free to [open an issue](https://github.com/kev1nbam27/nix-config/issues) if you have any questions.

## Installation (macOS)

1. Install macOS, set up your user, and sign into the App Store.
2. Install nix with flakes enabled: `curl -sSfL https://artifacts.nixos.org/nix-installer | sh -s -- install --enable-flakes`
3. Enable remote-login: `sudo systemsetup -setremotelogin on`
4. Install Xcode (App Store or `xcodes`), then `xcode-select -s`, `xcodebuild -license accept`,
   `xcodebuild -runFirstLaunch`.
5. Create the build keychain and import signing certs and provisioning profiles.
6. Clone this repo.
7. Set up SOPS:
    1. Set `bootstrapped = false` in `home-manager/nixbook/sops.nix`
    2. Run `nix run nix-darwin -- switch --flake .\#nixbook` (this generates the age key)
    3. Run `age-keygen -y ~/.config/sops/age/keys.txt`, add the recipient to `.sops.yaml`, create `secrets/nixbook.yaml`.
    4. Add `nixbook/build_keychain_password` to the secrets file.
    5. Set `bootstrapped = true` and re-run `darwin-rebuild switch --flake .\#nixbook`.

## Appendix

Special thanks to [Misterio77](https://github.com/Misterio77) for his [nix-starter-configs](https://github.com/Misterio77/nix-starter-configs) and his [dotfiles](https://github.com/Misterio77/nix-config).
