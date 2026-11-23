# PLACEHOLDER until NixOS is installed: replace the module lists with what
# `nixos-generate-config --show-hardware-config` prints on the machine (only
# these lines; the file systems are in ../common/hardware-configuration.nix
# and the pools in pools.nix).
#
# Guessed from the hardware list of the TrueNAS (i7-8750H laptop, NVMe,
# Intel AHCI, the disks on USB).
{ config, lib, pkgs, modulesPath, ... }:

{
  boot.initrd.availableKernelModules = [
    "xhci_pci"
    "ahci"
    "nvme"
    "usb_storage"
    "uas"
    "sd_mod"
  ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [ ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
