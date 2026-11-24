# The kernel modules the hardware needs early, from `lspci -k` on the TrueNAS
# (2026-11-24): the USB controllers use xhci_pci, the SATA controller ahci,
# the NVMe nvme; usb_storage, uas and sd_mod for the disks on USB. The
# network card (enp60s0, alx) loads later by itself.
#
# Only the module lines: the file systems are in
# ../common/hardware-configuration.nix and the pools in pools.nix.
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
