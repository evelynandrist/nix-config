# ollama on the RTX 3060. Its model is pulled and checked by
# paperless-llm-ocr.nix, the only user so far.
#
# Listens on 127.0.0.1 only; no port is opened. Models and state live in
# /persist/data/ollama, in the nightly restic backup.
#
# The CUDA build of ollama is not on cache.nixos.org, only on the CUDA
# team's cache, which every host has in its nix.conf
# (../common/configuration.nix). A machine without it would compile
# ollama with CUDA for hours; for a fresh install see README.md.
#
# Check:  ollama list
#         journalctl -u ollama -b
{ pkgs, ... }:
let
  home = "/persist/data/ollama";
in {
  services.ollama = {
    enable = true;
    package = pkgs.ollama-cuda;
    # A fixed user, so the files in /persist keep their owner.
    user = "ollama";
    inherit home;
  };

  systemd.tmpfiles.rules = [ "d ${home} 0750 ollama ollama -" ];
  systemd.services.ollama.unitConfig.RequiresMountsFor = [ home ];
}
